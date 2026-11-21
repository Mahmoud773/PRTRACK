import 'catalog.dart';

class Staff {
  const Staff({
    required this.uid,
    required this.username,
    required this.name,
    required this.scope,
    required this.sector,
    required this.department,
    required this.level,
    required this.active,
    this.discipline,
    this.homeSiteId,
    this.lang = 'ar',
    this.unread = 0,
    this.job = '',
    this.mustChangePassword = false,
  });

  final String uid;
  final String username;
  final String name;
  final Scope scope;
  final Sector sector;
  final Department department;
  final Level level;
  final Discipline? discipline;
  final String? homeSiteId;
  final bool active;
  final String lang;
  final int unread;
  final String job;
  final bool mustChangePassword;

  bool get ar => lang != 'en';

  Staff copyWith({String? lang, int? unread, bool? active}) {
    return Staff(
      uid: uid,
      username: username,
      name: name,
      scope: scope,
      sector: sector,
      department: department,
      level: level,
      discipline: discipline,
      homeSiteId: homeSiteId,
      active: active ?? this.active,
      lang: lang ?? this.lang,
      unread: unread ?? this.unread,
      job: job,
      mustChangePassword: mustChangePassword,
    );
  }
}

class Visit {
  const Visit({
    required this.stage,
    required this.startedAt,
    this.endedAt,
    this.note = '',
    this.imageUrl,
    this.actorName = '',
    this.actorUsername = '',
    this.actorJob = '',
    this.action = '',
  });

  final Stage stage;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String note;
  final String? imageUrl;
  final String actorName;
  final String actorUsername;
  final String actorJob;
  final String action;
}

class PurchaseRequest {
  const PurchaseRequest({
    required this.id,
    required this.requestNo,
    required this.externalPo,
    required this.creatorUid,
    required this.creatorName,
    required this.creatorUsername,
    this.creatorJob = '',
    required this.department,
    required this.scope,
    required this.siteId,
    required this.siteAr,
    required this.siteEn,
    required this.type,
    required this.discipline,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    required this.stageStartedAt,
    required this.details,
    this.poAnchorAt,
    this.imageUrl,
    this.mrRejected = false,
    this.closure = ClosureKind.none,
    this.deletion = DeletionStatus.none,
    this.deletionReason = '',
    this.deletionByName = '',
    this.deletionByUsername = '',
    this.deletionByJob = '',
    this.executiveVisible = true,
    this.procurementVisible = false,
    this.warehouseFifthOfficer = false,
    this.warehouseFifthManager = false,
    this.warehouseKourba = false,
    this.cycle = 1,
    this.alternativeNote = '',
    this.visits = const [],
  });

  final String id;
  final String requestNo;
  final String externalPo;
  final String creatorUid;
  final String creatorName;
  final String creatorUsername;
  final String creatorJob;
  final Department department;
  final Scope scope;
  final String siteId;
  final String siteAr;
  final String siteEn;
  final RequestType type;
  final Discipline discipline;
  final Stage stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime stageStartedAt;
  final DateTime? poAnchorAt;
  final String details;
  final String? imageUrl;
  final bool mrRejected;
  final ClosureKind closure;
  final DeletionStatus deletion;
  final String deletionReason;
  final String deletionByName;
  final String deletionByUsername;
  final String deletionByJob;
  final bool executiveVisible;
  final bool procurementVisible;
  final bool warehouseFifthOfficer;
  final bool warehouseFifthManager;
  final bool warehouseKourba;
  final int cycle;
  final String alternativeNote;
  final List<Visit> visits;

  String get displayPo => 'PO-$externalPo';

  TabKind get tab => tabFor(stage);

  String siteName(bool ar) => ar ? siteAr : siteEn;

  PurchaseRequest copyWith({
    Stage? stage,
    DateTime? updatedAt,
    DateTime? stageStartedAt,
    DateTime? poAnchorAt,
    bool? mrRejected,
    ClosureKind? closure,
    DeletionStatus? deletion,
    String? deletionReason,
    String? deletionByName,
    String? deletionByUsername,
    String? deletionByJob,
    bool? executiveVisible,
    bool? procurementVisible,
    bool? warehouseFifthOfficer,
    bool? warehouseFifthManager,
    bool? warehouseKourba,
    int? cycle,
    String? alternativeNote,
    String? imageUrl,
    String? details,
    List<Visit>? visits,
    String? requestNo,
    String? id,
  }) {
    return PurchaseRequest(
      id: id ?? this.id,
      requestNo: requestNo ?? this.requestNo,
      externalPo: externalPo,
      creatorUid: creatorUid,
      creatorName: creatorName,
      creatorUsername: creatorUsername,
      creatorJob: creatorJob,
      department: department,
      scope: scope,
      siteId: siteId,
      siteAr: siteAr,
      siteEn: siteEn,
      type: type,
      discipline: discipline,
      stage: stage ?? this.stage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stageStartedAt: stageStartedAt ?? this.stageStartedAt,
      poAnchorAt: poAnchorAt ?? this.poAnchorAt,
      details: details ?? this.details,
      imageUrl: imageUrl ?? this.imageUrl,
      mrRejected: mrRejected ?? this.mrRejected,
      closure: closure ?? this.closure,
      deletion: deletion ?? this.deletion,
      deletionReason: deletionReason ?? this.deletionReason,
      deletionByName: deletionByName ?? this.deletionByName,
      deletionByUsername: deletionByUsername ?? this.deletionByUsername,
      deletionByJob: deletionByJob ?? this.deletionByJob,
      executiveVisible: executiveVisible ?? this.executiveVisible,
      procurementVisible: procurementVisible ?? this.procurementVisible,
      warehouseFifthOfficer: warehouseFifthOfficer ?? this.warehouseFifthOfficer,
      warehouseFifthManager: warehouseFifthManager ?? this.warehouseFifthManager,
      warehouseKourba: warehouseKourba ?? this.warehouseKourba,
      cycle: cycle ?? this.cycle,
      alternativeNote: alternativeNote ?? this.alternativeNote,
      visits: visits ?? this.visits,
    );
  }
}

class AppEvent {
  const AppEvent({
    required this.username,
    required this.name,
    required this.at,
    required this.action,
    this.note = '',
  });

  final String username;
  final String name;
  final DateTime at;
  final String action;
  final String note;
}
