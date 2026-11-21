import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../data/codec.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';
import '../domain/rules.dart';
import '../l10n/s.dart';
import '../theme/app_theme.dart';

class PrApp extends StatelessWidget {
  const PrApp({super.key, required this.controller});
  final AppController controller;
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final text = S(controller.ar);
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'PR TRACK',
          theme: buildTheme(),
          locale: Locale(controller.ar ? 'ar' : 'en'),
          builder: (context, child) {
            return NetworkScope(
              online: controller.online,
              child: Directionality(
                textDirection: controller.ar ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                child: Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (controller.banner != null)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 16,
                        right: 16,
                        child: _SuccessBanner(
                          text: text.updatedOk(controller.banner!),
                          onClose: controller.dismissBanner,
                        ),
                      ),
                    if (!controller.online)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.paddingOf(context).bottom + 16,
                        child: Material(
                          color: AppColors.danger,
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Text(
                              text.offlineRetry,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          home: _Gate(controller: controller),
        );
      },
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate({required this.controller});
  final AppController controller;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  String? _lastFailure;
  String? _openedId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final failure = widget.controller.failurePo;
    final tick = widget.controller.failureTick;
    final key = '$tick-$failure';
    if (failure != null && key != _lastFailure) {
      _lastFailure = key;
      final text = S(widget.controller.ar);
      final code = widget.controller.failureCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_failureMessage(code, failure, text))),
      );
    }
    final pending = widget.controller.pendingRequestId;
    if (pending != null && pending != _openedId && widget.controller.staff != null) {
      _openedId = pending;
      final po = widget.controller.pendingPo;
      final stage = widget.controller.pendingStage;
      widget.controller.clearPendingOpen();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPage(
            controller: widget.controller,
            requestId: pending,
            fallbackPo: po,
            fallbackStage: stage,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller.booting) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (controller.staff == null) return LoginPage(controller: controller);
    if (controller.staff!.mustChangePassword) {
      return ForcePasswordPage(controller: controller);
    }
    return HomeShell(controller: controller);
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.success,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.controller.signIn(_user.text, _pass.text);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restoreDirector() async {
    final text = S(widget.controller.ar);
    final key = TextEditingController();
    final next = TextEditingController();
    var busy = false;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(text.restoreDirector),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text.restoreDirectorHint),
                  const SizedBox(height: 12),
                  PasswordField(controller: key, label: text.ownerKey, text: text),
                  const SizedBox(height: 12),
                  PasswordField(controller: next, label: text.newPassword, text: text),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: Text(text.cancel)),
              TextButton(
                onPressed: busy || !NetworkScope.of(context)
                    ? null
                    : () async {
                        if (key.text.trim().isEmpty) {
                          setLocal(() => error = text.required);
                          return;
                        }
                        if (next.text.trim().length < 6) {
                          setLocal(() => error = text.weakPassword);
                          return;
                        }
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        final result = await widget.controller.restoreExecutivePassword(key.text, next.text.trim());
                        if (!context.mounted) return;
                        if (result == null) {
                          Navigator.pop(context, true);
                          return;
                        }
                        setLocal(() {
                          busy = false;
                          error = result == 'key' ? text.badOwnerKey : text.genericError;
                        });
                      },
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(text.save),
              ),
            ],
          );
        },
      ),
    );
    key.dispose();
    next.dispose();
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.restoreDirectorOk)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = S(widget.controller.ar);
    final error = widget.controller.authError;
    String? message;
    if (error == 'missing') message = text.userMissing;
    if (error == 'password') message = text.wrongPassword;
    if (error == 'removed') message = text.userRemoved;
    if (error == 'disabled') message = text.accountDisabled;
    if (error == 'offline') message = text.noInternet;
    if (error != null && message == null) message = text.genericError;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Text('PR TRACK', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            TextField(controller: _user, decoration: InputDecoration(labelText: text.username)),
            const SizedBox(height: 12),
            PasswordField(controller: _pass, label: text.password, text: text),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            BusyButton(label: text.signIn, busy: _busy, onPressed: _submit),
            TextButton(
              onPressed: () => widget.controller.setLanguage(!widget.controller.ar),
              child: Text(text.language),
            ),
            TextButton(
              onPressed: _restoreDirector,
              child: Text(text.restoreDirector, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final text = S(controller.ar);
    final staff = controller.staff!;
    final executive = staff.level == Level.executive || staff.level == Level.kourbaDirector;
    final pages = <Widget>[
      if (executive) DashboardPage(controller: controller),
      if (executive) UsersPage(controller: controller),
      RequestsPage(controller: controller),
      InboxPage(controller: controller),
      SettingsPage(controller: controller),
    ];
    final items = <NavigationDestination>[
      if (executive) NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: text.dashboard),
      if (executive) NavigationDestination(icon: const Icon(Icons.group_outlined), label: text.users),
      NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: text.requests),
      NavigationDestination(
        icon: Badge(isLabelVisible: staff.unread > 0, label: Text('${staff.unread}'), child: const Icon(Icons.notifications_outlined)),
        label: text.notifications,
      ),
      NavigationDestination(icon: const Icon(Icons.settings_outlined), label: text.settings),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: items,
      ),
    );
  }
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final _search = TextEditingController();
  TabKind _tab = TabKind.fresh;
  String _group = 'all';
  String? _siteId;
  String? _type;
  String? _trade;
  Stage? _stage;

  bool _showFilters(Staff staff) =>
      staff.level == Level.executive ||
      staff.level == Level.kourbaDirector ||
      staff.level == Level.deptManager ||
      coversAllSites(staff);

  bool _keep(PurchaseRequest row, String group) {
    if (group == 'fifth' && row.scope != Scope.fifth) return false;
    if (group == 'kourba' && row.scope != Scope.kourba) return false;
    if (_siteId != null && row.siteId != _siteId) return false;
    if (_type != null && row.type.name != _type) return false;
    if (_trade != null && row.discipline.name != _trade) return false;
    if (_stage != null) {
      final mrvDone = _stage == Stage.mrv && row.stage == Stage.closed && row.closure == ClosureKind.completed;
      if (row.stage != _stage && !mrvDone) return false;
    }
    return true;
  }

  bool _filtersOn(Staff staff) {
    final locked = staff.level == Level.kourbaDirector;
    return (!locked && _group != 'all') ||
        _siteId != null ||
        _type != null ||
        _trade != null ||
        _stage != null;
  }

  void _resetFilters(Staff staff) {
    setState(() {
      if (staff.level != Level.kourbaDirector) _group = 'all';
      _siteId = null;
      _type = null;
      _trade = null;
      _stage = null;
    });
    widget.controller.watchStage(null);
  }

  @override
  void dispose() {
    _search.dispose();
    widget.controller.watchStage(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final text = S(controller.ar);
    final searching = _search.text.trim().isNotEmpty;
    final group = controller.staff!.level == Level.kourbaDirector ? 'kourba' : _group;
    final staged = _stage != null;
    final source = searching
        ? (controller.searchResults ?? const <PurchaseRequest>[])
        : (staged ? controller.stageRows : (controller.lists[_tab] ?? const <PurchaseRequest>[]));
    final rows = _showFilters(controller.staff!) ? source.where((row) => _keep(row, group)).toList() : source;
    final ready = searching || (staged ? controller.stageLoaded : controller.loaded[_tab] == true);
    final siteChoices = group == 'kourba'
        ? kSites.where((site) => site.id == 'kourba').toList()
        : group == 'fifth'
            ? <SiteInfo>[...fifthMalls, siteById('gold_yard')]
            : kSites;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PR TRACK'),
      ),
      floatingActionButton: canCreate(controller.staff!)
          ? FloatingActionButton.extended(
              onPressed: controller.online
                  ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CreatePage(controller: controller)))
                  : null,
              label: Text(text.create),
              icon: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: text.searchHint,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {});
                controller.search(value);
              },
            ),
          ),
          if (_showFilters(controller.staff!))
            _FilterBar(
              resetLabel: text.resetFilters,
              showReset: _filtersOn(controller.staff!),
              onReset: () => _resetFilters(controller.staff!),
              children: [
                _FilterPick<String>(
                  label: text.area,
                  valueLabel: group == 'all' ? text.all : (group == 'fifth' ? text.fifthArea : 'KOURBA HEIGHTS'),
                  options: [
                    if (controller.staff!.level != Level.kourbaDirector) (value: 'all', label: text.all),
                    if (controller.staff!.level != Level.kourbaDirector) (value: 'fifth', label: text.fifthArea),
                    (value: 'kourba', label: 'KOURBA HEIGHTS'),
                  ],
                  onSelected: controller.staff!.level == Level.kourbaDirector
                      ? null
                      : (value) => setState(() {
                            _group = value;
                            _siteId = null;
                          }),
                ),
                _FilterPick<String?>(
                  label: text.site,
                  valueLabel: _siteId == null ? text.all : siteById(_siteId!).name(false),
                  options: [
                    (value: null, label: text.all),
                    for (final site in siteChoices) (value: site.id, label: site.name(false)),
                  ],
                  onSelected: (value) => setState(() => _siteId = value),
                ),
                _FilterPick<String?>(
                  label: text.type,
                  valueLabel: _type == null ? text.all : text.typeLabel(_type!),
                  options: [
                    (value: null, label: text.all),
                    for (final type in RequestType.values) (value: type.name, label: text.typeLabel(type.name)),
                  ],
                  onSelected: (value) => setState(() => _type = value),
                ),
                _FilterPick<String?>(
                  label: text.trade,
                  valueLabel: _trade == null ? text.all : text.tradeLabel(_trade!),
                  options: [
                    (value: null, label: text.all),
                    for (final trade in kFilterTrades) (value: trade.name, label: text.tradeLabel(trade.name)),
                  ],
                  onSelected: (value) => setState(() => _trade = value),
                ),
                if (controller.staff!.level == Level.executive || controller.staff!.level == Level.kourbaDirector)
                  _FilterPick<Stage?>(
                    label: text.currentStage,
                    valueLabel: _stage == null ? text.allStages : text.stage(stageCode(_stage!)),
                    options: [
                      (value: null, label: text.allStages),
                      for (final stage in kFilterStages) (value: stage, label: text.stage(stageCode(stage))),
                    ],
                    onSelected: (value) {
                      setState(() => _stage = value);
                      controller.watchStage(value);
                    },
                  ),
              ],
            ),
          if (!searching && !staged)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ListTabs(
                tab: _tab,
                fresh: text.tabFresh,
                active: text.tabActive,
                done: text.tabDone,
                onChanged: (value) => setState(() => _tab = value),
              ),
            ),
          Expanded(
            child: !ready
                ? const Center(child: CircularProgressIndicator())
                : searching && controller.searching
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                        ? Center(child: Text(text.empty))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final item = rows[index];
                              return RequestCard(
                                request: item,
                                staff: controller.staff!,
                                ar: controller.ar,
                                waiting: controller.waiting.contains(item.id),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => DetailPage(controller: controller, requestId: item.id),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.staff,
    required this.ar,
    required this.waiting,
    required this.onTap,
  });

  final PurchaseRequest request;
  final Staff staff;
  final bool ar;
  final bool waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = S(ar);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 7,
                  decoration: BoxDecoration(
                    color: _stageColor(request.stage),
                    borderRadius: BorderRadius.horizontal(right: ar ? const Radius.circular(16) : Radius.zero, left: ar ? Radius.zero : const Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.displayPo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                            if (needsAction(staff, request))
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 8),
                                child: _NeedActionChip(label: text.needAction),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Chip(label: _stageBadge(request.stage, text)),
                            if (request.closure == ClosureKind.deletedBefore) _Chip(label: text.deletedBefore, danger: true),
                            if (request.stage == Stage.closed && request.closure == ClosureKind.completed)
                              _Chip(label: text.stage('mrv')),
                            _Chip(label: text.departmentLabel(request.department.name)),
                            _Chip(label: text.typeLabel(request.type.name)),
                            if (request.department == Department.mep &&
                                (request.discipline == Discipline.electrical || request.discipline == Discipline.mechanical))
                              _Chip(label: text.tradeLabel(request.discipline.name)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(request.siteName(ar), style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 4),
                        _WaitingBlock(request: request, text: text),
                        if (request.mrRejected) Text(text.reject, style: const TextStyle(color: AppColors.danger)),
                        if (waiting) Text(text.waitingServer, style: const TextStyle(color: AppColors.warning)),
                        if (request.poAnchorAt != null)
                          Text('${text.sinceProcurement}: ${formatWhen(request.poAnchorAt!, ar)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.controller,
    required this.requestId,
    this.fallbackPo,
    this.fallbackStage,
  });

  final AppController controller;
  final String requestId;
  final String? fallbackPo;
  final String? fallbackStage;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  PurchaseRequest? _held;
  bool _acting = false;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _live;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _live = FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  PurchaseRequest? _cached() {
    for (final list in widget.controller.lists.values) {
      for (final item in list) {
        if (item.id == widget.requestId) return item;
      }
    }
    return _held;
  }

  Future<void> _run(PurchaseRequest item, PrAction action) async {
    final text = S(widget.controller.ar);
    final note = TextEditingController();
    Uint8List? photo;
    var compressing = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !_acting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(text.actionLabel(action.name, _targetCode(item, action))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action == PrAction.deleteNow) Text(text.recreateFromProcurement),
                  if (action == PrAction.deleteNow) const SizedBox(height: 8),
                  TextField(controller: note, maxLines: 3, decoration: InputDecoration(labelText: text.notes)),
                  const SizedBox(height: 8),
                  if (compressing) const LinearProgressIndicator(),
                  if (photo != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(photo!, height: 140, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  OutlinedButton(
                    onPressed: compressing || !NetworkScope.of(context)
                        ? null
                        : () async {
                            final source = await showModalBottomSheet<ImageSource>(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(title: Text(text.camera), onTap: () => Navigator.pop(context, ImageSource.camera)),
                                    ListTile(title: Text(text.gallery), onTap: () => Navigator.pop(context, ImageSource.gallery)),
                                  ],
                                ),
                              ),
                            );
                            if (source == null) return;
                            setLocal(() => compressing = true);
                            final file = await ImagePicker().pickImage(source: source);
                            if (file != null) photo = await file.readAsBytes();
                            setLocal(() => compressing = false);
                          },
                    child: Text(text.attach),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: compressing ? null : () => Navigator.pop(context, false), child: Text(text.cancel)),
                TextButton(
                  onPressed: compressing || !NetworkScope.of(context) ? null : () => Navigator.pop(context, true),
                  child: Text(text.confirm),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    if (!widget.controller.online) return;
    setState(() => _acting = true);
    try {
      await widget.controller.act(request: item, action: action, note: note.text, photo: photo);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _live,
      builder: (context, snap) {
        final live = snap.data?.data() == null ? null : requestFromMap(widget.requestId, snap.data!.data()!);
        final cached = _cached();
        final busyNow = _acting || widget.controller.isBusy(widget.requestId);
        final next = busyNow ? (_held ?? cached ?? live) : (live ?? cached ?? _held);
        if (next != null) _held = next;
        final request = _held;
        final busy = busyNow;
        return _DetailBody(
          controller: widget.controller,
          request: request,
          busy: busy,
          fallbackPo: widget.fallbackPo ?? request?.displayPo ?? cached?.displayPo ?? widget.requestId,
          fallbackStage: widget.fallbackStage ?? (request == null ? null : stageCode(request.stage)),
          onRun: _run,
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.controller,
    required this.request,
    required this.busy,
    required this.fallbackPo,
    required this.fallbackStage,
    required this.onRun,
  });

  final AppController controller;
  final PurchaseRequest? request;
  final bool busy;
  final String fallbackPo;
  final String? fallbackStage;
  final Future<void> Function(PurchaseRequest item, PrAction action) onRun;

  @override
  Widget build(BuildContext context) {
    final text = S(controller.ar);
    final item = request;
    final code = item == null ? (fallbackStage ?? 'pr') : stageCode(item.stage);
    final actions = busy
        ? const <PrAction>[]
        : (item == null || controller.staff == null ? const <PrAction>[] : actionsFor(controller.staff!, item));
    final details = item == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(text.stage(code), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                if (item.stage == Stage.closed && item.closure == ClosureKind.completed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(text.stage('mrv'), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                  ),
                if (item.closure == ClosureKind.deletedBefore)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(text.deletedBefore, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 6),
                _WaitingBlock(request: item, text: text),
                if (controller.waiting.contains(item.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(text.waitingServer, style: const TextStyle(color: AppColors.warning)),
                  ),
                const SizedBox(height: 12),
                _Panel(
                  children: [
                    _InfoRow(label: text.site, value: item.siteName(controller.ar)),
                    _InfoRow(label: text.jobField, value: text.departmentLabel(item.department.name)),
                    _InfoRow(label: text.type, value: text.typeLabel(item.type.name)),
                    _InfoRow(label: text.notes, value: item.details),
                    if (item.poAnchorAt != null)
                      _InfoRow(label: text.sinceProcurement, value: formatWhen(item.poAnchorAt!, controller.ar)),
                    _InfoRow(label: text.currentStage, value: formatWhen(item.stageStartedAt, controller.ar)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(text.flowMap, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _StageMap(request: item, text: text),
                const SizedBox(height: 16),
                Text(text.timeline, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final visit in item.visits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            margin: const EdgeInsetsDirectional.only(end: 10),
                            decoration: BoxDecoration(
                              color: _stageColor(visit.stage),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Expanded(
                            child: _Panel(
                              children: [
                                if (visit.action.isNotEmpty)
                                  _InfoRow(label: text.eventAction, value: text.actionLabel(visit.action, stageCode(visit.stage))),
                                _InfoRow(label: text.currentStage, value: text.stage(stageCode(visit.stage))),
                                _InfoRow(label: text.actionAt, value: formatWhen(visit.startedAt, controller.ar)),
                                if (visit.endedAt != null && visit.endedAt != visit.startedAt)
                                  _InfoRow(
                                    label: text.period,
                                    value: formatPeriod(visit.startedAt, visit.endedAt!, text),
                                    valueColor: AppColors.muted,
                                  ),
                                if (visit.endedAt == null)
                                  _InfoRow(label: text.log, value: text.ongoing),
                                if (visit.note.isNotEmpty) _InfoRow(label: text.notes, value: visit.note),
                                _InfoRow(label: text.name, value: '${visit.actorName} · ${visit.actorUsername}'),
                                if (visit.actorJob.isNotEmpty) _InfoRow(label: text.jobField, value: text.job(visit.actorJob)),
                                if (visit.imageUrl != null) _Photo(url: visit.imageUrl!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(item?.displayPo ?? fallbackPo)),
      body: Stack(
        children: [
          details,
          if (busy && item != null)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Color(0x99F4F7FB),
                  child: Align(
                    alignment: Alignment(0, -0.72),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: actions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BusyButton(
                          label: text.actionLabel(action.name, _targetCode(item!, action)),
                          busy: false,
                          onPressed: () => onRun(item, action),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

String _targetCode(PurchaseRequest request, PrAction action) {
  switch (action) {
    case PrAction.approveMr:
      return 'pr';
    case PrAction.advance:
      return stageCode(forwardStage(request.stage) ?? request.stage);
    case PrAction.alternative:
    case PrAction.approveTir:
      return action == PrAction.approveTir ? 'mrv' : 'tir';
    case PrAction.rejectTir:
      return 'do';
    case PrAction.closePo:
    case PrAction.deleteNow:
    case PrAction.approveDelete:
    case PrAction.directDelete:
      return 'closed';
    default:
      return stageCode(request.stage);
  }
}

class CreatePage extends StatefulWidget {
  const CreatePage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  Scope _area = Scope.fifth;
  SiteInfo? _site;
  RequestType? _type;
  Discipline? _trade;
  final _po = TextEditingController();
  final _details = TextEditingController();
  Uint8List? _photo;
  bool _photoBusy = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final staff = widget.controller.staff;
    if (staff != null) _applyDefaults(staff);
  }

  List<SiteInfo> _sitesOf(Staff staff) {
    if (coversAllSites(staff)) {
      return _area == Scope.kourba
          ? kSites.where((site) => site.id == 'kourba').toList()
          : <SiteInfo>[...fifthMalls, siteById('gold_yard')];
    }
    return sitesFor(staff);
  }

  void _applyDefaults(Staff staff) {
    final types = typesFor(staff);
    if (_type == null && types.length == 1) _type = types.first;
    final trades = tradesFor(staff);
    if (_trade == null && trades.length == 1) _trade = trades.first;
    if (coversAllSites(staff) && _area == Scope.kourba) {
      _site = siteById('kourba');
      return;
    }
    final sites = _sitesOf(staff);
    if (_site == null && sites.length == 1) _site = sites.first;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _po.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final text = S(widget.controller.ar);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(text.camera), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(title: Text(text.gallery), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _photoBusy = true);
    final file = await ImagePicker().pickImage(source: source);
    if (file != null) _photo = await file.readAsBytes();
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _submit() async {
    final staff = widget.controller.staff;
    if (staff == null) return;
    final text = S(widget.controller.ar);
    if (!widget.controller.online) {
      _toast(text.offlineRetry);
      return;
    }
    final site = coversAllSites(staff) && _area == Scope.kourba ? siteById('kourba') : _site;
    if (site == null) {
      _toast(text.pickSite);
      return;
    }
    if (_type == null) {
      _toast(text.pickType);
      return;
    }
    final trades = tradesFor(staff);
    final trade = trades.length == 1 ? trades.first : _trade;
    if (trades.length > 1 && trade == null) {
      _toast(text.pickTrade);
      return;
    }
    if (_po.text.trim().isEmpty) {
      _toast(text.required);
      return;
    }
    if (_details.text.trim().isEmpty) {
      _toast(text.notesRequired);
      return;
    }
    final po = 'PO-${_po.text.trim()}';
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.poField),
        content: Text(text.confirmPo(po)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(text.cancel)),
          TextButton(
            onPressed: NetworkScope.of(context) ? () => Navigator.pop(context, true) : null,
            child: Text(text.confirm),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    if (!widget.controller.online) {
      _toast(text.offlineRetry);
      return;
    }
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.controller.createRequest(
        site: site,
        type: _type!,
        externalPo: _po.text,
        details: _details.text,
        photo: _photo,
        discipline: trade,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.controller.staff!;
    final text = S(widget.controller.ar);
    final wide = coversAllSites(staff);
    final sites = wide
        ? (_area == Scope.kourba
            ? kSites.where((site) => site.id == 'kourba').toList()
            : <SiteInfo>[...fifthMalls, siteById('gold_yard')])
        : sitesFor(staff);
    final types = typesFor(staff);
    final chosen = wide && _area == Scope.kourba ? siteById('kourba') : _site;
    return Scaffold(
      appBar: AppBar(title: Text(text.create)),
      body: Column(
        children: [
          if (_busy || _photoBusy) const LinearProgressIndicator(minHeight: 4),
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (wide) ...[
            DropdownButtonFormField<Scope>(
              key: ValueKey(_area),
              initialValue: _area,
              decoration: InputDecoration(labelText: text.area),
              items: [
                DropdownMenuItem(value: Scope.fifth, child: Text(text.fifthArea)),
                const DropdownMenuItem(value: Scope.kourba, child: Text('KOURBA HEIGHTS')),
              ],
              onChanged: (value) => setState(() {
                _area = value ?? Scope.fifth;
                _site = null;
                _applyDefaults(staff);
              }),
            ),
            const SizedBox(height: 12),
          ],
          if (!wide || _area == Scope.fifth)
            DropdownButtonFormField<SiteInfo>(
              key: ValueKey('${_area.name}-${_site?.id}-${sites.length}'),
              initialValue: sites.contains(chosen) ? chosen : null,
              decoration: InputDecoration(labelText: text.site),
              items: [for (final site in sites) DropdownMenuItem(value: site, child: Text(site.name(false)))],
              onChanged: (value) => setState(() => _site = value),
            )
          else
            InputDecorator(
              decoration: InputDecoration(labelText: text.site),
              child: const Text('KOURBA HEIGHTS'),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RequestType>(
            key: ValueKey(_type),
            initialValue: _type,
            decoration: InputDecoration(labelText: text.type),
            items: [for (final type in types) DropdownMenuItem(value: type, child: Text(text.typeLabel(type.name)))],
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 12),
          if (tradesFor(staff).length > 1)
            DropdownButtonFormField<Discipline>(
              key: ValueKey(_trade),
              initialValue: _trade,
              decoration: InputDecoration(labelText: text.trade),
              items: [
                for (final trade in tradesFor(staff)) DropdownMenuItem(value: trade, child: Text(text.tradeLabel(trade.name))),
              ],
              onChanged: (value) => setState(() => _trade = value),
            ),
          if (tradesFor(staff).length > 1) const SizedBox(height: 12),
          TextField(
            controller: _po,
            decoration: InputDecoration(labelText: text.poField, prefixText: 'PO-'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _details, maxLines: 4, decoration: InputDecoration(labelText: text.notes)),
          const SizedBox(height: 12),
          if (_photo != null) Image.memory(_photo!, height: 160, fit: BoxFit.cover),
          OutlinedButton(onPressed: _photoBusy || _busy || !NetworkScope.of(context) ? null : _pick, child: Text(text.attach)),
          const SizedBox(height: 16),
          if (_busy) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text.saving, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))),
          BusyButton(label: _busy ? text.saving : text.save, busy: _busy, onPressed: _submit),
        ],
      ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _group = 'all';
  String? _siteId;
  String? _type;
  String? _trade;
  String? _tabFocus;

  bool _filtersOn(bool locked) =>
      (!locked && _group != 'all') || _siteId != null || _type != null || _trade != null || _tabFocus != null;

  void _reset(bool locked) {
    setState(() {
      if (!locked) _group = 'all';
      _siteId = null;
      _type = null;
      _trade = null;
      _tabFocus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final text = S(controller.ar);
    final locked = controller.staff?.level == Level.kourbaDirector;
    final group = locked ? 'kourba' : _group;
    final sites = _visibleSites(controller).where((site) {
      if (_siteId != null) return site.id == _siteId;
      if (group == 'fifth') return site.scope == Scope.fifth;
      if (group == 'kourba') return site.id == 'kourba';
      return true;
    }).toList();
    final siteChoices = group == 'kourba'
        ? kSites.where((site) => site.id == 'kourba').toList()
        : group == 'fifth'
            ? <SiteInfo>[...fifthMalls, siteById('gold_yard')]
            : kSites;
    var fresh = 0;
    var active = 0;
    var done = 0;
    for (final site in sites) {
      fresh += _boardCount(controller, site.id, 'fresh', _type, _trade);
      active += _boardCount(controller, site.id, 'progress', _type, _trade);
      done += _boardCount(controller, site.id, 'closed', _type, _trade);
    }
    final slices = [
      _PieSlice('fresh', fresh, AppColors.primary, text.tabFresh),
      _PieSlice('progress', active, AppColors.progress, text.tabActive),
      _PieSlice('closed', done, AppColors.success, text.tabDone),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(text.dashboard)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _FilterBar(
            resetLabel: text.resetFilters,
            showReset: false,
            onReset: () => _reset(locked),
            children: [
              _FilterPick<String>(
                label: text.area,
                valueLabel: group == 'all' ? text.all : (group == 'fifth' ? text.fifthArea : 'KOURBA HEIGHTS'),
                options: [
                  if (!locked) (value: 'all', label: text.all),
                  if (!locked) (value: 'fifth', label: text.fifthArea),
                  (value: 'kourba', label: 'KOURBA HEIGHTS'),
                ],
                onSelected: locked
                    ? null
                    : (value) => setState(() {
                          _group = value;
                          _siteId = null;
                        }),
              ),
              _FilterPick<String?>(
                label: text.site,
                valueLabel: _siteId == null ? text.all : siteById(_siteId!).name(false),
                options: [
                  (value: null, label: text.all),
                  for (final site in siteChoices) (value: site.id, label: site.name(false)),
                ],
                onSelected: (value) => setState(() => _siteId = value),
              ),
              _FilterPick<String?>(
                label: text.type,
                valueLabel: _type == null ? text.all : text.typeLabel(_type!),
                options: [
                  (value: null, label: text.all),
                  for (final type in RequestType.values) (value: type.name, label: text.typeLabel(type.name)),
                ],
                onSelected: (value) => setState(() => _type = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatTile(
            label: text.totalRequests,
            value: fresh + active + done,
            color: AppColors.primaryDark,
            selected: false,
            action: _filtersOn(locked)
                ? TextButton(
                    onPressed: () => _reset(locked),
                    child: Text(text.resetFilters, style: const TextStyle(fontWeight: FontWeight.w800)),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatTile(label: text.tabFresh, value: fresh, color: AppColors.primary, selected: _tabFocus == 'fresh', onTap: () => setState(() => _tabFocus = _tabFocus == 'fresh' ? null : 'fresh'))),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(label: text.tabActive, value: active, color: AppColors.progress, selected: _tabFocus == 'progress', onTap: () => setState(() => _tabFocus = _tabFocus == 'progress' ? null : 'progress'))),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(label: text.tabDone, value: done, color: AppColors.success, selected: _tabFocus == 'closed', onTap: () => setState(() => _tabFocus = _tabFocus == 'closed' ? null : 'closed'))),
            ],
          ),
          const SizedBox(height: 10),
          _TradeGrid(
            allLabel: text.all,
            selected: _trade,
            labels: [for (final trade in kFilterTrades) (id: trade.name, label: text.tradeLabel(trade.name))],
            onSelect: (value) => setState(() => _trade = value == _trade ? null : value),
          ),
          const SizedBox(height: 16),
          _Panel(
            children: [
              Center(
                child: _PieChart(
                  slices: slices,
                  selected: _tabFocus,
                  onSelect: (id) => setState(() => _tabFocus = _tabFocus == id ? null : id),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final slice in slices)
                    InkWell(
                      onTap: () => setState(() => _tabFocus = _tabFocus == slice.id ? null : slice.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('${slice.label} ${slice.value}', style: TextStyle(fontWeight: _tabFocus == slice.id ? FontWeight.w800 : FontWeight.w500, color: _tabFocus == slice.id ? slice.color : AppColors.ink)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final site in sites)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _siteId = _siteId == site.id ? null : site.id),
                child: _Panel(
                  borderColor: AppColors.primary.withValues(alpha: 0.28),
                  children: [
                    Text(
                      site.name(false),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 6),
                    if (_tabFocus == null || _tabFocus == 'fresh')
                      _InfoRow(label: text.tabFresh, value: '${_boardCount(controller, site.id, 'fresh', _type, _trade)}'),
                    if (_tabFocus == null || _tabFocus == 'progress')
                      _InfoRow(label: text.tabActive, value: '${_boardCount(controller, site.id, 'progress', _type, _trade)}'),
                    if (_tabFocus == null || _tabFocus == 'closed')
                      _InfoRow(label: text.tabDone, value: '${_boardCount(controller, site.id, 'closed', _type, _trade)}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final List<Map<String, dynamic>> _fresh = [];
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _users;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('users');
    if (controller.staff?.level == Level.kourbaDirector) {
      query = query.where('scope', isEqualTo: 'kourba');
    }
    _users = query.limit(100).snapshots();
  }

  String _place(Map<String, dynamic> data, S text) {
    final home = data['homeSiteId']?.toString() ?? '';
    if (home.isNotEmpty) return siteById(home).name(false);
    switch (data['scope']?.toString()) {
      case 'company':
        return text.allSitesLabel;
      case 'kourba':
        return 'KOURBA HEIGHTS';
      case 'fifth':
        return text.fifthArea;
      default:
        return '';
    }
  }

  String _status(Map<String, dynamic> data, S text) {
    if (data['removed'] == true) return text.removedUser;
    if (data['active'] == false) return text.disabledUser;
    return text.activeUser;
  }

  bool _flag(dynamic value, bool fallback) => value == null ? fallback : value == true;

  bool _same(Map<String, dynamic> live, Map<String, dynamic> local) {
    return live['name'] == local['name'] &&
        live['username'] == local['username'] &&
        live['job'] == local['job'] &&
        live['scope'] == local['scope'] &&
        live['homeSiteId'] == local['homeSiteId'] &&
        live['discipline'] == local['discipline'] &&
        _flag(live['active'], true) == _flag(local['active'], true) &&
        _flag(live['removed'], false) == _flag(local['removed'], false);
  }

  void _remember(Map<String, dynamic> data) {
    final uid = data['uid'];
    _fresh.removeWhere((row) => row['uid'] == uid);
    _fresh.add(data);
  }

  String _explain(String? code, S text) {
    if (code == 'username' || code == 'already-exists') return text.usernameTaken;
    if (code == 'username_format') return text.usernameFormat;
    if (code == 'password') return text.weakPassword;
    if (code == 'create_failed' || code == 'profile') return text.createUserFailed;
    return text.genericError;
  }

  Future<void> _confirmThen(String title, String body, Future<String?> Function() action) async {
    final text = S(controller.ar);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(text.cancel)),
          TextButton(
            onPressed: NetworkScope.of(context) ? () => Navigator.pop(context, true) : null,
            child: Text(text.confirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final error = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error == null ? text.userSaved : _explain(error, text))));
  }

  @override
  Widget build(BuildContext context) {
    final text = S(controller.ar);
    return Scaffold(
      appBar: AppBar(title: Text(text.users)),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.online ? () => _edit(null) : null,
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(text.genericError));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final server = <String, Map<String, dynamic>>{
            for (final doc in snap.data!.docs) doc.id: {'uid': doc.id, ...doc.data()},
          };
          final freshIds = _fresh.map((row) => row['uid']).toSet();
          final rows = <Map<String, dynamic>>[
            for (final row in server.values)
              if (!freshIds.contains(row['uid'])) row,
            ..._fresh,
          ];
          final stale = [
            for (final row in _fresh)
              if (server[row['uid']] != null && _same(server[row['uid']]!, row)) row['uid'],
          ];
          if (stale.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _fresh.removeWhere((row) => stale.contains(row['uid'])));
            });
          }
          rows.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
          if (rows.isEmpty) return Center(child: Text(text.noUsers));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: rows.length,
            itemBuilder: (context, index) => _userCard(rows[index], text),
          );
        },
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> data, S text) {
    final uid = data['uid']?.toString() ?? '';
    final own = uid == controller.staff?.uid;
    final removed = data['removed'] == true;
    final active = data['active'] != false && !removed;
    final name = data['name']?.toString() ?? '';
    final code = data['job']?.toString() ?? '';
    final job = code.isNotEmpty ? text.job(code) : (data['level'] == 'executive' ? text.executiveTitle : '');
    final trade = data['discipline']?.toString();
    final place = _place(data, text);
    final username = data['username']?.toString() ?? '';
    final online = NetworkScope.of(context);
    return _Panel(
      borderColor: AppColors.primary.withValues(alpha: 0.28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              child: Text(_initials(name), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (username.isNotEmpty) Text(username, style: const TextStyle(color: AppColors.muted)),
                  if (job.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(job, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (place.isNotEmpty) Text(place, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  if (trade == 'electrical' || trade == 'mechanical') Text(trade == 'electrical' ? text.electrical : text.mechanical, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            _Chip(label: _status(data, text)),
          ],
        ),
        if (!own && !removed) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: online ? () => _edit(data) : null, child: Text(text.editUser)),
              OutlinedButton(onPressed: online ? () => _resetPassword(data) : null, child: Text(text.resetPassword)),
              OutlinedButton(
                onPressed: online
                    ? () => _confirmThen(
                          active ? text.disableUser : text.enableUser,
                          active ? text.disableUserBody(name) : text.enableUserBody(name),
                          () async {
                            final error = await controller.setUserActive(uid, !active);
                            if (error == null && mounted) setState(() => _remember({...data, 'active': !active, 'removed': false}));
                            return error;
                          },
                        )
                    : null,
                child: Text(active ? text.disableUser : text.enableUser),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.45)),
                ),
                onPressed: online
                    ? () => _confirmThen(text.deleteUserTitle, text.deleteUserBody(name), () async {
                          final error = await controller.deleteUser(uid);
                          if (error == null && mounted) setState(() => _remember({...data, 'active': false, 'removed': true}));
                          return error;
                        })
                    : null,
                child: Text(text.delete),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final text = S(controller.ar);
    final admin = controller.staff!;
    final username = TextEditingController(text: existing?['username']?.toString() ?? '');
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final password = TextEditingController();
    final jobs = jobsFor(admin.level);
    var job = jobs.first;
    for (final item in jobs) {
      if (item.name == existing?['job']) job = item;
    }
    var area = existing?['scope'] == 'kourba' || admin.level == Level.kourbaDirector ? Scope.kourba : Scope.fifth;
    String? mall = existing?['homeSiteId']?.toString();
    if (mall == null || mall.isEmpty) mall = fifthMalls.first.id;
    var trade = existing?['discipline'] == 'mechanical' ? Discipline.mechanical : Discipline.electrical;
    var busy = false;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final spec = specFor(job);
          return AlertDialog(
            title: Text(existing == null ? text.addUser : text.editUser),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: username, decoration: InputDecoration(labelText: text.username)),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: InputDecoration(labelText: text.name)),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: password,
                    label: existing == null ? text.password : text.optionalPassword,
                    text: text,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<JobTitle>(
                    key: ValueKey(job),
                    initialValue: job,
                    decoration: InputDecoration(labelText: text.jobField),
                    items: [for (final item in jobs) DropdownMenuItem(value: item, child: Text(text.job(item.name)))],
                    onChanged: (value) => setLocal(() => job = value ?? job),
                  ),
                  if (spec.needsMall) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(mall),
                      initialValue: mall,
                      decoration: InputDecoration(labelText: text.site),
                      items: [for (final site in fifthMalls) DropdownMenuItem(value: site.id, child: Text(site.name(false)))],
                      onChanged: (value) => setLocal(() => mall = value ?? mall),
                    ),
                  ],
                  if (spec.needsArea && admin.level != Level.kourbaDirector) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Scope>(
                      key: ValueKey(area),
                      initialValue: area,
                      decoration: InputDecoration(labelText: text.area),
                      items: [
                        DropdownMenuItem(value: Scope.fifth, child: Text(text.fifthArea)),
                        const DropdownMenuItem(value: Scope.kourba, child: Text('KOURBA HEIGHTS')),
                      ],
                      onChanged: (value) => setLocal(() => area = value ?? area),
                    ),
                  ],
                  if (spec.needsTrade) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Discipline>(
                      key: ValueKey(trade),
                      initialValue: trade,
                      decoration: InputDecoration(labelText: text.trade),
                      items: [
                        DropdownMenuItem(value: Discipline.electrical, child: Text(text.electrical)),
                        DropdownMenuItem(value: Discipline.mechanical, child: Text(text.mechanical)),
                      ],
                      onChanged: (value) => setLocal(() => trade = value ?? trade),
                    ),
                  ],
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: AppColors.danger))),
                ],
              ),
            ),
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(text.cancel)),
              TextButton(
                onPressed: busy || !NetworkScope.of(context)
                    ? null
                    : () async {
                        if (username.text.trim().isEmpty || name.text.trim().isEmpty) {
                          setLocal(() => error = text.required);
                          return;
                        }
                        final rawName = username.text.trim();
                        if (rawName.contains('/') || RegExp(r'\s').hasMatch(rawName) || rawName == '.' || rawName == '..') {
                          setLocal(() => error = text.usernameFormat);
                          return;
                        }
                        final nextPassword = password.text.trim();
                        if ((existing == null || nextPassword.isNotEmpty) && nextPassword.length < 6) {
                          setLocal(() => error = text.weakPassword);
                          return;
                        }
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        final spec = specFor(job);
                        final chosenArea = spec.needsArea ? area : spec.scope;
                        final department = (job == JobTitle.civilEngineer || job == JobTitle.civilManager) && chosenArea == Scope.kourba
                            ? Department.civilKourba
                            : spec.department;
                        final payload = <String, dynamic>{
                          if (existing != null) 'uid': existing['uid'],
                          'username': username.text.trim().toLowerCase(),
                          'name': name.text.trim(),
                          if (nextPassword.isNotEmpty) 'password': nextPassword,
                          'job': job.name,
                          'level': spec.level.name,
                          'department': department.name,
                          'scope': chosenArea.name,
                          'sector': spec.sector.name,
                          if (spec.needsTrade) 'discipline': trade.name,
                          if (!spec.needsTrade && spec.discipline != null) 'discipline': spec.discipline!.name,
                          if (spec.needsMall) 'homeSiteId': mall,
                        };
                        final result = await controller.upsertUser(payload);
                        if (!context.mounted || !mounted) return;
                        if (result != null && result.startsWith('ok:')) {
                          final uid = result.substring(3);
                          setState(() {
                            _fresh.removeWhere((row) => row['uid'] == uid);
                            _fresh.add({...payload, 'uid': uid, 'active': existing?['active'] != false, 'removed': false});
                          });
                          Navigator.pop(context, true);
                          return;
                        }
                        setLocal(() {
                          busy = false;
                          error = _explain(result?.replaceFirst('err:', ''), text);
                        });
                      },
                child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(text.save),
              ),
            ],
          );
        },
      ),
    );
    username.dispose();
    name.dispose();
    password.dispose();
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.userSaved)));
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> data) async {
    final text = S(controller.ar);
    final password = TextEditingController();
    var busy = false;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(text.resetPassword),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text.resetPasswordBody(data['name']?.toString() ?? '')),
                const SizedBox(height: 12),
                PasswordField(controller: password, label: text.newPassword, text: text),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: Text(text.cancel)),
              TextButton(
                onPressed: busy || !NetworkScope.of(context)
                    ? null
                    : () async {
                        final next = password.text.trim();
                        if (next.length < 6) {
                          setLocal(() => error = text.weakPassword);
                          return;
                        }
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        final result = await controller.resetUserPassword(data['uid']?.toString() ?? '', next);
                        if (!context.mounted) return;
                        if (result == null) {
                          Navigator.pop(context, true);
                          return;
                        }
                        setLocal(() {
                          busy = false;
                          error = _explain(result, text);
                        });
                      },
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(text.save),
              ),
            ],
          );
        },
      ),
    );
    password.dispose();
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.userSaved)));
    }
  }
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = S(controller.ar);
    final rows = controller.inbox;
    return Scaffold(
      appBar: AppBar(title: Text(text.notifications)),
      body: !controller.inboxLoaded
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? Center(child: Text(text.noNotifications))
              : ListView.builder(
                  itemCount: rows.length + (controller.inboxHasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == rows.length) {
                      return TextButton(
                        onPressed: !controller.online || controller.inboxLoadingMore ? null : controller.loadMoreInbox,
                        child: Text(text.loadMore),
                      );
                    }
                    final item = rows[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          controller.markInboxRead();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DetailPage(
                                controller: controller,
                                requestId: item['requestId']?.toString() ?? '',
                                fallbackPo: item['displayPo']?.toString(),
                                fallbackStage: item['stage']?.toString(),
                              ),
                            ),
                          );
                        },
                        child: _StripeCard(
                          color: AppColors.progress,
                          ar: controller.ar,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(item['body']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final text = S(widget.controller.ar);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.settings),
        actions: [
          IconButton(
            tooltip: text.help,
            onPressed: () => _openHelpImage(context),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: text.language,
            onPressed: () => widget.controller.setLanguage(!widget.controller.ar),
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(staff: widget.controller.staff!, text: text),
          const SizedBox(height: 16),
          PasswordField(controller: _current, label: text.currentPassword, text: text),
          const SizedBox(height: 12),
          PasswordField(controller: _next, label: text.newPassword, text: text),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 16),
          BusyButton(
            label: text.changePassword,
            busy: _busy,
            onPressed: () async {
              setState(() {
                _busy = true;
                _error = null;
              });
              try {
                await widget.controller.changePassword(_current.text, _next.text);
              } catch (error) {
                _error = text.genericError;
              }
              if (mounted) setState(() => _busy = false);
            },
          ),
          TextButton(onPressed: widget.controller.signOut, child: Text(text.signOut)),
        ],
      ),
    );
  }
}

