enum Scope { fifth, kourba, company }

enum Department {
  mep,
  lowCurrent,
  civilFifth,
  civilKourba,
  mallOps,
  procurement,
  warehouseFifth,
  warehouseKourba,
  executiveOffice,
  kourbaOffice,
  it,
  landscape,
}

enum Level {
  engineer,
  mallOpsManager,
  deptManager,
  procurementOfficer,
  warehouseOfficer,
  warehouseManager,
  executive,
  kourbaDirector,
}

enum Sector { maintenance, execution, warehouse, procurement, leadership }

enum Discipline { civil, electrical, mechanical, lowCurrent, mep, operations, it, landscape }

const List<Discipline> kFilterTrades = [
  Discipline.electrical,
  Discipline.mechanical,
  Discipline.lowCurrent,
  Discipline.civil,
  Discipline.landscape,
  Discipline.it,
  Discipline.operations,
];

enum RequestType { execution, maintenance, regular }

enum Stage { mr, pr, rfq, po, delivery, grn, tir, mrv, closed }

/// The eight workflow stages shown on the request map.
const List<Stage> kMapStages = [
  Stage.mr,
  Stage.pr,
  Stage.rfq,
  Stage.po,
  Stage.delivery,
  Stage.grn,
  Stage.tir,
  Stage.mrv,
];

/// Stage keys for executive filtering. Keep values in this enum only.
const List<Stage> kFilterStages = [
  Stage.mr,
  Stage.pr,
  Stage.rfq,
  Stage.po,
  Stage.delivery,
  Stage.grn,
  Stage.tir,
  Stage.mrv,
  Stage.closed,
];

enum TabKind { fresh, progress, closed }

enum ClosureKind { none, completed, deletedBefore, deletedAfter }

enum DeletionStatus { none, pending, approved, rejected }

enum PrAction {
  approveMr,
  rejectMr,
  deleteNow,
  requestDelete,
  approveDelete,
  rejectDelete,
  advance,
  alternative,
  approveTir,
  rejectTir,
  closePo,
  directDelete,
}

enum JobTitle {
  mallMaintenanceEngineer,
  mallOpsLead,
  mallsOpsManager,
  mepExecutionEngineer,
  mepManager,
  lowCurrentEngineer,
  lowCurrentManager,
  civilEngineer,
  civilManager,
  procurement,
  fifthStorekeeper,
  fifthStoreManager,
  kourbaStorekeeper,
  kourbaStoreManager,
  itEngineer,
  itManager,
  landscape,
  kourbaDirector,
}

class JobSpec {
  const JobSpec({
    required this.level,
    required this.department,
    required this.sector,
    required this.scope,
    this.discipline,
    this.needsMall = false,
    this.needsArea = false,
    this.needsTrade = false,
  });

  final Level level;
  final Department department;
  final Sector sector;
  final Scope scope;
  final Discipline? discipline;
  final bool needsMall;
  final bool needsArea;
  final bool needsTrade;
}

JobSpec specFor(JobTitle job) {
  switch (job) {
    case JobTitle.mallMaintenanceEngineer:
      return const JobSpec(level: Level.engineer, department: Department.mep, sector: Sector.maintenance, scope: Scope.fifth, discipline: Discipline.mep, needsMall: true);
    case JobTitle.mallOpsLead:
      return const JobSpec(level: Level.mallOpsManager, department: Department.mallOps, sector: Sector.maintenance, scope: Scope.fifth, discipline: Discipline.operations, needsMall: true);
    case JobTitle.mallsOpsManager:
      return const JobSpec(level: Level.deptManager, department: Department.mallOps, sector: Sector.maintenance, scope: Scope.fifth, discipline: Discipline.operations);
    case JobTitle.mepExecutionEngineer:
      return const JobSpec(level: Level.engineer, department: Department.mep, sector: Sector.execution, scope: Scope.fifth, needsArea: true, needsTrade: true);
    case JobTitle.mepManager:
      return const JobSpec(level: Level.deptManager, department: Department.mep, sector: Sector.maintenance, scope: Scope.company, discipline: Discipline.mep);
    case JobTitle.lowCurrentEngineer:
      return const JobSpec(level: Level.engineer, department: Department.lowCurrent, sector: Sector.maintenance, scope: Scope.company, discipline: Discipline.lowCurrent);
    case JobTitle.lowCurrentManager:
      return const JobSpec(level: Level.deptManager, department: Department.lowCurrent, sector: Sector.maintenance, scope: Scope.company, discipline: Discipline.lowCurrent);
    case JobTitle.civilEngineer:
      return const JobSpec(level: Level.engineer, department: Department.civilFifth, sector: Sector.execution, scope: Scope.fifth, discipline: Discipline.civil, needsArea: true);
    case JobTitle.civilManager:
      return const JobSpec(level: Level.deptManager, department: Department.civilFifth, sector: Sector.execution, scope: Scope.fifth, discipline: Discipline.civil, needsArea: true);
    case JobTitle.procurement:
      return const JobSpec(level: Level.procurementOfficer, department: Department.procurement, sector: Sector.procurement, scope: Scope.company);
    case JobTitle.fifthStorekeeper:
      return const JobSpec(level: Level.warehouseOfficer, department: Department.warehouseFifth, sector: Sector.warehouse, scope: Scope.fifth);
    case JobTitle.fifthStoreManager:
      return const JobSpec(level: Level.warehouseManager, department: Department.warehouseFifth, sector: Sector.warehouse, scope: Scope.fifth);
    case JobTitle.kourbaStorekeeper:
      return const JobSpec(level: Level.warehouseOfficer, department: Department.warehouseKourba, sector: Sector.warehouse, scope: Scope.kourba);
    case JobTitle.kourbaStoreManager:
      return const JobSpec(level: Level.warehouseManager, department: Department.warehouseKourba, sector: Sector.warehouse, scope: Scope.kourba);
    case JobTitle.itEngineer:
      return const JobSpec(level: Level.engineer, department: Department.it, sector: Sector.maintenance, scope: Scope.company, discipline: Discipline.it);
    case JobTitle.itManager:
      return const JobSpec(level: Level.deptManager, department: Department.it, sector: Sector.maintenance, scope: Scope.company, discipline: Discipline.it);
    case JobTitle.landscape:
      return const JobSpec(level: Level.engineer, department: Department.landscape, sector: Sector.maintenance, scope: Scope.company, discipline: Discipline.landscape);
    case JobTitle.kourbaDirector:
      return const JobSpec(level: Level.kourbaDirector, department: Department.kourbaOffice, sector: Sector.leadership, scope: Scope.kourba);
  }
}

