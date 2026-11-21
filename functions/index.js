const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const auth = getAuth();
const region = 'europe-west1';

const forward = { pr: 'rfq', rfq: 'po', po: 'do', do: 'grn', grn: 'tir' };

function tabFor(stage) {
  if (stage === 'mr' || stage === 'pr') return 'fresh';
  if (stage === 'closed') return 'closed';
  return 'progress';
}

function actor(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'auth');
  return {
    uid: request.auth.uid,
    level: request.auth.token.level,
    department: request.auth.token.department,
    scope: request.auth.token.scope,
    name: request.auth.token.name || '',
    username: request.auth.token.username || '',
  };
}

function assertStaff(user) {
  if (!user || user.active === false) throw new HttpsError('permission-denied', 'removed');
}

function can(user, request, action) {
  if (request.stage === 'closed') return false;
  if (request.deletion === 'pending') {
    return user.level === 'executive' && (action === 'approveDelete' || action === 'rejectDelete');
  }
  const manager = (user.level === 'deptManager' && user.department === request.department)
    || (request.department === 'landscape' && user.level === 'executive');
  const procurement = user.level === 'procurementOfficer';
  const fifthOfficer = request.scope === 'fifth' && user.level === 'warehouseOfficer' && user.department === 'warehouseFifth';
  const fifthManager = request.scope === 'fifth' && user.level === 'warehouseManager' && user.department === 'warehouseFifth';
  const kourbaStore = request.scope === 'kourba' && user.department === 'warehouseKourba' && (user.level === 'warehouseOfficer' || user.level === 'warehouseManager');
  if (manager && request.stage === 'mr' && action === 'deleteNow') return true;
  if (manager && request.stage === 'mr' && !request.mrRejected && (action === 'approveMr' || action === 'rejectMr')) return true;
  if (manager && request.stage !== 'mr' && request.department === 'landscape' && user.level === 'executive' && action === 'directDelete') return true;
  if (manager && request.stage !== 'mr' && !(request.department === 'landscape' && user.level === 'executive') && action === 'requestDelete') return true;
  if (procurement && ['pr', 'rfq', 'po', 'do', 'grn'].includes(request.stage) && action === 'advance') return true;
  if (procurement && ['rfq', 'po'].includes(request.stage) && action === 'alternative') return true;
  if (procurement && request.stage === 'mrv' && action === 'closePo') return true;
  if ((fifthOfficer || kourbaStore) && ['do', 'grn'].includes(request.stage) && action === 'advance') return true;
  if ((fifthManager || kourbaStore) && request.stage === 'mrv' && action === 'closePo') return true;
  if (user.uid === request.creatorUid && request.stage === 'tir' && (action === 'approveTir' || action === 'rejectTir')) return true;
  return false;
}

function closeVisits(visits, now, note) {
  return (visits || []).map((visit) => visit.endedAt ? visit : { ...visit, endedAt: now, note: note || visit.note || '' });
}

function actorVisit(user, now, note, imageUrl, stage, action) {
  return {
    stage,
    startedAt: now,
    endedAt: now,
    note: note || '',
    imageUrl: imageUrl || null,
    actorName: user.name || '',
    actorUsername: user.username || '',
    actorJob: user.job || '',
    action: action || '',
  };
}

function noteVisit(request, user, now, note, imageUrl, action) {
  return [...(request.visits || []), actorVisit(user, now, note, imageUrl, request.stage, action)];
}

function stampClose(request, user, now, note, imageUrl, action) {
  const visits = closeVisits(request.visits, now, '');
  visits.push(actorVisit(user, now, note, imageUrl, 'closed', action));
  return visits;
}

function enter(request, stage, user, now, note, imageUrl, anchor, action) {
  const visits = closeVisits(request.visits, now, '');
  visits.push({
    stage,
    startedAt: now,
    note: note || '',
    imageUrl: imageUrl || null,
    actorName: user.name,
    actorUsername: user.username,
    actorJob: user.job || '',
    action: action || '',
  });
  return {
    ...request,
    stage,
    tab: tabFor(stage),
    updatedAt: now,
    stageStartedAt: now,
    poAnchorAt: anchor ? (request.poAnchorAt || now) : request.poAnchorAt || null,
    mrRejected: false,
    visits,
    imageUrl: imageUrl || request.imageUrl || null,
  };
}