class ForcePasswordPage extends StatefulWidget {
  const ForcePasswordPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ForcePasswordPage> createState() => _ForcePasswordPageState();
}

class _ForcePasswordPageState extends State<ForcePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = S(widget.controller.ar);
    return Scaffold(
      appBar: AppBar(title: Text(text.mustChangePassword)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(staff: widget.controller.staff!, text: text),
          const SizedBox(height: 16),
          PasswordField(controller: _current, label: text.currentPassword, text: text),
          const SizedBox(height: 12),
          PasswordField(controller: _next, label: text.newPassword, text: text),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 16),
          BusyButton(
            label: text.changePassword,
            busy: _busy,
            onPressed: () async {
              setState(() {
                _busy = true;
                _error = null;
              });
              try {
                await widget.controller.changePassword(_current.text, _next.text);
              } catch (_) {
                _error = text.genericError;
              }
              if (mounted) setState(() => _busy = false);
            },
          ),
          TextButton(onPressed: widget.controller.signOut, child: Text(text.signOut)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.staff, required this.text});
  final Staff staff;
  final S text;

  @override
  Widget build(BuildContext context) {
    final job = staff.job.isNotEmpty
        ? text.job(staff.job)
        : (staff.level == Level.executive ? text.executiveTitle : text.job(staff.level == Level.kourbaDirector ? 'kourbaDirector' : ''));
    return _Panel(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              child: Text(_initials(staff.name), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(staff.username),
                  if (job.isNotEmpty) Text(job, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, required this.text});
  final TextEditingController controller;
  final String label;
  final S text;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _hidden ? widget.text.showPassword : widget.text.hidePassword,
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
      ),
    );
  }
}

