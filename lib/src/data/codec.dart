import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/catalog.dart';
import '../domain/models.dart';

DateTime _time(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

String _name(Object? value) => value?.toString() ?? '';

T _enum<T>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString() ?? '';
  for (final value in values) {
    if (value.toString().split('.').last == name) return value;
  }
  return fallback;
}

Staff staffFromMap(String uid, Map<String, dynamic> data) {
  return Staff(
    uid: uid,
    username: _name(data['username']),
    name: _name(data['name']),
    scope: _enum(Scope.values, data['scope'], Scope.fifth),
    sector: _enum(Sector.values, data['sector'], Sector.maintenance),
    department: _enum(Department.values, data['department'], Department.mep),
    level: _enum(Level.values, data['level'], Level.engineer),
    discipline: data['discipline'] == null
        ? null
        : _enum(Discipline.values, data['discipline'], Discipline.mep),
    homeSiteId: data['homeSiteId']?.toString(),
    active: data['active'] != false,
    lang: data['lang']?.toString() ?? 'en',
    unread: (data['unread'] as num?)?.toInt() ?? 0,
    job: _name(data['job']),
    mustChangePassword: data['mustChangePassword'] == true,
  );
}

Map<String, dynamic> requestToMap(PurchaseRequest request) {
  return {
    'requestNo': request.requestNo,
    'externalPo': request.externalPo,
    'displayPo': request.displayPo,
    'creatorUid': request.creatorUid,
    'creatorName': request.creatorName,
    'creatorUsername': request.creatorUsername,
    'creatorJob': request.creatorJob,
    'department': request.department.name,
    'scope': request.scope.name,
    'siteId': request.siteId,
    'siteAr': request.siteAr,
    'siteEn': request.siteEn,
    'type': request.type.name,
    'discipline': request.discipline.name,
    'stage': stageCode(request.stage),
    'tab': request.tab.name,
    'createdAt': Timestamp.fromDate(request.createdAt),
    'updatedAt': Timestamp.fromDate(request.updatedAt),
    'stageStartedAt': Timestamp.fromDate(request.stageStartedAt),
    'poAnchorAt': request.poAnchorAt == null ? null : Timestamp.fromDate(request.poAnchorAt!),
    'details': request.details,
    'imageUrl': request.imageUrl,
    'mrRejected': request.mrRejected,
    'closure': request.closure.name,
    'deletion': request.deletion.name,
    'deletionReason': request.deletionReason,
    'deletionByName': request.deletionByName,
    'deletionByUsername': request.deletionByUsername,
    'deletionByJob': request.deletionByJob,
    'executiveVisible': request.executiveVisible,
    'procurementVisible': request.procurementVisible,
    'warehouseFifthOfficer': request.warehouseFifthOfficer,
    'warehouseFifthManager': request.warehouseFifthManager,
    'warehouseKourba': request.warehouseKourba,
    'cycle': request.cycle,
    'alternativeNote': request.alternativeNote,
    'visits': request.visits
        .map((visit) => {
              'stage': stageCode(visit.stage),
              'startedAt': Timestamp.fromDate(visit.startedAt),
              'endedAt': visit.endedAt == null ? null : Timestamp.fromDate(visit.endedAt!),
              'note': visit.note,
              'imageUrl': visit.imageUrl,
              'actorName': visit.actorName,
              'actorUsername': visit.actorUsername,
              'actorJob': visit.actorJob,
              'action': visit.action,
            })
        .toList(),
  };
}

PurchaseRequest requestFromMap(String id, Map<String, dynamic> data) {
  final visits = (data['visits'] as List?) ?? const [];
  return PurchaseRequest(
    id: id,
    requestNo: _name(data['requestNo']),
    externalPo: _name(data['externalPo']),
    creatorUid: _name(data['creatorUid']),
    creatorName: _name(data['creatorName']),
    creatorUsername: _name(data['creatorUsername']),
    creatorJob: _name(data['creatorJob']),
    department: _enum(Department.values, data['department'], Department.mep),
    scope: _enum(Scope.values, data['scope'], Scope.fifth),
    siteId: _name(data['siteId']),
    siteAr: _name(data['siteAr']),
    siteEn: _name(data['siteEn']),
    type: _enum(RequestType.values, data['type'], RequestType.maintenance),
    discipline: _enum(Discipline.values, data['discipline'], Discipline.mep),
    stage: stageFromCode(_name(data['stage'])),
    createdAt: _time(data['createdAt']),
    updatedAt: _time(data['updatedAt']),
    stageStartedAt: _time(data['stageStartedAt']),
    poAnchorAt: data['poAnchorAt'] == null ? null : _time(data['poAnchorAt']),
    details: _name(data['details']),
    imageUrl: data['imageUrl']?.toString(),
    mrRejected: data['mrRejected'] == true,
    closure: _enum(ClosureKind.values, data['closure'], ClosureKind.none),
    deletion: _enum(DeletionStatus.values, data['deletion'], DeletionStatus.none),
    deletionReason: _name(data['deletionReason']),
    deletionByName: _name(data['deletionByName']),
    deletionByUsername: _name(data['deletionByUsername']),
    deletionByJob: _name(data['deletionByJob']),
    executiveVisible: data['executiveVisible'] != false,
    procurementVisible: data['procurementVisible'] == true,
    warehouseFifthOfficer: data['warehouseFifthOfficer'] == true,
    warehouseFifthManager: data['warehouseFifthManager'] == true,
    warehouseKourba: data['warehouseKourba'] == true,
    cycle: (data['cycle'] as num?)?.toInt() ?? 1,
    alternativeNote: _name(data['alternativeNote']),
    visits: visits.whereType<Map>().map((raw) {
      final visit = Map<String, dynamic>.from(raw);
      return Visit(
        stage: stageFromCode(_name(visit['stage'])),
        startedAt: _time(visit['startedAt']),
        endedAt: visit['endedAt'] == null ? null : _time(visit['endedAt']),
        note: _name(visit['note']),
        imageUrl: visit['imageUrl']?.toString(),
        actorName: _name(visit['actorName']),
        actorUsername: _name(visit['actorUsername']),
        actorJob: _name(visit['actorJob']),
        action: _name(visit['action']),
      );
    }).toList(),
  );
}