function audiences(request) {
  const procurement = request.stage === 'closed' ? !!request.procurementVisible : request.stage !== 'mr';
  const reachedStore = ['do', 'grn', 'tir', 'mrv'].includes(request.stage);
  return {
    ...request,
    procurementVisible: procurement,
    warehouseFifthOfficer: request.scope === 'fifth' && (reachedStore || !!request.warehouseFifthOfficer),
    warehouseFifthManager: request.scope === 'fifth' && (['grn', 'tir', 'mrv'].includes(request.stage) || !!request.warehouseFifthManager),
    warehouseKourba: request.scope === 'kourba' && (reachedStore || !!request.warehouseKourba),
    executiveVisible: request.executiveVisible !== false,
  };
}

function apply(request, action, user, now, note, imageUrl) {
  if (!can(user, request, action)) throw new HttpsError('permission-denied', 'forbidden');
  if (['deleteNow', 'requestDelete', 'rejectTir', 'alternative', 'directDelete'].includes(action) && !String(note || '').trim()) {
    throw new HttpsError('invalid-argument', 'note_required');
  }
  let next = request;
  if (action === 'approveMr') next = enter(request, 'pr', user, now, note, imageUrl, true, action);
  if (action === 'rejectMr') {
    next = { ...request, mrRejected: true, updatedAt: now, visits: noteVisit(request, user, now, note, imageUrl, action) };
  }
  if (action === 'deleteNow') {
    next = {
      ...request,
      stage: 'closed',
      tab: 'closed',
      closure: 'deletedBefore',
      executiveVisible: true,
      procurementVisible: false,
      deletionReason: note,
      updatedAt: now,
      visits: stampClose(request, user, now, note, imageUrl, action),
    };
  }
  if (action === 'requestDelete') {
    next = {
      ...request,
      deletion: 'pending',
      deletionReason: note,
      deletionByName: user.name || '',
      deletionByUsername: user.username || '',
      deletionByJob: user.job || '',
      updatedAt: now,
      visits: noteVisit(request, user, now, note, imageUrl, action),
    };
  }
  if (action === 'approveDelete') {
    next = {
      ...request,
      stage: 'closed',
      tab: 'closed',
      closure: 'deletedAfter',
      deletion: 'approved',
      updatedAt: now,
      visits: stampClose(request, user, now, note, imageUrl, action),
    };
  }
  if (action === 'directDelete') {
    next = {
      ...request,
      stage: 'closed',
      tab: 'closed',
      closure: 'deletedAfter',
      deletion: 'approved',
      deletionReason: note,
      updatedAt: now,
      visits: stampClose(request, user, now, note, imageUrl, action),
    };
  }
  if (action === 'rejectDelete') {
    next = {
      ...request,
      deletion: 'none',
      deletionReason: '',
      deletionByName: '',
      deletionByUsername: '',
      deletionByJob: '',
      updatedAt: now,
      visits: noteVisit(request, user, now, note, imageUrl, action),
    };
  }
  if (action === 'advance') next = enter(request, forward[request.stage], user, now, note, imageUrl, false, action);
  if (action === 'alternative') next = { ...enter(request, 'tir', user, now, note, imageUrl, false, action), alternativeNote: note };
  if (action === 'approveTir') next = enter(request, 'mrv', user, now, note, imageUrl, false, action);
  if (action === 'rejectTir') next = { ...enter(request, 'do', user, now, note, imageUrl, false, action), cycle: (request.cycle || 1) + 1 };
  if (action === 'closePo') next = { ...enter(request, 'closed', user, now, note, imageUrl, false, action), closure: 'completed' };
  next.tab = tabFor(next.stage);
  return audiences(next);
}

function emptyNode() {
  return { tabs: {}, stages: {}, types: {}, closures: {}, byType: {}, byDiscipline: {} };
}

function bump(node, request, sign) {
  const trade = request.discipline || 'operations';
  node.tabs[request.tab] = (node.tabs[request.tab] || 0) + sign;
  node.stages[request.stage] = (node.stages[request.stage] || 0) + sign;
  node.types[request.type] = (node.types[request.type] || 0) + sign;
  node.byType = node.byType || {};
  node.byType[request.type] = node.byType[request.type] || { tabs: {}, byDiscipline: {} };
  node.byType[request.type].tabs[request.tab] = (node.byType[request.type].tabs[request.tab] || 0) + sign;
  node.byType[request.type].byDiscipline = node.byType[request.type].byDiscipline || {};
  node.byType[request.type].byDiscipline[trade] = node.byType[request.type].byDiscipline[trade] || { tabs: {} };
  node.byType[request.type].byDiscipline[trade].tabs[request.tab] =
    (node.byType[request.type].byDiscipline[trade].tabs[request.tab] || 0) + sign;
  node.byDiscipline = node.byDiscipline || {};
  node.byDiscipline[trade] = node.byDiscipline[trade] || { tabs: {} };
  node.byDiscipline[trade].tabs[request.tab] = (node.byDiscipline[trade].tabs[request.tab] || 0) + sign;
  if (request.closure && request.closure !== 'none') {
    node.closures[request.closure] = (node.closures[request.closure] || 0) + sign;
  }
}