class _WaitingBlock extends StatelessWidget {
  const _WaitingBlock({required this.request, required this.text});
  final PurchaseRequest request;
  final S text;

  @override
  Widget build(BuildContext context) {
    if (request.deletion == DeletionStatus.pending) {
      final who = request.deletionByUsername.isNotEmpty ? request.deletionByUsername : request.deletionByName;
      return Text(text.deletionAskedBy(who), style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700));
    }
    if (request.stage == Stage.tir) {
      final job = request.creatorJob.isEmpty ? '' : text.job(request.creatorJob);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.waitingFor, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          Text(request.creatorUsername, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (job.isNotEmpty) Text(job, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      );
    }
    final code = stageCode(request.stage);
    return Text(
      '${text.waitingFor}: ${text.waiting(code, kourba: request.scope == Scope.kourba, department: request.department.name)}',
    );
  }
}

class NetworkScope extends InheritedWidget {
  const NetworkScope({super.key, required this.online, required super.child});
  final bool online;

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NetworkScope>()?.online ?? true;
  }

  @override
  bool updateShouldNotify(NetworkScope oldWidget) => oldWidget.online != online;
}

class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.busy, required this.onPressed});
  final String label;
  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final blocked = busy || !NetworkScope.of(context);
    return FilledButton(
      onPressed: blocked ? null : () { onPressed(); },
      child: busy
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 10),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            )
          : Text(label),
    );
  }
}

