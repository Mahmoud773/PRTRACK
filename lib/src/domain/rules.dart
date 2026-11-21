import 'catalog.dart';
import 'models.dart';

class RuleException implements Exception {
  const RuleException(this.code);
  final String code;
}

bool canCreate(Staff staff) {
  if (!staff.active) return false;
  if (staff.level == Level.engineer || staff.level == Level.mallOpsManager) {
    return true;
  }
  return staff.level == Level.deptManager &&
      (staff.department == Department.civilFifth ||
          staff.department == Department.civilKourba);
}

bool skipsApproval(Staff staff) =>
    staff.level == Level.deptManager &&
    (staff.department == Department.civilFifth ||
        staff.department == Department.civilKourba);

List<RequestType> typesFor(Staff staff) {
  if (staff.department == Department.civilFifth ||
      staff.department == Department.civilKourba) {
    return const [RequestType.execution, RequestType.regular];
  }
  if (coversAllSites(staff)) {
    return const [RequestType.maintenance, RequestType.execution];
  }
  if (staff.sector == Sector.execution) {
    return const [RequestType.execution];
  }
  return const [RequestType.maintenance];
}

bool coversAllSites(Staff staff) =>
    staff.level == Level.engineer &&
    (staff.department == Department.lowCurrent ||
        staff.department == Department.it ||
        staff.department == Department.landscape);

Discipline disciplineFor(Staff staff, {Discipline? chosen}) {
  if (staff.department == Department.civilFifth ||
      staff.department == Department.civilKourba) {
    return Discipline.civil;
  }
  if (staff.department == Department.mallOps) {
    return Discipline.operations;
  }
  if (staff.discipline == Discipline.mep &&
      (chosen == Discipline.electrical || chosen == Discipline.mechanical)) {
    return chosen!;
  }
  return staff.discipline ?? Discipline.operations;
}

List<Discipline> tradesFor(Staff staff) {
  if (staff.discipline == Discipline.mep) {
    return const [Discipline.electrical, Discipline.mechanical];
  }
  return [disciplineFor(staff)];
}

bool goldYardAllowed(Staff staff) {
  if (staff.scope != Scope.fifth) return false;
  if (staff.department == Department.mallOps) return false;
  if (staff.level == Level.mallOpsManager) return false;
  return true;
}

List<SiteInfo> sitesFor(Staff staff) {
  if (coversAllSites(staff)) return List<SiteInfo>.from(kSites);
  if (staff.scope == Scope.kourba) {
    return kSites.where((site) => site.id == 'kourba').toList();
  }
  final home = staff.homeSiteId;
  final List<SiteInfo> base;
  if (home != null && home.isNotEmpty && home != 'gold_yard') {
    base = [siteById(home)];
  } else {
    base = List<SiteInfo>.from(fifthMalls);
  }
  if (goldYardAllowed(staff)) {
    base.add(siteById('gold_yard'));
  }
  return base;
}

Stage initialStage(Staff staff) => skipsApproval(staff) ? Stage.pr : Stage.mr;

bool _managerOf(Staff staff, PurchaseRequest request) {
  if (request.department == Department.landscape && staff.level == Level.executive) {
    return true;
  }
  return staff.level == Level.deptManager && staff.department == request.department;
}

bool _procurement(Staff staff) => staff.level == Level.procurementOfficer;

bool _fifthOfficer(Staff staff, PurchaseRequest request) =>
    request.scope == Scope.fifth &&
    staff.level == Level.warehouseOfficer &&
    staff.department == Department.warehouseFifth;

bool _fifthManager(Staff staff, PurchaseRequest request) =>
    request.scope == Scope.fifth &&
    staff.level == Level.warehouseManager &&
    staff.department == Department.warehouseFifth;

bool _kourbaStore(Staff staff, PurchaseRequest request) =>
    request.scope == Scope.kourba &&
    staff.department == Department.warehouseKourba &&
    (staff.level == Level.warehouseOfficer ||
        staff.level == Level.warehouseManager);