function counted(request) {
  return request && request.executiveVisible !== false;
}

function moveStats(stats, before, after) {
  stats.totals = stats.totals || emptyNode();
  stats.sites = stats.sites || {};
  const touch = (request, sign) => {
    if (!counted(request)) return;
    stats.sites[request.siteId] = stats.sites[request.siteId] || emptyNode();
    bump(stats.totals, request, sign);
    bump(stats.sites[request.siteId], request, sign);
  };
  touch(before, -1);
  touch(after, 1);
  stats.updatedAt = FieldValue.serverTimestamp();
  return stats;
}

function noticeCopy(request, kind, ar) {
  const po = request.displayPo || '';
  const who = request.deletionByUsername || request.deletionByName || '';
  if (kind === 'deleteAsk') {
    return {
      title: ar ? `طلب حذف ${po}` : `Deletion request ${po}`,
      body: ar ? `من ${who} — بانتظار المدير التنفيذي` : `From ${who} — waiting for the executive director`,
    };
  }
  if (kind === 'deleteBefore') {
    return {
      title: ar ? `رُفض وحُذف ${po}` : `${po} was rejected and deleted`,
      body: ar
        ? 'حُذف طلب المواد قبل المشتريات. أعد إنشاء الطلب من سيستم المشتريات'
        : 'The material request was deleted before procurement. Create it again from the procurement system',
    };
  }
  if (kind === 'closed') {
    return {
      title: ar ? `أُغلق ${po}` : `${po} was closed`,
      body: ar ? 'تم إغلاق طلب الشراء' : 'The purchase request was closed',
    };
  }
  if (kind === 'tir') {
    return {
      title: ar ? `فحص فني ${po}` : `Technical inspection ${po}`,
      body: ar ? 'بانتظار منشئ الطلب' : 'Waiting for the request creator',
    };
  }
  if (kind === 'deleteReject') {
    return {
      title: ar ? `رُفض حذف ${po}` : `Deletion of ${po} was rejected`,
      body: ar ? 'الطلب مستمر في مساره' : 'The request continues on its path',
    };
  }
  return {
    title: ar ? `تم تحديث ${po}` : `${po} was updated`,
    body: ar ? `المرحلة الحالية: ${request.stage}` : `Current stage: ${request.stage}`,
  };
}

async function notify(request, kind, actorUid) {
  const keys = [];
  const addKey = (key) => {
    if (key && !keys.includes(key)) keys.push(key);
  };
  const kourba = request.scope === 'kourba';
  const fifth = request.scope === 'fifth';
  const control = kind === 'procurement' || kind === 'grn' || kind === 'ncr' || kind === 'mrv' || kind === 'closed' || kind === 'tir';
  const deleteNotice = kind === 'deleteAsk' || kind === 'deleteReject';
  if (kind === 'mr') {
    addKey(`dept_${request.department}`);
    if (request.department === 'landscape') addKey('executive');
  }
  if (control) {
    addKey('procurement');
    addKey('executive');
    addKey(`dept_${request.department}`);
  }
  if (deleteNotice) {
    addKey('executive');
    addKey('procurement');
    addKey(`dept_${request.department}`);
  }
  if (kind === 'deleteBefore') addKey('executive');
  if (kind === 'grn' || kind === 'closed') {
    if (fifth) addKey('wh_fifth_officer');
    if (kourba) addKey('wh_kourba');
  }
  if (kind === 'mrv' || kind === 'closed') {
    if (fifth) addKey('wh_fifth_manager');
    if (kourba) addKey('wh_kourba');
  }
  if (kourba && (kind === 'mr' || control || deleteNotice || kind === 'deleteBefore')) {
    addKey('kourba_director');
  }
  const ids = new Set();
  if (control || deleteNotice || kind === 'deleteBefore') {
    if (request.creatorUid) ids.add(request.creatorUid);
  }
  if (keys.length) {
    const snaps = await db.getAll(...keys.map((key) => db.doc(`roleIndex/${key}`)));
    snaps.forEach((snap) => {
      const uids = snap.exists ? snap.data().uids || [] : [];
      uids.forEach((id) => ids.add(id));
    });
  }
  ids.delete(actorUid);
  if (!ids.size) return;
  const userSnaps = await db.getAll(...[...ids].map((uid) => db.doc(`users/${uid}`)));
  const active = userSnaps.filter((snap) => snap.exists && snap.data().active !== false);
  if (!active.length) return;
  const tokenSnaps = await Promise.all(active.map((snap) => db.collection(`users/${snap.id}/tokens`).get()));
  const batch = db.batch();
  const tokens = [];
  const stamp = Date.now();
  active.forEach((user, index) => {
    const ar = user.data().lang !== 'en';
    const copy = noticeCopy(request, kind, ar);
    const note = {
      title: copy.title,
      body: copy.body,
      requestId: request.id,
      displayPo: request.displayPo,
      stage: request.stage,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
      notificationId: `${request.id}_${request.stage}_${stamp}_${user.id}`,
    };
    batch.set(db.collection(`users/${user.id}/notifications`).doc(), note);
    batch.set(db.doc(`users/${user.id}`), { unread: FieldValue.increment(1) }, { merge: true });
    tokenSnaps[index].docs.forEach((doc) => tokens.push({
      token: doc.id,
      title: note.title,
      body: note.body,
      notificationId: note.notificationId,
    }));
  });
  await batch.commit();
  if (!tokens.length) return;
  await getMessaging().sendEach(tokens.map((item) => ({
    token: item.token,
    notification: { title: item.title, body: item.body },
    data: {
      type: 'request',
      requestId: request.id,
      displayPo: request.displayPo || '',
      stage: request.stage || '',
      notificationId: item.notificationId,
    },
    android: { collapseKey: request.id, priority: 'high' },
    apns: { headers: { 'apns-collapse-id': request.id } },
  })));
}