String _failureMessage(String? code, String po, S text) {
  if (code == 'po_exists') return text.poExists;
  if (code == 'po_format') return text.poFormat;
  if (code == 'note_required') return text.notesRequired;
  if (code == 'offline') return text.offlineRetry;
  if (code == 'image') return text.imageBad;
  return text.updateFailed(po);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.borderColor});
  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _StripeCard extends StatelessWidget {
  const _StripeCard({required this.color, required this.ar, required this.child});
  final Color color;
  final bool ar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.horizontal(right: ar ? const Radius.circular(16) : Radius.zero, left: ar ? Radius.zero : const Radius.circular(16)),
              ),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.all(14), child: child)),
          ],
        ),
      ),
    );
  }
}

class _NeedActionChip extends StatefulWidget {
  const _NeedActionChip({required this.label});
  final String label;

  @override
  State<_NeedActionChip> createState() => _NeedActionChipState();
}

class _NeedActionChipState extends State<_NeedActionChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: _Chip(label: widget.label, danger: true),
    );
  }
}

void _openHelpImage(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      pageBuilder: (context, animation, secondaryAnimation) => const _HelpImagePage(),
    ),
  );
}

class _HelpImagePage extends StatelessWidget {
  const _HelpImagePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.asset('assets/pr_track.jpg', fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final cleaned = name.trim();
  if (cleaned.isEmpty) return '?';
  return Characters(cleaned).take(2).toString();
}

class _StageMap extends StatelessWidget {
  const _StageMap({required this.request, required this.text});
  final PurchaseRequest request;
  final S text;