List<PrAction> actionsFor(Staff staff, PurchaseRequest request) {
  if (!staff.active || request.stage == Stage.closed) return const [];
  if (request.deletion == DeletionStatus.pending) {
    if (staff.level == Level.executive) {
      return const [PrAction.approveDelete, PrAction.rejectDelete];
    }
    return const [];
  }
  final actions = <PrAction>[];
  if (_managerOf(staff, request)) {
    if (request.stage == Stage.mr) {
      if (!request.mrRejected) actions.add(PrAction.approveMr);
      actions.add(PrAction.deleteNow);
    } else if (request.department == Department.landscape &&
        staff.level == Level.executive) {
      actions.add(PrAction.directDelete);
    } else {
      actions.add(PrAction.requestDelete);
    }
  }
  if (_procurement(staff)) {
    if (forwardStage(request.stage) != null &&
        request.stage != Stage.delivery &&
        request.stage != Stage.grn) {
      actions.add(PrAction.advance);
    }
    if (request.stage == Stage.delivery || request.stage == Stage.grn) {
      actions.add(PrAction.advance);
    }
    if (request.stage == Stage.rfq || request.stage == Stage.po) {
      actions.add(PrAction.alternative);
    }
    if (request.stage == Stage.mrv) actions.add(PrAction.closePo);
  }
  if (request.stage == Stage.delivery || request.stage == Stage.grn) {
    if (_fifthOfficer(staff, request) || _kourbaStore(staff, request)) {
      actions.add(PrAction.advance);
    }
  }
  if (request.stage == Stage.mrv &&
      (_fifthManager(staff, request) || _kourbaStore(staff, request))) {
    actions.add(PrAction.closePo);
  }
  if (request.stage == Stage.tir && staff.uid == request.creatorUid) {
    actions.add(PrAction.approveTir);
    actions.add(PrAction.rejectTir);
  }
  return actions;
}

bool needsAction(Staff staff, PurchaseRequest request) {
  if (!staff.active || request.stage == Stage.closed) return false;
  if (request.deletion == DeletionStatus.pending) return staff.level == Level.executive;
  switch (request.stage) {
    case Stage.mr:
      return _managerOf(staff, request);
    case Stage.pr:
    case Stage.rfq:
    case Stage.po:
      return _procurement(staff);
    case Stage.delivery:
    case Stage.grn:
      return _procurement(staff) ||
          _fifthOfficer(staff, request) ||
          _kourbaStore(staff, request);
    case Stage.tir:
      return staff.uid == request.creatorUid;
    case Stage.mrv:
      return _procurement(staff) ||
          _fifthManager(staff, request) ||
          _kourbaStore(staff, request);
    case Stage.closed:
      return false;
  }
}