function kindFor(action, before, after) {
  if (action === 'deleteNow') return 'deleteBefore';
  if (action === 'requestDelete') return 'deleteAsk';
  if (action === 'approveDelete' || action === 'directDelete') return 'closed';
  if (action === 'rejectDelete') return 'deleteReject';
  if (action === 'alternative' || action === 'advance' && after.stage === 'tir') return 'tir';
  if (after.stage === 'grn') return 'grn';
  if (after.stage === 'tir') return 'tir';
  if (action === 'rejectTir') return 'ncr';
  if (after.stage === 'mrv') return 'mrv';
  if (after.stage === 'closed') return 'closed';
  if (['pr', 'rfq', 'po', 'do'].includes(after.stage)) return 'procurement';
  return 'mr';
}

async function loadUser(uid) {
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) throw new HttpsError('permission-denied', 'removed');
  return { uid, ...snap.data() };
}

function allowedSiteIds(user) {
  const malls = ['north_plus', 'ozone', 'cairo_capital_center', 'business_plus', 'elegantry'];
  const fifth = [...malls, 'gold_yard'];
  if (user.level === 'engineer' && ['lowCurrent', 'it', 'landscape'].includes(user.department)) {
    return [...fifth, 'kourba'];
  }
  if (user.scope === 'kourba' || user.department === 'civilKourba' || user.department === 'warehouseKourba') {
    return ['kourba'];
  }
  if (user.homeSiteId && malls.includes(user.homeSiteId)) {
    if (user.department === 'mallOps' || user.level === 'mallOpsManager') return [user.homeSiteId];
    return [user.homeSiteId, 'gold_yard'];
  }
  if (user.department === 'mallOps' || user.level === 'mallOpsManager') return malls;
  return fifth;
}

function allowedTypes(user) {
  if (user.department === 'civilFifth' || user.department === 'civilKourba') return ['execution', 'regular'];
  if (user.level === 'engineer' && ['lowCurrent', 'it', 'landscape'].includes(user.department)) return ['maintenance', 'execution'];
  if (user.sector === 'execution') return ['execution'];
  return ['maintenance'];
}

function requestDiscipline(user, requested) {
  if (user.department === 'civilFifth' || user.department === 'civilKourba') return 'civil';
  if (user.department === 'mallOps') return 'operations';
  if (user.discipline === 'mep' && ['electrical', 'mechanical'].includes(requested)) return requested;
  return user.discipline || 'operations';
}

const siteNames = {
  north_plus: 'NORTH PLUS',
  ozone: 'OZONE',
  cairo_capital_center: 'CAIRO CAPITAL CENTER',
  business_plus: 'BUSINESS PLUS',
  elegantry: 'ELEGANTRY',
  gold_yard: 'GOLD YARD',
  kourba: 'KOURBA HEIGHTS',
};

