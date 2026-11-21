import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/codec.dart';
import 'domain/catalog.dart';
import 'domain/models.dart';
import 'domain/rules.dart';

const kListLimit = 30;
const kInboxLimit = 30;

/// Matches functions/index.js authEmail. Plain names stay name@prtrack.app.
String authEmail(String username) {
  final local = StringBuffer();
  for (final unit in username.codeUnits) {
    final ch = String.fromCharCode(unit);
    if (unit < 128 && RegExp(r'[a-z0-9._-]').hasMatch(ch)) {
      local.write(ch);
    } else {
      local.write('_${unit.toRadixString(16)}_');
    }
  }
  return '$local@prtrack.app';
}

class AppController extends ChangeNotifier {
  AppController() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    _listenNet();
  }

  final lists = <TabKind, List<PurchaseRequest>>{
    for (final tab in TabKind.values) tab: <PurchaseRequest>[],
  };
  final loaded = <TabKind, bool>{for (final tab in TabKind.values) tab: false};
  final waiting = <String>{};
  final _pending = <String>{};
  final _subs = <TabKind, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

  Staff? staff;
  bool booting = true;
  bool preferAr = false;
  String? authError;
  String? banner;
  String? failurePo;
  int failureTick = 0;
  String? pendingRequestId;
  String? pendingPo;
  String? pendingStage;
  List<PurchaseRequest>? searchResults;
  bool searching = false;
  Map<String, dynamic> stats = const {};
  List<Map<String, dynamic>> inbox = const [];
  bool inboxLoaded = false;
  bool inboxHasMore = false;
  bool inboxLoadingMore = false;
  List<PurchaseRequest> stageRows = const [];
  bool stageLoaded = false;
  String? failureCode;
  bool online = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _staffSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inboxSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _stageSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _stageDoneSub;
  List<PurchaseRequest> _stageLive = const [];
  List<PurchaseRequest> _stageCompleted = const [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _inboxHead = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _inboxTail = [];
  bool _inboxTailHasMore = false;
  Stage? _watchedStage;
  final _waitTimers = <String, Timer>{};
  Timer? _bannerTimer;

  bool get ar => staff?.ar ?? preferAr;

  bool isBusy(String id) => _pending.contains(id);

  void _listenNet() {
    void apply(List<ConnectivityResult> results) {
      final next = results.any((item) => item != ConnectivityResult.none);
      if (next == online) return;
      online = next;
      notifyListeners();
    }

    Connectivity().checkConnectivity().then(apply);
    _netSub = Connectivity().onConnectivityChanged.listen(apply);
  }

  bool _networkError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          (error.code == 'internal' && (error.message ?? '').toLowerCase().contains('network'));
    }
    if (error is FirebaseException) {
      return error.code == 'unavailable' || error.code == 'network-request-failed';
    }
    final text = error.toString().toLowerCase();
    return text.contains('network') || text.contains('unavailable') || text.contains('offline') || text.contains('socket');
  }

  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> _onAuth(User? user) async {
    await _staffSub?.cancel();
    _stopListeners();
    if (user == null) {
      staff = null;
      booting = false;
      notifyListeners();
      return;
    }
    _staffSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((
      snap,
    ) async {
      if (snap.metadata.isFromCache && (!snap.exists || snap.data()?['active'] == false)) {
        return;
      }
      if (!snap.exists || snap.data()?['removed'] == true) {
        authError = 'removed';
        await FirebaseAuth.instance.signOut();
        return;
      }
      if (snap.data()?['active'] == false) {
        authError = 'disabled';
        await FirebaseAuth.instance.signOut();
        return;
      }
      final next = staffFromMap(user.uid, snap.data()!);
      booting = false;
      if (next.mustChangePassword) {
        staff = next;
        _stopListeners();
        notifyListeners();
        return;
      }
      final prev = staff;
      final relisten = prev == null ||
          prev.uid != next.uid ||
          prev.level != next.level ||
          prev.department != next.department ||
          prev.scope != next.scope;
      staff = next;
      if (relisten) {
        _listenLists();
        _listenInbox();
        if (next.level == Level.executive || next.level == Level.kourbaDirector) {
          _listenStats();
        }
        unawaited(_saveToken());
      }
      notifyListeners();
    });
  }

  Future<void> signIn(String username, String password) async {
    authError = null;
    final name = username.trim().toLowerCase();
    try {
      final lookup = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(name)
          .get(const GetOptions(source: Source.server));
      if (!lookup.exists) {
        authError = 'missing';
        notifyListeners();
        return;
      }
      if (lookup.data()?['removed'] == true) {
        authError = 'removed';
        notifyListeners();
        return;
      }
      if (lookup.data()?['active'] == false) {
        authError = 'disabled';
        notifyListeners();
        return;
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail(name),
        password: password,
      );
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' || error.code == 'invalid-credential') {
        authError = 'password';
      } else if (error.code == 'user-disabled') {
        authError = 'disabled';
      } else if (error.code == 'network-request-failed') {
        authError = 'offline';
      } else {
        authError = error.message ?? 'generic';
      }
      notifyListeners();
    } on FirebaseException catch (error) {
      authError = error.code == 'unavailable' || error.code == 'network-request-failed' ? 'offline' : 'generic';
      notifyListeners();
    } catch (error) {
      authError = error.toString().contains('network') ? 'offline' : 'generic';
      notifyListeners();
    }
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<void> setLanguage(bool arabic) async {
    preferAr = arabic;
    final current = staff;
    if (current != null) {
      staff = current.copyWith(lang: arabic ? 'ar' : 'en');
    }
    notifyListeners();
    if (current != null && online) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(current.uid).update({
          'lang': arabic ? 'ar' : 'en',
        });
      } catch (_) {}
    }
  }

  void _listenLists() {
    final current = staff;
    if (current == null) return;
    for (final tab in TabKind.values) {
      _subs[tab]?.cancel();
      _subs[tab] = _query(current, tab).snapshots().listen((snap) {
        loaded[tab] = true;
        for (final change in snap.docChanges) {
          final id = change.doc.id;
          if (_pending.contains(id)) continue;
          if (change.type == DocumentChangeType.removed) {
            for (final list in lists.values) {
              list.removeWhere((item) => item.id == id);
            }
          } else {
            _place(requestFromMap(id, change.doc.data()!));
          }
        }
        if (snap.docChanges.isEmpty && (lists[tab]?.isEmpty ?? true)) {
          lists[tab] = snap.docs
              .map((doc) => requestFromMap(doc.id, doc.data()))
              .where((item) => !_pending.contains(item.id))
              .toList();
        }
        notifyListeners();
      }, onError: (Object error) {
        loaded[tab] = true;
        debugPrint('list $tab $error');
        notifyListeners();
      });
    }
  }

  Query<Map<String, dynamic>> _query(Staff current, TabKind tab) {
    final base = FirebaseFirestore.instance.collection('requests');
    Query<Map<String, dynamic>> query;
    switch (current.level) {
      case Level.executive:
        query = base.where('executiveVisible', isEqualTo: true);
      case Level.kourbaDirector:
        query = base.where('scope', isEqualTo: 'kourba').where('executiveVisible', isEqualTo: true);
      case Level.procurementOfficer:
        query = base.where('procurementVisible', isEqualTo: true);
      case Level.warehouseOfficer:
        query = current.department == Department.warehouseKourba
            ? base.where('warehouseKourba', isEqualTo: true)
            : base.where('warehouseFifthOfficer', isEqualTo: true);
      case Level.warehouseManager:
        query = current.department == Department.warehouseKourba
            ? base.where('warehouseKourba', isEqualTo: true)
            : base.where('warehouseFifthManager', isEqualTo: true);
      case Level.deptManager:
        query = base.where('department', isEqualTo: current.department.name);
      case Level.engineer:
      case Level.mallOpsManager:
        query = base.where('creatorUid', isEqualTo: current.uid);
    }
    return query.where('tab', isEqualTo: tab.name).orderBy('updatedAt', descending: true).limit(kListLimit);
  }

  void watchStage(Stage? stage) {
    if (stage == _watchedStage) return;
    _watchedStage = stage;
    _stageSub?.cancel();
    _stageDoneSub?.cancel();
    _stageLive = const [];
    _stageCompleted = const [];
    stageRows = const [];
    stageLoaded = stage == null;
    if (stage == null) {
      notifyListeners();
      return;
    }
    final current = staff;
    if (current == null) return;
    if (current.level != Level.executive && current.level != Level.kourbaDirector) {
      notifyListeners();
      return;
    }
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('requests');
    if (current.level == Level.kourbaDirector) {
      query = query.where('scope', isEqualTo: 'kourba').where('executiveVisible', isEqualTo: true);
    } else {
      query = query.where('executiveVisible', isEqualTo: true);
    }
    _stageSub = query
        .where('stage', isEqualTo: stageCode(stage))
        .orderBy('updatedAt', descending: true)
        .limit(kListLimit)
        .snapshots()
        .listen((snap) {
      _stageLive = snap.docs.map((doc) => requestFromMap(doc.id, doc.data())).toList();
      _publishStage();
    }, onError: (Object error) {
      debugPrint('stage $error');
      stageLoaded = true;
      notifyListeners();
    });
    if (stage == Stage.mrv) {
      _stageDoneSub = query
          .where('stage', isEqualTo: 'closed')
          .where('closure', isEqualTo: 'completed')
          .orderBy('updatedAt', descending: true)
          .limit(kListLimit)
          .snapshots()
          .listen((snap) {
        _stageCompleted = snap.docs.map((doc) => requestFromMap(doc.id, doc.data())).toList();
        _publishStage();
      }, onError: (Object error) {
        debugPrint('stage-closed $error');
        stageLoaded = true;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _publishStage() {
    final merged = <String, PurchaseRequest>{};
    for (final row in _stageLive) {
      merged[row.id] = row;
    }
    for (final row in _stageCompleted) {
      merged[row.id] = row;
    }
    final rows = merged.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    stageRows = rows.take(kListLimit).toList();
    stageLoaded = true;
    notifyListeners();
  }

  void _place(PurchaseRequest item) {
    for (final list in lists.values) {
      list.removeWhere((row) => row.id == item.id);
    }
    final bucket = lists[item.tab]!..add(item);
    bucket.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> search(String text) async {
    final queryText = text.trim();
    if (queryText.isEmpty) {
      searchResults = null;
      searching = false;
      notifyListeners();
      return;
    }
    searching = true;
    searchResults = const [];
    notifyListeners();
    final current = staff;
    if (current == null) return;
    final po = queryText.toUpperCase().startsWith('PO-') ? queryText : 'PO-$queryText';
    final number = queryText.toUpperCase();
    try {
      final hits = <String, PurchaseRequest>{};
      for (final field in ['displayPo', 'requestNo']) {
        final value = field == 'displayPo' ? po : number;
        final snap = await _searchQuery(current, field, value).get();
        for (final doc in snap.docs) {
          hits[doc.id] = requestFromMap(doc.id, doc.data());
        }
      }
      searchResults = hits.values.toList();
    } catch (error) {
      debugPrint('search $error');
      searchResults = const [];
    }
    searching = false;
    notifyListeners();
  }

  Query<Map<String, dynamic>> _searchQuery(Staff current, String field, String value) {
    final base = FirebaseFirestore.instance.collection('requests');
    switch (current.level) {
      case Level.executive:
        return base.where('executiveVisible', isEqualTo: true).where(field, isEqualTo: value).limit(5);
      case Level.kourbaDirector:
        return base
            .where('scope', isEqualTo: 'kourba')
            .where('executiveVisible', isEqualTo: true)
            .where(field, isEqualTo: value)
            .limit(5);
      case Level.procurementOfficer:
        return base.where('procurementVisible', isEqualTo: true).where(field, isEqualTo: value).limit(5);
      case Level.warehouseOfficer:
        return base
            .where(
              current.department == Department.warehouseKourba
                  ? 'warehouseKourba'
                  : 'warehouseFifthOfficer',
              isEqualTo: true,
            )
            .where(field, isEqualTo: value)
            .limit(5);
      case Level.warehouseManager:
        return base
            .where(
              current.department == Department.warehouseKourba
                  ? 'warehouseKourba'
                  : 'warehouseFifthManager',
              isEqualTo: true,
            )
            .where(field, isEqualTo: value)
            .limit(5);
      case Level.deptManager:
        return base.where('department', isEqualTo: current.department.name).where(field, isEqualTo: value).limit(5);
      case Level.engineer:
      case Level.mallOpsManager:
        return base.where('creatorUid', isEqualTo: current.uid).where(field, isEqualTo: value).limit(5);
    }
  }

  Future<bool> createRequest({
    required SiteInfo site,
    required RequestType type,
    required String externalPo,
    required String details,
    Uint8List? photo,
    Discipline? discipline,
  }) async {
    final current = staff;
    if (current == null) return false;
    if (!online) return false;
    String? imageUrl;
    if (photo != null) {
      imageUrl = await _upload(photo, 'staging/${current.uid}');
    }
    final now = DateTime.now();
    late final PurchaseRequest draft;
    try {
      draft = draftRequest(
        creator: current,
        site: site,
        type: type,
        externalPo: externalPo.trim(),
        details: details,
        now: now,
        imageUrl: imageUrl,
        discipline: discipline,
      ).copyWith(id: 'local-$now');
    } catch (error) {
      _fail('PO-${externalPo.trim()}', error);
      notifyListeners();
      return false;
    }
    _pending.add(draft.id);
    _place(draft);
    _armWait(draft.id);
    notifyListeners();
    try {
      final result = await _fn.httpsCallable('createRequest').call({
        'clientActionId': draft.id,
        'siteId': site.id,
        'siteAr': site.nameAr,
        'siteEn': site.nameEn,
        'type': type.name,
        'discipline': draft.discipline.name,
        'externalPo': externalPo.trim(),
        'details': details.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final saved = requestFromMap(data['id'] as String, Map<String, dynamic>.from(data['request'] as Map));
      _pending.remove(draft.id);
      waiting.remove(draft.id);
      for (final list in lists.values) {
        list.removeWhere((row) => row.id == draft.id);
      }
      _place(saved);
      _showSuccess(saved.displayPo);
      notifyListeners();
      return true;
    } catch (error) {
      _pending.remove(draft.id);
      waiting.remove(draft.id);
      for (final list in lists.values) {
        list.removeWhere((row) => row.id == draft.id);
      }
      _fail(draft.displayPo, error);
      notifyListeners();
      return false;
    }
  }

  Future<void> act({
    required PurchaseRequest request,
    required PrAction action,
    String note = '',
    Uint8List? photo,
  }) async {
    final current = staff;
    if (current == null || _pending.contains(request.id) || !online) return;
    final previous = request;
    _pending.add(request.id);
    notifyListeners();
    String? imageUrl;
    try {
      if (photo != null) imageUrl = await _upload(photo, 'requests/${request.id}');
    } catch (error) {
      _pending.remove(request.id);
      waiting.remove(request.id);
      _fail(previous.displayPo, error);
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    late final PurchaseRequest next;
    try {
      next = applyAction(
        request: request,
        action: action,
        actor: current,
        now: now,
        note: note,
        imageUrl: imageUrl,
      );
    } catch (error) {
      _pending.remove(request.id);
      waiting.remove(request.id);
      _fail(previous.displayPo, error);
      notifyListeners();
      return;
    }
    _place(next);
    _armWait(request.id);
    notifyListeners();
    try {
      final result = await _fn.httpsCallable('applyAction').call({
        'requestId': request.id,
        'clientActionId': '${request.id}-$now',
        'action': action.name,
        'note': note.trim(),
        'imageUrl': imageUrl,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final saved = requestFromMap(request.id, Map<String, dynamic>.from(data['request'] as Map));
      _pending.remove(request.id);
      waiting.remove(request.id);
      _place(saved);
      _showSuccess(saved.displayPo);
    } catch (error) {
      _pending.remove(request.id);
      waiting.remove(request.id);
      _place(previous);
      _fail(previous.displayPo, error);
    }
    notifyListeners();
  }

  void _armWait(String id) {
    _waitTimers[id]?.cancel();
    _waitTimers[id] = Timer(const Duration(seconds: 2), () {
      if (_pending.contains(id)) {
        waiting.add(id);
        notifyListeners();
      }
    });
  }

  void _showSuccess(String po) {
    banner = po;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      banner = null;
      notifyListeners();
    });
  }

  void dismissBanner() {
    banner = null;
    _bannerTimer?.cancel();
    notifyListeners();
  }

  void _fail(String po, Object error) {
    debugPrint('write failed $error');
    if (_networkError(error) && online) {
      online = false;
    }
    failurePo = po;
    if (error is RuleException) {
      failureCode = error.code;
    } else if (error is FirebaseFunctionsException) {
      failureCode = error.message ?? error.code;
    } else {
      failureCode = null;
    }
    failureTick++;
  }

  Future<String> _upload(Uint8List bytes, String folder) async {
    final compressed = await compute(_compress, bytes);
    final ref = FirebaseStorage.instance.ref('$folder/${DateTime.now().microsecondsSinceEpoch}.jpg');
    await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  void _listenStats() {
    _statsSub?.cancel();
    _statsSub = FirebaseFirestore.instance.doc('stats/executive').snapshots().listen((snap) {
      stats = snap.data() ?? const {};
      notifyListeners();
    });
  }

  void _listenInbox() {
    final uid = staff?.uid;
    if (uid == null) return;
    _inboxSub?.cancel();
    _inboxHead = [];
    _inboxTail = [];
    _inboxTailHasMore = false;
    inboxHasMore = false;
    _inboxSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(kInboxLimit + 1)
        .snapshots()
        .listen((snap) {
      final liveMore = snap.docs.length > kInboxLimit;
      _inboxHead = liveMore ? snap.docs.sublist(0, kInboxLimit) : snap.docs;
      final headIds = _inboxHead.map((doc) => doc.id).toSet();
      _inboxTail = _inboxTail.where((doc) => !headIds.contains(doc.id)).toList();
      inboxHasMore = _inboxTail.isEmpty ? liveMore : _inboxTailHasMore;
      inbox = [
        ..._inboxHead.map((doc) => {'id': doc.id, ...doc.data()}),
        ..._inboxTail.map((doc) => {'id': doc.id, ...doc.data()}),
      ];
      inboxLoaded = true;
      notifyListeners();
    }, onError: (Object error) {
      debugPrint('inbox $error');
      inboxLoaded = true;
      notifyListeners();
    });
  }

  Future<void> loadMoreInbox() async {
    final uid = staff?.uid;
    if (uid == null || inboxLoadingMore || !inboxHasMore) return;
    final cursor = _inboxTail.isNotEmpty
        ? _inboxTail.last
        : (_inboxHead.isNotEmpty ? _inboxHead.last : null);
    if (cursor == null) return;
    inboxLoadingMore = true;
    notifyListeners();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(kInboxLimit + 1)
          .get();
      _inboxTailHasMore = snap.docs.length > kInboxLimit;
      final page = _inboxTailHasMore ? snap.docs.sublist(0, kInboxLimit) : snap.docs;
      _inboxTail = [..._inboxTail, ...page];
      inboxHasMore = _inboxTailHasMore;
      inbox = [
        ..._inboxHead.map((doc) => {'id': doc.id, ...doc.data()}),
        ..._inboxTail.map((doc) => {'id': doc.id, ...doc.data()}),
      ];
    } finally {
      inboxLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markInboxRead() async {
    final uid = staff?.uid;
    if (uid == null) return;
    final unread = inbox.where((item) => item['read'] != true).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in unread) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').doc(item['id'] as String),
        {'read': true},
      );
    }
    batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
      'unread': FieldValue.increment(-unread.length),
    });
    await batch.commit();
  }

  Future<String?> upsertUser(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)..removeWhere((_, value) => value == null);
    try {
      final result = await _fn.httpsCallable('upsertUser').call(payload);
      final raw = result.data;
      final uid = raw is Map ? raw['uid']?.toString() : null;
      if (uid == null || uid.isEmpty) return 'err:generic';
      return 'ok:$uid';
    } on FirebaseFunctionsException catch (error) {
      return 'err:${error.message ?? error.code}';
    } catch (_) {
      return 'err:generic';
    }
  }

  Future<String?> setUserActive(String uid, bool active) async {
    try {
      await _fn.httpsCallable('setUserActive').call({'uid': uid, 'active': active});
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message ?? 'generic';
    }
  }

  Future<String?> deleteUser(String uid) async {
    try {
      await _fn.httpsCallable('deleteUser').call({'uid': uid});
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message ?? 'generic';
    }
  }

  Future<void> changePassword(String current, String next) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;
    final credential = EmailAuthProvider.credential(email: email, password: current);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(next);
    if (staff?.mustChangePassword == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'mustChangePassword': false,
      });
    }
  }

  Future<String?> resetUserPassword(String uid, String password) async {
    try {
      await _fn.httpsCallable('resetUserPassword').call({'uid': uid, 'password': password});
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message ?? error.code;
    } catch (_) {
      return 'generic';
    }
  }

  Future<String?> restoreExecutivePassword(String setupKey, String password) async {
    try {
      await _fn.httpsCallable('restoreExecutive').call({
        'setupKey': setupKey.trim(),
        'password': password,
      });
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message ?? error.code;
    } catch (_) {
      return 'generic';
    }
  }

  Future<void> _saveToken() async {
    final uid = staff?.uid;
    if (uid == null || kIsWeb) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apns;
      for (var i = 0; i < 10 && apns == null; i++) {
        apns = await messaging.getAPNSToken();
        if (apns == null) await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (apns == null) return;
    }
    final token = await messaging.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('tokens').doc(token).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rememberPush(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList('pushes') ?? <String>[];
    if (seen.contains(id)) return;
    seen.add(id);
    if (seen.length > 200) seen.removeRange(0, seen.length - 200);
    await prefs.setStringList('pushes', seen);
  }

  Future<bool> pushSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('pushes')?.contains(id) ?? false;
  }

  void openFromPush(Map<String, dynamic> data) {
    if (data['type'] == 'account_deleted') {
      authError = 'removed';
      unawaited(signOut());
      return;
    }
    pendingRequestId = data['requestId']?.toString();
    pendingPo = data['displayPo']?.toString();
    pendingStage = data['stage']?.toString();
    notifyListeners();
  }

  void clearPendingOpen() {
    pendingRequestId = null;
    notifyListeners();
  }

  void _stopListeners() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _statsSub?.cancel();
    _inboxSub?.cancel();
    _stageSub?.cancel();
    _stageDoneSub?.cancel();
    _stageLive = const [];
    _stageCompleted = const [];
    _watchedStage = null;
    stageRows = const [];
    stageLoaded = false;
    _inboxHead = [];
    _inboxTail = [];
    inbox = const [];
    inboxLoaded = false;
    inboxHasMore = false;
    for (final list in lists.values) {
      list.clear();
    }
    for (final tab in TabKind.values) {
      loaded[tab] = false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _netSub?.cancel();
    _staffSub?.cancel();
    _stopListeners();
    _bannerTimer?.cancel();
    for (final timer in _waitTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

Uint8List _compress(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const RuleException('image');
  const maxSide = 1280;
  final img.Image resized;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxSide)
        : img.copyResize(decoded, height: maxSide);
  } else {
    resized = decoded;
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 58));
}