PurchaseRequest applyAction({
  required PurchaseRequest request,
  required PrAction action,
  required Staff actor,
  required DateTime now,
  String note = '',
  String? imageUrl,
}) {
  if (!actionsFor(actor, request).contains(action)) {
    throw const RuleException('forbidden');
  }
  if (action == PrAction.deleteNow ||
      action == PrAction.requestDelete ||
      action == PrAction.rejectTir ||
      action == PrAction.alternative ||
      action == PrAction.directDelete) {
    if (note.trim().isEmpty) throw const RuleException('note_required');
  }
  var next = request;
  switch (action) {
    case PrAction.approveMr:
      next = _enter(request, Stage.pr, now, actor, note, imageUrl, anchor: true, action: action.name);
      break;
    case PrAction.rejectMr:
      next = request.copyWith(
        mrRejected: true,
        updatedAt: now,
        visits: _noteVisit(request, now, actor, note, imageUrl, action.name),
      );
      break;
    case PrAction.deleteNow:
      next = request.copyWith(
        stage: Stage.closed,
        closure: ClosureKind.deletedBefore,
        executiveVisible: true,
        procurementVisible: false,
        updatedAt: now,
        deletionReason: note.trim(),
        visits: _stampClose(request, now, actor, note, imageUrl, action.name),
      );
      break;
    case PrAction.requestDelete:
      next = request.copyWith(
        deletion: DeletionStatus.pending,
        deletionReason: note.trim(),
        deletionByName: actor.name,
        deletionByUsername: actor.username,
        deletionByJob: actor.job,
        updatedAt: now,
        visits: _noteVisit(request, now, actor, note, imageUrl, action.name),
      );
      break;
    case PrAction.approveDelete:
      next = request.copyWith(
        stage: Stage.closed,
        closure: ClosureKind.deletedAfter,
        deletion: DeletionStatus.approved,
        updatedAt: now,
        visits: _stampClose(request, now, actor, note, imageUrl, action.name),
      );
      break;
    case PrAction.rejectDelete:
      next = request.copyWith(
        deletion: DeletionStatus.none,
        deletionReason: '',
        deletionByName: '',
        deletionByUsername: '',
        deletionByJob: '',
        updatedAt: now,
        visits: _noteVisit(request, now, actor, note, imageUrl, action.name),
      );
      break;
    case PrAction.advance:
      final target = forwardStage(request.stage);
      if (target == null) throw const RuleException('no_next');
      next = _enter(request, target, now, actor, note, imageUrl, anchor: false, action: action.name);
      break;
    case PrAction.alternative:
      next = _enter(
        request,
        Stage.tir,
        now,
        actor,
        note,
        imageUrl,
        anchor: false,
        action: action.name,
      ).copyWith(alternativeNote: note.trim());
      break;
    case PrAction.approveTir:
      next = _enter(request, Stage.mrv, now, actor, note, imageUrl, anchor: false, action: action.name);
      break;
    case PrAction.rejectTir:
      next = _enter(
        request,
        Stage.delivery,
        now,
        actor,
        note,
        imageUrl,
        anchor: false,
        action: action.name,
      ).copyWith(cycle: request.cycle + 1);
      break;
    case PrAction.closePo:
      next = _enter(
        request,
        Stage.closed,
        now,
        actor,
        note,
        imageUrl,
        anchor: false,
        action: action.name,
      ).copyWith(closure: ClosureKind.completed);
      break;
    case PrAction.directDelete:
      next = request.copyWith(
        stage: Stage.closed,
        closure: ClosureKind.deletedAfter,
        deletion: DeletionStatus.approved,
        updatedAt: now,
        deletionReason: note.trim(),
        visits: _stampClose(request, now, actor, note, imageUrl, action.name),
      );
      break;
  }
  return _audiences(next);
}

PurchaseRequest draftRequest({
  required Staff creator,
  required SiteInfo site,
  required RequestType type,
  required String externalPo,
  required String details,
  required DateTime now,
  String? imageUrl,
  Discipline? discipline,
}) {
  if (!canCreate(creator)) throw const RuleException('forbidden');
  if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(externalPo)) {
    throw const RuleException('po_format');
  }
  if (details.trim().isEmpty) throw const RuleException('note_required');
  final stage = initialStage(creator);
  final request = PurchaseRequest(
    id: 'local',
    requestNo: '',
    externalPo: externalPo,
    creatorUid: creator.uid,
    creatorName: creator.name,
    creatorUsername: creator.username,
    creatorJob: creator.job,
    department: creator.department,
    scope: site.scope,
    siteId: site.id,
    siteAr: site.nameAr,
    siteEn: site.nameEn,
    type: type,
    discipline: disciplineFor(creator, chosen: discipline),
    stage: stage,
    createdAt: now,
    updatedAt: now,
    stageStartedAt: now,
    poAnchorAt: stage == Stage.pr ? now : null,
    details: details.trim(),
    imageUrl: imageUrl,
    procurementVisible: stage == Stage.pr,
    visits: [
      Visit(
        stage: stage,
        startedAt: now,
        note: details.trim(),
        imageUrl: imageUrl,
        actorName: creator.name,
        actorUsername: creator.username,
        actorJob: creator.job,
        action: 'create',
      ),
    ],
  );
  return _audiences(request);
}