List<JobTitle> jobsFor(Level admin) {
  if (admin == Level.kourbaDirector) {
    return const [
      JobTitle.mepExecutionEngineer,
      JobTitle.civilEngineer,
      JobTitle.civilManager,
      JobTitle.kourbaStorekeeper,
      JobTitle.kourbaStoreManager,
    ];
  }
  return JobTitle.values;
}

class SiteInfo {
  const SiteInfo(this.id, this.nameAr, this.nameEn, this.scope);

  final String id;
  final String nameAr;
  final String nameEn;
  final Scope scope;

  String name(bool ar) => nameEn;
}

/// Site names stay English in both languages so search uses one reference.
const List<SiteInfo> kSites = [
  SiteInfo('north_plus', 'NORTH PLUS', 'NORTH PLUS', Scope.fifth),
  SiteInfo('ozone', 'OZONE', 'OZONE', Scope.fifth),
  SiteInfo('cairo_capital_center', 'CAIRO CAPITAL CENTER', 'CAIRO CAPITAL CENTER', Scope.fifth),
  SiteInfo('business_plus', 'BUSINESS PLUS', 'BUSINESS PLUS', Scope.fifth),
  SiteInfo('elegantry', 'ELEGANTRY', 'ELEGANTRY', Scope.fifth),
  SiteInfo('gold_yard', 'GOLD YARD', 'GOLD YARD', Scope.fifth),
  SiteInfo('kourba', 'KOURBA HEIGHTS', 'KOURBA HEIGHTS', Scope.kourba),
];

SiteInfo siteById(String id) =>
    kSites.firstWhere((site) => site.id == id, orElse: () => kSites.first);

List<SiteInfo> get fifthMalls =>
    kSites.where((site) => site.scope == Scope.fifth && site.id != 'gold_yard').toList();

TabKind tabFor(Stage stage) {
  switch (stage) {
    case Stage.mr:
    case Stage.pr:
      return TabKind.fresh;
    case Stage.closed:
      return TabKind.closed;
    default:
      return TabKind.progress;
  }
}

Stage? forwardStage(Stage stage) {
  switch (stage) {
    case Stage.pr:
      return Stage.rfq;
    case Stage.rfq:
      return Stage.po;
    case Stage.po:
      return Stage.delivery;
    case Stage.delivery:
      return Stage.grn;
    case Stage.grn:
      return Stage.tir;
    default:
      return null;
  }
}

String stageCode(Stage stage) {
  switch (stage) {
    case Stage.mr:
      return 'mr';
    case Stage.pr:
      return 'pr';
    case Stage.rfq:
      return 'rfq';
    case Stage.po:
      return 'po';
    case Stage.delivery:
      return 'do';
    case Stage.grn:
      return 'grn';
    case Stage.tir:
      return 'tir';
    case Stage.mrv:
      return 'mrv';
    case Stage.closed:
      return 'closed';
  }
}

Stage stageFromCode(String code) {
  switch (code) {
    case 'mr':
      return Stage.mr;
    case 'pr':
      return Stage.pr;
    case 'rfq':
      return Stage.rfq;
    case 'po':
      return Stage.po;
    case 'do':
      return Stage.delivery;
    case 'grn':
      return Stage.grn;
    case 'tir':
      return Stage.tir;
    case 'mrv':
      return Stage.mrv;
    default:
      return Stage.closed;
  }
}
