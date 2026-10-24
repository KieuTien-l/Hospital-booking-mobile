import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const endpoint = process.env.SPRINT6_ADMIN_TEST_URL;
if (!endpoint || !/^http:\/\/127\.0\.0\.1:\d+\/demo-healway-admin\/asia-southeast1\/adminCommand$/.test(endpoint) ||
    !/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '') ||
    !/^127\.0\.0\.1:\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST || '')) {
  throw new Error('Local Functions/Auth/Firestore emulators required; production is never allowed.');
}
const projectId = 'demo-healway-admin';
const app = initializeApp({ projectId }, `http-${randomUUID()}`);
const db = getFirestore(app), auth = getAuth(app), tokens = {};
const invoke = async (data, token) => {
  const response = await fetch(endpoint, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }), signal: AbortSignal.timeout(30000),
  });
  return { status: response.status, body: await response.json() };
};
const input = () => ({ operation: 'create', collection: 'CHUYEN_KHOA',
  requestId: randomUUID(), reason: 'QA HTTP emulator', values: { name: 'Chuyên khoa HTTP thử nghiệm', description: 'Synthetic QA only' } });

before(async () => {
  for (const [label, role, active] of [['admin', 'admin', true], ['patient', 'patient', true], ['doctor', 'doctor', true], ['locked', 'admin', false]]) {
    const uid = `http-qa-${label}`, email = `${uid}@example.com`, password = randomBytes(24).toString('hex');
    try { await auth.deleteUser(uid); } catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
    await auth.createUser({ uid, email, password });
    await db.collection('TAI_KHOAN').doc(uid).set({ role, isActive: active, status: 'ACTIVE', fullName: label, email, phone: '' });
    const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }),
    });
    const result = await response.json();
    assert.equal(response.status, 200, 'Synthetic emulator login must succeed');
    assert.ok(result.idToken);
    tokens[label] = result.idToken;
  }
});
after(async () => { await deleteApp(app); });

test('HTTP callable rejects absent and malformed authentication', async () => {
  for (const token of [undefined, 'invalid']) {
    const result = await invoke(input(), token);
    assert.equal(result.status, 401);
    assert.equal(result.body.error.status, 'UNAUTHENTICATED');
  }
});

test('HTTP callable denies patient, doctor and inactive admin tokens', async () => {
  for (const label of ['patient', 'doctor', 'locked']) {
    const result = await invoke(input(), tokens[label]);
    assert.equal(result.status, 403, label);
    assert.equal(result.body.error.status, 'PERMISSION_DENIED');
  }
});

test('HTTP admin mutation and retry share one receipt and audit; changed input is rejected', async () => {
  const command = input();
  const first = await invoke(command, tokens.admin);
  assert.equal(first.status, 200);
  assert.equal(first.body.result.id, command.requestId);
  const retry = await invoke(command, tokens.admin);
  assert.deepEqual(retry, first);
  const audit = (await db.collection('NHAT_KY_ADMIN').doc(command.requestId).get()).data();
  assert.equal(audit.actorId, 'http-qa-admin');
  assert.equal(audit.targetId, command.requestId);
  assert.ok((await db.collection('ADMIN_COMMANDS').doc(`http-qa-admin_${command.requestId}`).get()).exists);
  const changed = await invoke({ ...command, values: { ...command.values, name: 'Changed payload' } }, tokens.admin);
  assert.equal(changed.status, 409);
  assert.equal(changed.body.error.status, 'ALREADY_EXISTS');
  assert.equal((await db.collection('CHUYEN_KHOA').doc(command.requestId).get()).data().name, command.values.name);
});