PurchaseRequest _enter(
  PurchaseRequest request,
  Stage stage,
  DateTime now,
  Staff actor,
  String note,
  String? imageUrl, {
  required bool anchor,
  String action = '',
}) {
  final closedVisits = request.visits.map((visit) {
    if (visit.endedAt != null) return visit;
    return Visit(
      stage: visit.stage,
      startedAt: visit.startedAt,
      endedAt: now,
      note: visit.note,
      imageUrl: visit.imageUrl,
      actorName: visit.actorName,
      actorUsername: visit.actorUsername,
      actorJob: visit.actorJob,
      action: visit.action,
    );
  }).toList();
  closedVisits.add(
    Visit(
      stage: stage,
      startedAt: now,
      note: note.trim(),
      imageUrl: imageUrl,
      actorName: actor.name,
      actorUsername: actor.username,
      actorJob: actor.job,
      action: action,
    ),
  );
  return request.copyWith(
    stage: stage,
    updatedAt: now,
    stageStartedAt: now,
    poAnchorAt: anchor ? (request.poAnchorAt ?? now) : request.poAnchorAt,
    mrRejected: false,
    visits: closedVisits,
    imageUrl: imageUrl ?? request.imageUrl,
  );
}

List<Visit> _noteVisit(
  PurchaseRequest request,
  DateTime now,
  Staff actor,
  String note,
  String? imageUrl,
  String action,
) {
  final visits = List<Visit>.from(request.visits);
  visits.add(
    Visit(
      stage: request.stage,
      startedAt: now,
      endedAt: now,
      note: note.trim(),
      imageUrl: imageUrl,
      actorName: actor.name,
      actorUsername: actor.username,
      actorJob: actor.job,
      action: action,
    ),
  );
  return visits;
}

List<Visit> _stampClose(
  PurchaseRequest request,
  DateTime now,
  Staff actor,
  String note,
  String? imageUrl,
  String action,
) {
  final visits = request.visits.map((visit) {
    if (visit.endedAt != null) return visit;
    return Visit(
      stage: visit.stage,
      startedAt: visit.startedAt,
      endedAt: now,
      note: visit.note,
      imageUrl: visit.imageUrl,
      actorName: visit.actorName,
      actorUsername: visit.actorUsername,
      actorJob: visit.actorJob,
      action: visit.action,
    );
  }).toList();
  visits.add(
    Visit(
      stage: Stage.closed,
      startedAt: now,
      endedAt: now,
      note: note.trim(),
      imageUrl: imageUrl,
      actorName: actor.name,
      actorUsername: actor.username,
      actorJob: actor.job,
      action: action,
    ),
  );
  return visits;
}

PurchaseRequest _audiences(PurchaseRequest request) {
  final fromProcurement = request.stage != Stage.mr && request.stage != Stage.closed
      ? true
      : request.procurementVisible;
  final procurement = request.stage == Stage.closed
      ? request.procurementVisible
      : request.stage != Stage.mr;
  final reachedDelivery = request.stage == Stage.delivery ||
      request.stage == Stage.grn ||
      request.stage == Stage.tir ||
      request.stage == Stage.mrv ||
      (request.stage == Stage.closed && request.warehouseFifthOfficer);
  final fifthOfficer = request.scope == Scope.fifth &&
      (reachedDelivery || request.warehouseFifthOfficer);
  final fifthManager = request.scope == Scope.fifth &&
      (request.stage == Stage.grn ||
          request.stage == Stage.tir ||
          request.stage == Stage.mrv ||
          request.warehouseFifthManager);
  final kourba = request.scope == Scope.kourba &&
      (request.stage == Stage.delivery ||
          request.stage == Stage.grn ||
          request.stage == Stage.tir ||
          request.stage == Stage.mrv ||
          request.warehouseKourba);
  return request.copyWith(
    procurementVisible: procurement || fromProcurement,
    warehouseFifthOfficer: fifthOfficer,
    warehouseFifthManager: fifthManager,
    warehouseKourba: kourba,
    executiveVisible: request.executiveVisible,
  );
}