  @override
  Widget build(BuildContext context) {
    final reached = <Stage>{};
    for (final visit in request.visits) {
      if (visit.stage != Stage.closed) reached.add(visit.stage);
    }
    Stage? last;
    for (final visit in request.visits.reversed) {
      if (visit.stage != Stage.closed) {
        last = visit.stage;
        break;
      }
    }
    last ??= request.stage == Stage.closed ? null : request.stage;
    final frozen = request.stage == Stage.closed || request.deletion == DeletionStatus.pending;
    return _Panel(
      children: [
        Text(text.flowchart, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        for (var i = 0; i < kMapStages.length; i++) ...[
          _MapStep(
            index: i + 1,
            label: text.stage(stageCode(kMapStages[i])),
            tone: _mapTone(kMapStages[i], reached: reached, last: last, frozen: frozen, current: request.stage),
          ),
          if (i < kMapStages.length - 1)
            Container(
              margin: const EdgeInsetsDirectional.only(start: 15, top: 2, bottom: 2),
              width: 2,
              height: 10,
              color: _mapTone(kMapStages[i], reached: reached, last: last, frozen: frozen, current: request.stage) == _MapTone.skipped
                  ? AppColors.line
                  : AppColors.primary.withValues(alpha: 0.35),
            ),
        ],
      ],
    );
  }
}

enum _MapTone { done, current, skipped }

_MapTone _mapTone(
  Stage stage, {
  required Set<Stage> reached,
  required Stage? last,
  required bool frozen,
  required Stage current,
}) {
  if (frozen) {
    if (last != null && stage == last) return _MapTone.current;
    if (reached.contains(stage)) return _MapTone.done;
    return _MapTone.skipped;
  }
  if (stage == current) return _MapTone.current;
  if (reached.contains(stage)) return _MapTone.done;
  return _MapTone.skipped;
}

class _MapStep extends StatelessWidget {
  const _MapStep({required this.index, required this.label, required this.tone});
  final int index;
  final String label;
  final _MapTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _MapTone.done => AppColors.success,
      _MapTone.current => AppColors.progress,
      _MapTone.skipped => AppColors.muted,
    };
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: tone == _MapTone.skipped ? 0.08 : 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: tone == _MapTone.current ? 2 : 1),
          ),
          child: Text('$index', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: tone == _MapTone.skipped ? AppColors.muted : AppColors.ink,
              fontWeight: tone == _MapTone.current ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _stageBadge(Stage stage, S text) {
  if (stage == Stage.closed) return text.stage('closed');
  final index = kMapStages.indexOf(stage);
  if (index < 0) return text.stage(stageCode(stage));
  return '${text.stageIndex(index + 1)}  ${text.stage(stageCode(stage))}';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.danger = false});
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (danger ? AppColors.danger : AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: danger ? AppColors.danger : AppColors.primaryDark, fontWeight: FontWeight.w700)),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => const SizedBox(
            height: 80,
            child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.muted)),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.children, required this.resetLabel, required this.showReset, required this.onReset});
  final List<Widget> children;
  final String resetLabel;
  final bool showReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...children.map((child) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: child)),
          if (showReset)
            TextButton(
              onPressed: onReset,
              child: Text(resetLabel, maxLines: 1),
            ),
        ],
      ),
    );
  }
}