exports.createRequest = onCall({ region }, async (request) => {
  const claim = actor(request);
  const user = await loadUser(claim.uid);
  assertStaff(user);
  const direct = user.level === 'deptManager' && (user.department === 'civilFifth' || user.department === 'civilKourba');
  const allowed = user.level === 'engineer' || user.level === 'mallOpsManager' || direct;
  if (!allowed) throw new HttpsError('permission-denied', 'forbidden');
  const externalPo = String(request.data.externalPo || '').trim();
  if (!/^[A-Za-z0-9]+$/.test(externalPo)) throw new HttpsError('invalid-argument', 'po_format');
  const details = String(request.data.details || '').trim();
  if (!details) throw new HttpsError('invalid-argument', 'note_required');
  const siteId = String(request.data.siteId || '');
  if (!allowedSiteIds(user).includes(siteId)) throw new HttpsError('permission-denied', 'site');
  const type = String(request.data.type || '');
  if (!allowedTypes(user).includes(type)) throw new HttpsError('permission-denied', 'type');
  const requestedTrade = String(request.data.discipline || '');
  const discipline = requestDiscipline(user, requestedTrade);
  const now = new Date();
  const stage = direct ? 'pr' : 'mr';
  const ref = db.collection('requests').doc();
  const lock = db.doc(`poLocks/${externalPo}`);
  const counter = db.doc('counters/requests');
  const statsRef = db.doc('stats/executive');
  let saved;
  await db.runTransaction(async (tx) => {
    const [lockSnap, counterSnap, statsSnap] = await Promise.all([tx.get(lock), tx.get(counter), tx.get(statsRef)]);
    if (lockSnap.exists) throw new HttpsError('already-exists', 'po_exists');
    const next = (counterSnap.exists ? counterSnap.data().value : 0) + 1;
    const requestNo = `PR-${String(next).padStart(6, '0')}`;
    saved = audiences({
      id: ref.id,
      requestNo,
      externalPo,
      displayPo: `PO-${externalPo}`,
      creatorUid: user.uid,
      creatorName: user.name,
      creatorUsername: user.username,
      creatorJob: user.job || '',
      department: user.department,
      scope: siteId === 'kourba' ? 'kourba' : 'fifth',
      siteId: siteId,
      siteAr: siteNames[siteId] || siteId,
      siteEn: siteNames[siteId] || siteId,
      type: type,
      discipline,
      stage,
      tab: tabFor(stage),
      createdAt: now,
      updatedAt: now,
      stageStartedAt: now,
      poAnchorAt: stage === 'pr' ? now : null,
      details,
      imageUrl: request.data.imageUrl || null,
      mrRejected: false,
      closure: 'none',
      deletion: 'none',
      deletionReason: '',
      executiveVisible: true,
      procurementVisible: stage === 'pr',
      cycle: 1,
      alternativeNote: '',
      visits: [{
        stage,
        startedAt: now,
        note: details,
        imageUrl: request.data.imageUrl || null,
        actorName: user.name,
        actorUsername: user.username,
        actorJob: user.job || '',
        action: 'create',
      }],
    });
    const stats = statsSnap.exists ? statsSnap.data() : { totals: emptyNode(), sites: {} };
    tx.set(lock, { requestId: ref.id });
    tx.set(counter, { value: next });
    tx.set(ref, saved);
    tx.set(statsRef, moveStats(stats, null, saved));
  });
  await notify(saved, stage === 'pr' ? 'procurement' : 'mr', user.uid);
  return { id: ref.id, request: saved };
});

exports.applyAction = onCall({ region }, async (request) => {
  const claim = actor(request);
  const user = await loadUser(claim.uid);
  assertStaff(user);
  user.name = user.name || '';
  user.username = user.username || '';
  const ref = db.doc(`requests/${request.data.requestId}`);
  const eventRef = ref.collection('events').doc(String(request.data.clientActionId));
  const statsRef = db.doc('stats/executive');
  let saved;
  let before;
  await db.runTransaction(async (tx) => {
    const [currentSnap, eventSnap, statsSnap] = await Promise.all([tx.get(ref), tx.get(eventRef), tx.get(statsRef)]);
    if (!currentSnap.exists) throw new HttpsError('not-found', 'missing');
    if (eventSnap.exists) {
      saved = currentSnap.data();
      return;
    }
    before = currentSnap.data();
    const now = new Date();
    saved = apply(before, request.data.action, user, now, request.data.note || '', request.data.imageUrl || null);
    saved.id = ref.id;
    const stats = statsSnap.exists ? statsSnap.data() : { totals: emptyNode(), sites: {} };
    tx.set(ref, saved);
    tx.set(eventRef, {
      username: user.username,
      name: user.name,
      at: now,
      action: request.data.action,
      note: request.data.note || '',
    });
    tx.set(statsRef, moveStats(stats, before, saved));
  });
  if (before) await notify(saved, kindFor(request.data.action, before, saved), user.uid);
  return { request: saved };
});

