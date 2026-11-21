import 'package:flutter_test/flutter_test.dart';
import 'package:prtrack/src/domain/catalog.dart';
import 'package:prtrack/src/domain/models.dart';
import 'package:prtrack/src/domain/rules.dart';

Staff _engineer() {
  return const Staff(
    uid: 'e1',
    username: 'eng',
    name: 'Engineer',
    scope: Scope.fifth,
    sector: Sector.maintenance,
    department: Department.mep,
    level: Level.engineer,
    discipline: Discipline.mep,
    homeSiteId: 'north_plus',
    active: true,
  );
}

Staff _manager() {
  return const Staff(
    uid: 'm1',
    username: 'mgr',
    name: 'Manager',
    scope: Scope.fifth,
    sector: Sector.maintenance,
    department: Department.mep,
    level: Level.deptManager,
    active: true,
  );
}

void main() {
  test('approval moves MR to PR and keeps the new tab', () {
    final creator = _engineer();
    final now = DateTime(2026, 11, 14, 9);
    final draft = draftRequest(
      creator: creator,
      site: siteById('north_plus'),
      type: RequestType.maintenance,
      externalPo: 'A12',
      details: 'paint',
      now: now,
    );
    expect(draft.stage, Stage.mr);
    expect(draft.tab, TabKind.fresh);
    final approved = applyAction(
      request: draft,
      action: PrAction.approveMr,
      actor: _manager(),
      now: now.add(const Duration(minutes: 5)),
    );
    expect(approved.stage, Stage.pr);
    expect(approved.tab, TabKind.fresh);
    expect(approved.poAnchorAt, isNotNull);
    expect(approved.procurementVisible, isTrue);
  });

  test('RFQ leaves the new tab', () {
    final creator = _engineer();
    final manager = _manager();
    final now = DateTime(2026, 11, 14, 9);
    final draft = draftRequest(
      creator: creator,
      site: siteById('north_plus'),
      type: RequestType.maintenance,
      externalPo: 'B12',
      details: 'cable',
      now: now,
    );
    final pr = applyAction(request: draft, action: PrAction.approveMr, actor: manager, now: now);
    final buyer = const Staff(
      uid: 'p1',
      username: 'buy',
      name: 'Buyer',
      scope: Scope.company,
      sector: Sector.procurement,
      department: Department.procurement,
      level: Level.procurementOfficer,
      active: true,
    );
    final rfq = applyAction(request: pr, action: PrAction.advance, actor: buyer, now: now);
    expect(rfq.stage, Stage.rfq);
    expect(rfq.tab, TabKind.progress);
  });

  test('delete before procurement closes on the executive board', () {
    final creator = _engineer();
    final now = DateTime(2026, 11, 14, 9);
    final draft = draftRequest(
      creator: creator,
      site: siteById('north_plus'),
      type: RequestType.maintenance,
      externalPo: 'C12',
      details: 'lamp',
      now: now,
    );
    final deleted = applyAction(
      request: draft,
      action: PrAction.deleteNow,
      actor: _manager(),
      now: now,
      note: 'wrong item',
    );
    expect(deleted.stage, Stage.closed);
    expect(deleted.tab, TabKind.closed);
    expect(deleted.closure, ClosureKind.deletedBefore);
    expect(deleted.executiveVisible, isTrue);
    expect(deleted.visits.last.action, 'deleteNow');
    expect(actionsFor(_manager(), draft), containsAll([PrAction.approveMr, PrAction.deleteNow]));
    expect(actionsFor(_manager(), draft), isNot(contains(PrAction.rejectMr)));
  });

  test('site names stay English and wide roles choose type and place', () {
    expect(siteById('gold_yard').name(true), 'GOLD YARD');
    expect(siteById('kourba').name(false), 'KOURBA HEIGHTS');
    final wide = const Staff(
      uid: 'it1',
      username: 'it',
      name: 'IT',
      scope: Scope.company,
      sector: Sector.maintenance,
      department: Department.it,
      level: Level.engineer,
      active: true,
    );
    expect(typesFor(wide).map((type) => type.name), ['maintenance', 'execution']);
    expect(sitesFor(wide).map((site) => site.id), containsAll(['north_plus', 'gold_yard', 'kourba']));
  });

  test('filter trades stay fixed and do not change approval', () {
    expect(kFilterTrades.map((trade) => trade.name), [
      'electrical',
      'mechanical',
      'lowCurrent',
      'civil',
      'landscape',
      'it',
      'operations',
    ]);
    expect(disciplineFor(_engineer(), chosen: Discipline.electrical), Discipline.electrical);
    expect(tradesFor(_engineer()), [Discipline.electrical, Discipline.mechanical]);
    final draft = draftRequest(
      creator: _engineer(),
      site: siteById('north_plus'),
      type: RequestType.maintenance,
      externalPo: 'D12',
      details: 'motor',
      now: DateTime(2026, 11, 15, 9),
      discipline: Discipline.mechanical,
    );
    expect(draft.discipline, Discipline.mechanical);
    expect(draft.stage, Stage.mr);
  });

  test('need-action follows the waiting role and skips delete-only actions', () {
    final creator = _engineer();
    final now = DateTime(2026, 11, 18, 9);
    final draft = draftRequest(
      creator: creator,
      site: siteById('north_plus'),
      type: RequestType.maintenance,
      externalPo: 'E12',
      details: 'valve',
      now: now,
    );
    expect(needsAction(_manager(), draft), isTrue);
    expect(needsAction(creator, draft), isFalse);
    expect(draft.creatorJob, creator.job);
    expect(draft.visits.first.actorJob, creator.job);
    final tir = draft.copyWith(stage: Stage.tir);
    expect(needsAction(creator, tir), isTrue);
    expect(needsAction(_manager(), tir), isFalse);
  });

  test('request delete logs who asked and waits for the executive', () {
    final creator = _engineer();
    final manager = _manager();
    final now = DateTime(2026, 11, 18, 9);
    final draft = draftRequest(
      creator: creator,
      site: siteById('north_plus'),
      type: RequestType.maintenance,
      externalPo: 'F12',
      details: 'pump',
      now: now,
    );
    final pr = applyAction(request: draft, action: PrAction.approveMr, actor: manager, now: now);
    final pending = applyAction(
      request: pr,
      action: PrAction.requestDelete,
      actor: manager,
      now: now.add(const Duration(minutes: 1)),
      note: 'duplicate',
    );
    expect(pending.deletion, DeletionStatus.pending);
    expect(pending.deletionByUsername, manager.username);
    expect(pending.visits.last.action, 'requestDelete');
    final exec = const Staff(
      uid: 'x1',
      username: 'exec',
      name: 'Executive',
      scope: Scope.company,
      sector: Sector.leadership,
      department: Department.executiveOffice,
      level: Level.executive,
      active: true,
    );
    expect(needsAction(exec, pending), isTrue);
    expect(needsAction(manager, pending), isFalse);
    expect(needsAction(creator, pending), isFalse);
  });

  test('executive can appoint the kourba director and that role cannot appoint another', () {
    expect(jobsFor(Level.executive), contains(JobTitle.kourbaDirector));
    expect(jobsFor(Level.kourbaDirector), isNot(contains(JobTitle.kourbaDirector)));
  });
}