class _FilterPick<T> extends StatelessWidget {
  const _FilterPick({
    required this.label,
    required this.valueLabel,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String valueLabel;
  final List<({T value, String label})> options;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onSelected == null
          ? null
          : () async {
              final picked = await showModalBottomSheet<({T value, String label})>(
                context: context,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      for (final option in options)
                        ListTile(
                          title: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, option),
                        ),
                    ],
                  ),
                ),
              );
              if (picked != null) onSelected?.call(picked.value);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                '$label: $valueLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ListTabs extends StatelessWidget {
  const _ListTabs({
    required this.tab,
    required this.fresh,
    required this.active,
    required this.done,
    required this.onChanged,
  });

  final TabKind tab;
  final String fresh;
  final String active;
  final String done;
  final ValueChanged<TabKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _tab(TabKind.fresh, fresh),
          Container(width: 1, height: 22, color: AppColors.line),
          _tab(TabKind.progress, active),
          Container(width: 1, height: 22, color: AppColors.line),
          _tab(TabKind.closed, done),
        ],
      ),
    );
  }

  Widget _tab(TabKind value, String label) {
    final on = tab == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeGrid extends StatelessWidget {
  const _TradeGrid({
    required this.allLabel,
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  final String allLabel;
  final String? selected;
  final List<({String id, String label})> labels;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <({String? id, String label})>[
      (id: null, label: allLabel),
      for (final item in labels) (id: item.id, label: item.label),
    ];
    return Column(
      children: [
        for (var row = 0; row < items.length; row += 4)
          Padding(
            padding: EdgeInsets.only(bottom: row + 4 < items.length ? 8 : 0),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i + row < items.length
                        ? _DashChoice(
                            label: items[row + i].label,
                            selected: selected == items[row + i].id,
                            onTap: () => onSelect(items[row + i].id),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DashChoice extends StatelessWidget {
  const _DashChoice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    this.onTap,
    this.action,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final numbers = Column(
      crossAxisAlignment: action == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.line, width: selected ? 2 : 1),
        ),
        child: action == null
            ? numbers
            : Row(
                children: [
                  Expanded(child: numbers),
                  action!,
                ],
              ),
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice(this.id, this.value, this.color, this.label);
  final String id;
  final int value;
  final Color color;
  final String label;
}

class _PieChart extends StatelessWidget {
  const _PieChart({required this.slices, required this.selected, required this.onSelect});
  final List<_PieSlice> slices;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final center = const Offset(90, 90);
        final pos = details.localPosition - center;
        if (pos.distance < 28 || pos.distance > 90) return;
        var angle = math.atan2(pos.dy, pos.dx) + math.pi / 2;
        if (angle < 0) angle += math.pi * 2;
        final total = slices.fold<int>(0, (count, slice) => count + slice.value);
        if (total == 0) return;
        var start = 0.0;
        for (final slice in slices) {
          final sweep = (slice.value / total) * math.pi * 2;
          if (angle >= start && angle < start + sweep) {
            onSelect(slice.id);
            return;
          }
          start += sweep;
        }
      },
      child: CustomPaint(
        size: const Size(180, 180),
        painter: _PiePainter(slices: slices, selected: selected),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter({required this.slices, required this.selected});
  final List<_PieSlice> slices;
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final total = slices.fold<int>(0, (count, slice) => count + slice.value);
    final rect = Rect.fromCircle(center: center, radius: radius);
    if (total == 0) {
      canvas.drawCircle(center, radius, Paint()..color = AppColors.line);
      canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white);
      return;
    }
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = slice.color.withValues(alpha: selected == null || selected == slice.id ? 1 : 0.35);
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }
    canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.slices != slices;
}

Color _stageColor(Stage stage) {
  switch (stage) {
    case Stage.mr:
    case Stage.pr:
      return AppColors.primary;
    case Stage.closed:
      return AppColors.success;
    default:
      return AppColors.progress;
  }
}

String formatWhen(DateTime time, bool ar) {
  return DateFormat('d MMM yyyy, h:mm a', ar ? 'ar' : 'en').format(time.toLocal());
}

String formatPeriod(DateTime start, DateTime end, S text) {
  var hours = end.difference(start).inHours;
  if (hours < 1) return text.lessThanHour;
  final months = hours ~/ (30 * 24);
  hours %= 30 * 24;
  final days = hours ~/ 24;
  hours %= 24;
  final parts = <String>[];
  if (months > 0) parts.add(text.monthsUnit(months));
  if (days > 0) parts.add(text.daysUnit(days));
  if (hours > 0) parts.add(text.hoursUnit(hours));
  return parts.join(text.ar ? '، ' : ', ');
}

int _num(Map<String, dynamic> node, String group, String key) {
  final bucket = node[group];
  if (bucket is Map && bucket[key] is num) return (bucket[key] as num).toInt();
  return 0;
}

int _boardCount(AppController controller, String siteId, String tab, String? type, String? trade) {
  final node = _siteNode(controller, siteId);
  if (type == null && trade == null) return _num(node, 'tabs', tab);
  if (type != null && trade == null) {
    final byType = node['byType'];
    if (byType is Map && byType[type] is Map) {
      final tabs = (byType[type] as Map)['tabs'];
      if (tabs is Map && tabs[tab] is num) return (tabs[tab] as num).toInt();
    }
    return 0;
  }
  if (type == null && trade != null) {
    final byDiscipline = node['byDiscipline'];
    if (byDiscipline is Map && byDiscipline[trade] is Map) {
      final tabs = (byDiscipline[trade] as Map)['tabs'];
      if (tabs is Map && tabs[tab] is num) return (tabs[tab] as num).toInt();
    }
    return 0;
  }
  final byType = node['byType'];
  if (byType is Map && byType[type] is Map) {
    final nested = (byType[type] as Map)['byDiscipline'];
    if (nested is Map && nested[trade] is Map) {
      final tabs = (nested[trade] as Map)['tabs'];
      if (tabs is Map && tabs[tab] is num) return (tabs[tab] as num).toInt();
    }
  }
  return 0;
}

Map<String, dynamic> _siteNode(AppController controller, String siteId) {
  final sites = controller.stats['sites'];
  if (sites is! Map || sites[siteId] is! Map) return const {};
  return Map<String, dynamic>.from(sites[siteId] as Map);
}

List<SiteInfo> _visibleSites(AppController controller) {
  if (controller.staff?.level == Level.kourbaDirector) {
    return kSites.where((site) => site.id == 'kourba').toList();
  }
  return kSites;
}