exports.onRequestDeleted = onDocumentDeleted({ region, document: 'requests/{requestId}' }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};
  const before = {
    ...data,
    id: event.params.requestId,
    tab: data.tab || tabFor(data.stage),
  };
  await db.runTransaction(async (tx) => {
    const statsRef = db.doc('stats/executive');
    const statsSnap = await tx.get(statsRef);
    const stats = statsSnap.exists ? statsSnap.data() : { totals: emptyNode(), sites: {} };
    tx.set(statsRef, moveStats(stats, before, null));
  });
});

function indexKeys(user) {
  const keys = [];
  if (user.level === 'deptManager') keys.push(`dept_${user.department}`);
  if (user.level === 'procurementOfficer') keys.push('procurement');
  if (user.level === 'executive') keys.push('executive');
  if (user.level === 'kourbaDirector') keys.push('kourba_director');
  if (user.level === 'warehouseOfficer' && user.department === 'warehouseFifth') keys.push('wh_fifth_officer');
  if (user.level === 'warehouseManager' && user.department === 'warehouseFifth') keys.push('wh_fifth_manager');
  if (user.department === 'warehouseKourba') keys.push('wh_kourba');
  return keys;
}

function keysForUser(user) {
  if (Array.isArray(user.indexKeys) && user.indexKeys.length) {
    return user.indexKeys.filter(Boolean);
  }
  return indexKeys(user);
}

async function rebuildRoleIndex() {
  const wanted = Object.create(null);
  let last = null;
  for (;;) {
    let query = db.collection('users').orderBy(FieldPath.documentId()).limit(200);
    if (last) query = query.startAfter(last);
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      const user = doc.data() || {};
      if (user.active === false || user.removed === true) continue;
      for (const key of keysForUser(user)) {
        if (!wanted[key]) wanted[key] = new Set();
        wanted[key].add(doc.id);
      }
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < 200) break;
  }
  const names = Object.keys(wanted);
  if (!names.length) return { keys: [], counts: {}, skipped: true };
  const existing = await db.collection('roleIndex').get();
  const writes = db.batch();
  const kept = new Set();
  const counts = {};
  for (const key of names) {
    kept.add(key);
    const uids = [...wanted[key]];
    counts[key] = uids.length;
    writes.set(db.doc(`roleIndex/${key}`), { uids });
  }
  for (const doc of existing.docs) {
    if (!kept.has(doc.id)) writes.delete(doc.ref);
  }
  await writes.commit();
  return { keys: names.sort(), counts };
}

function textValue(value) {
  return value === undefined || value === null ? '' : String(value).trim();
}

function acceptableUsername(username) {
  if (!username || username.length > 64) return false;
  if (username === '.' || username === '..') return false;
  return !/[/\s]/.test(username);
}

// Auth still needs an email. Plain names stay name@prtrack.app so existing
// accounts keep working. Symbols such as @ are encoded into the local part.
function authEmail(username) {
  let local = '';
  for (let i = 0; i < username.length; i++) {
    const code = username.charCodeAt(i);
    const ch = username[i];
    if (code < 128 && /[a-z0-9._-]/.test(ch)) local += ch;
    else local += `_${code.toString(16)}_`;
  }
  return `${local}@prtrack.app`;
}

exports.upsertUser = onCall({ region }, async (request) => {
  const claim = actor(request);
  if (!['executive', 'kourbaDirector'].includes(claim.level)) throw new HttpsError('permission-denied', 'forbidden');
  const data = request.data || {};
  const username = textValue(data.username).toLowerCase();
  if (!acceptableUsername(username)) throw new HttpsError('invalid-argument', 'username_format');
  const email = authEmail(username);
  if (email.split('@')[0].length > 64) throw new HttpsError('invalid-argument', 'username_format');
  const name = textValue(data.name);
  const scope = textValue(data.scope);
  const sector = textValue(data.sector);
  const department = textValue(data.department);
  const level = textValue(data.level);
  if (!name || !scope || !sector || !department || !level) throw new HttpsError('invalid-argument', 'profile');
  if (claim.level === 'kourbaDirector' && scope !== 'kourba') throw new HttpsError('permission-denied', 'scope');
  if (claim.level === 'kourbaDirector' && ['lowCurrent', 'it', 'landscape'].includes(department)) {
    throw new HttpsError('permission-denied', 'shared_manager');
  }
  if (claim.level === 'kourbaDirector' && ['mep', 'lowCurrent', 'it'].includes(department) && level === 'deptManager') {
    throw new HttpsError('permission-denied', 'shared_manager');
  }
  let uid = textValue(data.uid);
  const password = textValue(data.password);
  const nameSnap = await db.doc(`usernames/${username}`).get();
  if (nameSnap.exists) {
    const owner = nameSnap.data() || {};
    if (owner.uid && owner.uid !== uid && owner.removed !== true) {
      const owned = await db.doc(`users/${owner.uid}`).get();
      if (owned.exists) throw new HttpsError('already-exists', 'username');
    }
    if (!uid && owner.uid) uid = owner.uid;
  }
  if (!uid) {
    if (password.length < 6) throw new HttpsError('invalid-argument', 'password');
    try {
      const created = await auth.createUser({ email, password, displayName: name });
      uid = created.uid;
    } catch (error) {
      const code = String(error.code || error.message || '');
      console.error('upsertUser createUser', code, error.message);
      if (code.includes('email-already-exists')) {
        const existing = await auth.getUserByEmail(email);
        const profileSnap = await db.doc(`users/${existing.uid}`).get();
        if (profileSnap.exists) throw new HttpsError('already-exists', 'username');
        uid = existing.uid;
        await auth.updateUser(uid, { displayName: name, password, disabled: false });
      } else if (code.includes('password')) {
        throw new HttpsError('invalid-argument', 'password');
      } else if (code.includes('invalid-email')) {
        throw new HttpsError('invalid-argument', 'username_format');
      } else {
        throw new HttpsError('internal', 'create_failed');
      }
    }
  } else {
    if (password && password.length < 6) throw new HttpsError('invalid-argument', 'password');
    const patch = { displayName: name, email, disabled: false };
    if (password) patch.password = password;
    await auth.updateUser(uid, patch);
  }
  const previous = (await db.doc(`users/${uid}`).get()).data() || {};
  const profile = {
    username,
    name,
    scope,
    sector,
    department,
    level,
    discipline: textValue(data.discipline) || null,
    homeSiteId: textValue(data.homeSiteId) || null,
    job: textValue(data.job) || null,
    indexKeys: indexKeys({ level, department }),
    active: previous.active !== false,
    lang: previous.lang || 'en',
    unread: typeof previous.unread === 'number' ? previous.unread : 0,
    mustChangePassword: password ? !!uid && !!previous.username : previous.mustChangePassword === true,
    removed: false,
  };
  if (!previous.username) {
    profile.active = true;
    profile.lang = 'en';
    profile.unread = 0;
  }
  for (const key of previous.indexKeys || []) {
    if (!profile.indexKeys.includes(key)) {
      await db.doc(`roleIndex/${key}`).set({ uids: FieldValue.arrayRemove(uid) }, { merge: true });
    }
  }
  if (previous.username && previous.username !== username) {
    await db.doc(`usernames/${previous.username}`).delete();
  }
  await auth.setCustomUserClaims(uid, {
    level: profile.level,
    department: profile.department,
    scope: profile.scope,
    username,
    display: profile.name,
    active: profile.active !== false,
  });
  await db.doc(`users/${uid}`).set(profile, { merge: true });
  await db.doc(`usernames/${username}`).set({ uid, active: profile.active !== false, disabled: false, removed: false });
  for (const key of profile.indexKeys) {
    await db.doc(`roleIndex/${key}`).set({ uids: FieldValue.arrayUnion(uid) }, { merge: true });
  }
  return { uid };
});

exports.deleteUser = onCall({ region }, async (request) => {
  const claim = actor(request);
  if (!['executive', 'kourbaDirector'].includes(claim.level)) throw new HttpsError('permission-denied', 'forbidden');
  const uid = request.data.uid;
  if (uid === claim.uid) throw new HttpsError('failed-precondition', 'self');
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) return { ok: true };
  const user = snap.data();
  if (claim.level === 'kourbaDirector' && user.scope !== 'kourba') throw new HttpsError('permission-denied', 'scope');
  await auth.updateUser(uid, { disabled: true });
  const record = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, Object.assign({}, record.customClaims, { active: false }));
  await db.doc(`users/${uid}`).set({ active: false, removed: true }, { merge: true });
  await db.doc(`usernames/${user.username}`).set({ uid, active: false, removed: true, disabled: false }, { merge: true });
  for (const key of user.indexKeys || []) {
    await db.doc(`roleIndex/${key}`).set({ uids: FieldValue.arrayRemove(uid) }, { merge: true });
  }
  const tokens = await db.collection(`users/${uid}/tokens`).get();
  if (!tokens.empty) {
    await getMessaging().sendEach(tokens.docs.map((doc) => ({
      token: doc.id,
      data: { type: 'account_deleted', notificationId: `deleted_${uid}` },
      notification: { title: 'PR TRACK', body: 'تم حذف الحساب' },
    })));
  }
  return { ok: true };
});

exports.setUserActive = onCall({ region }, async (request) => {
  const claim = actor(request);
  if (!['executive', 'kourbaDirector'].includes(claim.level)) throw new HttpsError('permission-denied', 'forbidden');
  const uid = request.data.uid;
  if (uid === claim.uid) throw new HttpsError('failed-precondition', 'self');
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists || snap.data().removed === true) throw new HttpsError('not-found', 'missing');
  const user = snap.data();
  if (claim.level === 'kourbaDirector' && user.scope !== 'kourba') throw new HttpsError('permission-denied', 'scope');
  const active = request.data.active === true;
  const record = await auth.getUser(uid);
  await auth.updateUser(uid, { disabled: !active });
  await auth.setCustomUserClaims(uid, Object.assign({}, record.customClaims, { active }));
  await db.doc(`users/${uid}`).set({ active, removed: false }, { merge: true });
  await db.doc(`usernames/${user.username}`).set({ uid, active, disabled: !active, removed: false }, { merge: true });
  for (const key of user.indexKeys || []) {
    await db.doc(`roleIndex/${key}`).set(
      { uids: active ? FieldValue.arrayUnion(uid) : FieldValue.arrayRemove(uid) },
      { merge: true },
    );
  }
  return { ok: true };
});

exports.resetUserPassword = onCall({ region }, async (request) => {
  const claim = actor(request);
  if (!['executive', 'kourbaDirector'].includes(claim.level)) throw new HttpsError('permission-denied', 'forbidden');
  const uid = String(request.data.uid || '');
  const password = textValue(request.data.password);
  if (!uid || uid === claim.uid) throw new HttpsError('failed-precondition', 'self');
  if (password.length < 6) throw new HttpsError('invalid-argument', 'password');
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists || snap.data().removed === true) throw new HttpsError('not-found', 'missing');
  if (claim.level === 'kourbaDirector' && snap.data().scope !== 'kourba') {
    throw new HttpsError('permission-denied', 'scope');
  }
  await auth.updateUser(uid, { password, disabled: false });
  await db.doc(`users/${uid}`).set({ mustChangePassword: true }, { merge: true });
  return { ok: true };
});

exports.bootstrapExecutive = onCall({ region }, async (request) => {
  if (request.data.setupKey !== process.env.SETUP_KEY) throw new HttpsError('permission-denied', 'key');
  const existing = await db.collection('users').where('level', '==', 'executive').limit(1).get();
  if (!existing.empty) throw new HttpsError('already-exists', 'executive');
  const username = String(request.data.username || '').trim().toLowerCase();
  const created = await auth.createUser({
    email: authEmail(username),
    password: request.data.password,
    displayName: request.data.name,
  });
  const profile = {
    username,
    name: request.data.name,
    scope: 'company',
    sector: 'leadership',
    department: 'executiveOffice',
    level: 'executive',
    active: true,
    lang: 'en',
    unread: 0,
    indexKeys: ['executive'],
  };
  await auth.setCustomUserClaims(created.uid, {
    level: 'executive',
    department: 'executiveOffice',
    scope: 'company',
    username,
    name: profile.name,
    active: true,
  });
  await db.doc(`users/${created.uid}`).set(profile);
  await db.doc(`usernames/${username}`).set({ uid: created.uid, active: true });
  await db.doc('roleIndex/executive').set({ uids: FieldValue.arrayUnion(created.uid) }, { merge: true });
  return { uid: created.uid };
});

exports.restoreExecutive = onCall({ region }, async (request) => {
  if (request.data.setupKey !== process.env.SETUP_KEY) throw new HttpsError('permission-denied', 'key');
  const existing = await db.collection('users').where('level', '==', 'executive').limit(1).get();
  if (existing.empty) throw new HttpsError('not-found', 'executive');
  const doc = existing.docs[0];
  const data = doc.data();
  const password = String(request.data.password || '').trim();
  if (password && password.length < 6) throw new HttpsError('invalid-argument', 'password');
  const authPatch = { disabled: false };
  if (password) authPatch.password = password;
  await auth.updateUser(doc.id, authPatch);
  const record = await auth.getUser(doc.id);
  await auth.setCustomUserClaims(doc.id, {
    ...(record.customClaims || {}),
    level: 'executive',
    department: 'executiveOffice',
    scope: 'company',
    username: data.username,
    name: data.name || '',
    active: true,
  });
  await db.doc(`users/${doc.id}`).set({ active: true, lang: 'en' }, { merge: true });
  await db.doc(`usernames/${data.username}`).set({ uid: doc.id, active: true }, { merge: true });
  await rebuildRoleIndex();
  return { uid: doc.id, username: data.username };
});

exports.rebuildRoleIndex = onCall({ region }, async (request) => {
  const claim = actor(request);
  if (claim.level !== 'executive') throw new HttpsError('permission-denied', 'forbidden');
  return rebuildRoleIndex();
});
