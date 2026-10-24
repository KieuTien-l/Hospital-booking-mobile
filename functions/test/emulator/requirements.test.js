import test, { before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, query, where, serverTimestamp } from 'firebase/firestore';
import { executeAdminCommand } from '../../src/commands.js';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Local emulators required.');
const projectId = 'demo-healway-requirements';
const app = initializeApp({ projectId }, `requirements-${randomUUID()}`);
const db = getFirestore(app), auth = getAuth(app);
let env;
const client = (uid) => env.authenticatedContext(uid).firestore();
const day = new Date('2026-11-02T00:00:00Z');
const report = (extra = {}) => ({ senderId: 'doctor', doctorId: 'doctor', scheduleId: 'schedule',
  type: 'Bận đột xuất', date: day, reason: 'Xin đổi lịch', description: 'Có công việc đột xuất',
  status: 'PENDING', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra });
const command = (uid, values, extra = {}) => executeAdminCommand(db, auth, uid, {
  requestId: randomUUID(), reason: 'Kiểm thử yêu cầu bác sĩ', operation: 'reviewDoctorRequest',
  collection: 'YEU_CAU_BAC_SI', id: 'request', values, ...extra,
});

before(async () => { env = await initializeTestEnvironment({ projectId,
  firestore: { rules: await readFile(new URL('../../../firestore.rules', import.meta.url), 'utf8') } }); });
beforeEach(async () => {
  await env.clearFirestore();
  for (const [key, role, isActive] of [['admin', 'admin', true], ['admin2', 'admin', true], ['doctor', 'doctor', true],
    ['other-doctor', 'doctor', true], ['patient', 'patient', true], ['locked', 'admin', false]]) {
    await db.collection('TAI_KHOAN').doc(key).set({ role, isActive, fullName: key, email: `${key}@example.com`, phone: '', status: 'ACTIVE' });
  }
  await db.collection('CHUYEN_KHOA').doc('specialty').set({ name: 'Nội', status: 'ACTIVE', isActive: true });
  await db.collection('BAC_SI').doc('doctor').set({ userId: 'doctor', fullName: 'Bác sĩ A', specialtyId: 'specialty',
    status: 'ACTIVE', isActive: true, yearsOfExperience: 4, consultationFee: 100000 });
  await db.collection('BAC_SI').doc('other-doctor').set({ userId: 'other-doctor', status: 'ACTIVE' });
  await db.collection('BENH_NHAN').doc('patient').set({ authUserId: 'patient', fullName: 'Bệnh nhân' });
  await db.collection('LICH_LAM_VIEC').doc('schedule').set({ doctorId: 'doctor', workDate: day, startTime: '08:00', endTime: '12:00', status: 'ACTIVE' });
  await db.collection('CA_KHAM').doc('slot').set({ doctorId: 'doctor', workScheduleId: 'schedule', startTime: '08:00', endTime: '09:00', capacity: 5, bookedCount: 1, reservationCounts: { appointment: 1 }, status: 'AVAILABLE' });
  await db.collection('LICH_HEN').doc('appointment').set({ doctorId: 'doctor', patientId: 'patient', workScheduleId: 'schedule', timeSlotId: 'slot', specialtyId: 'specialty', peopleCount: 1, status: 'PENDING', appointmentDate: day, startTime: '08:00', endTime: '09:00' });
});
after(async () => { await env?.cleanup(); await deleteApp(app); });

test('AI-06/12: transcript ownership, schema, timestamps and immutable records', async () => {
  const transcript = { authUserId: 'patient', userId: 'patient', sessionId: 'session',
    userMessage: 'Cách đặt khám?', aiReply: 'Vào Đặt khám.', source: 'OPENAI_CLOUDFLARE', timestamp: serverTimestamp() };
  await assertSucceeds(setDoc(doc(client('patient'), 'LS_CHAT_AI', 'mine'), transcript));
  await assertSucceeds(getDoc(doc(client('patient'), 'LS_CHAT_AI', 'mine')));
  await assertSucceeds(getDoc(doc(client('admin'), 'LS_CHAT_AI', 'mine')));
  for (const uid of ['doctor', 'locked']) {
    await assertFails(getDoc(doc(client(uid), 'LS_CHAT_AI', 'mine')));
    await assertFails(setDoc(doc(client(uid), 'LS_CHAT_AI', 'forged'), transcript));
  }
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'LS_CHAT_AI', 'mine')));
  await assertFails(getDocs(collection(client('patient'), 'LS_CHAT_AI')));
  assert.equal((await assertSucceeds(getDocs(query(collection(client('patient'), 'LS_CHAT_AI'), where('authUserId', '==', 'patient'))))).size, 1);
  for (const change of [{ authUserId: 'doctor' }, { userId: 'doctor' }, { userMessage: '' }, { userMessage: 'x'.repeat(2001) },
    { aiReply: 'x'.repeat(4001) }, { sessionId: '' }, { source: 'FAKE' }, { timestamp: new Date(0) }, { privateField: 'forbidden' }]) {
    await assertFails(setDoc(doc(client('patient'), 'LS_CHAT_AI', 'invalid'), { ...transcript, ...change }));
  }
  await assertFails(updateDoc(doc(client('patient'), 'LS_CHAT_AI', 'mine'), { aiReply: 'forged' }));
  await assertFails(deleteDoc(doc(client('patient'), 'LS_CHAT_AI', 'mine')));
  await db.collection('TAI_KHOAN').doc('patient').update({ isActive: false });
  await assertFails(getDoc(doc(client('patient'), 'LS_CHAT_AI', 'mine')));
  await assertFails(setDoc(doc(client('patient'), 'LS_CHAT_AI', 'locked'), transcript));
});

test('ADM-02/05/08: admin queries real collections, empty data and revoked permissions', async () => {
  for (const name of ['CHUYEN_KHOA', 'BAC_SI', 'LICH_HEN']) {
    const result = await assertSucceeds(getDocs(collection(client('admin'), name)));
    assert.ok(result.size > 0);
    await assertFails(getDocs(collection(client('locked'), name)));
    await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), name)));
  }
  await assertSucceeds(getDoc(doc(client('admin'), 'BAC_SI', 'missing')));
  await db.collection('LICH_HEN').doc('appointment').delete();
  assert.equal((await assertSucceeds(getDocs(collection(client('admin'), 'LICH_HEN')))).size, 0);
});

test('ADM-08/05: specialty and doctor writes respect schema and privilege', async () => {
  const specialty = { name: 'Tim mạch', description: '', status: 'ACTIVE', isActive: true };
  await assertSucceeds(setDoc(doc(client('admin'), 'CHUYEN_KHOA', 'new'), specialty));
  await assertSucceeds(updateDoc(doc(client('admin'), 'CHUYEN_KHOA', 'new'), { name: 'Tim mạch 2' }));
  await assertFails(updateDoc(doc(client('patient'), 'CHUYEN_KHOA', 'new'), { name: 'Giả mạo' }));
  await assertFails(updateDoc(doc(client('admin'), 'CHUYEN_KHOA', 'new'), { name: '' }));
  await assertSucceeds(updateDoc(doc(client('admin'), 'BAC_SI', 'doctor'), { fullName: 'Bác sĩ cập nhật' }));
  await assertFails(updateDoc(doc(client('doctor'), 'BAC_SI', 'doctor'), { consultationFee: 0 }));
  await assertFails(updateDoc(doc(client('admin'), 'BAC_SI', 'doctor'), { userId: 'other-doctor' }));
  await assertFails(updateDoc(doc(client('admin'), 'BAC_SI', 'doctor'), { specialtyId: 'missing' }));
});

test('ADM-12: schedules and slots reject bad ranges, missing parents and counter tampering', async () => {
  const schedule = { doctorId: 'doctor', workDate: day, startTime: '13:00', endTime: '16:00', status: 'ACTIVE' };
  await assertSucceeds(setDoc(doc(client('admin'), 'LICH_LAM_VIEC', 'new'), schedule));
  await assertSucceeds(setDoc(doc(client('admin'), 'LICH_LAM_VIEC', 'saturday-am'), {
    ...schedule, workDate: new Date('2026-11-07T00:00:00+07:00'), startTime: '08:00', endTime: '12:00',
  }));
  for (const workDate of [new Date('2026-11-07T00:00:00+07:00'), new Date('2026-11-08T00:00:00+07:00')]) {
    await assertFails(setDoc(doc(client('admin'), 'LICH_LAM_VIEC', 'weekend-invalid'), { ...schedule, workDate }));
  }
  for (const bad of [{ startTime: '25:00' }, { endTime: '12:00' }, { workDate: null }, { doctorId: 'missing' }]) {
    await assertFails(setDoc(doc(client('admin'), 'LICH_LAM_VIEC', 'invalid'), { ...schedule, ...bad }));
  }
  const slot = { doctorId: 'doctor', workScheduleId: 'schedule', startTime: '09:00', endTime: '10:00', capacity: 3, bookedCount: 0, status: 'AVAILABLE' };
  await assertSucceeds(setDoc(doc(client('admin'), 'CA_KHAM', 'new'), slot));
  for (const bad of [{ startTime: '07:00' }, { endTime: '13:00' }, { endTime: '08:00' }, { capacity: 0 },
    { bookedCount: -1 }, { bookedCount: 4 }, { status: 'BOOKED' }, { doctorId: 'other-doctor' }, { workScheduleId: 'missing' }]) {
    await assertFails(setDoc(doc(client('admin'), 'CA_KHAM', 'invalid'), { ...slot, ...bad }));
  }
  for (const bad of [{ bookedCount: 0 }, { reservationCounts: {} }, { capacity: 0 }, { startTime: '08:15' }, { workScheduleId: 'new' }]) {
    await assertFails(updateDoc(doc(client('admin'), 'CA_KHAM', 'slot'), bad));
  }
  await assertFails(deleteDoc(doc(client('admin'), 'CA_KHAM', 'slot')));
});

test('ADM-15: scoped appointment queries succeed; broad or foreign reads fail', async () => {
  for (const [uid, field] of [['doctor', 'doctorId'], ['patient', 'patientId']]) {
    const data = await assertSucceeds(getDocs(query(collection(client(uid), 'LICH_HEN'), where(field, '==', uid))));
    assert.equal(data.docs[0].data().timeSlotId, 'slot');
    await assertFails(getDocs(collection(client(uid), 'LICH_HEN')));
  }
  await assertFails(getDoc(doc(client('other-doctor'), 'LICH_HEN', 'appointment')));
  await assertSucceeds(getDocs(collection(client('admin'), 'LICH_HEN')));
  await assertFails(updateDoc(doc(client('patient'), 'LICH_HEN', 'appointment'), { doctorId: 'other-doctor' }));
});

test('ADM-15: an inactive doctor profile cannot read appointments even with an active login', async () => {
  await db.collection('BAC_SI').doc('doctor').update({ isActive: false });
  await assertFails(getDoc(doc(client('doctor'), 'LICH_HEN', 'appointment')));
});

test('ADM-18: request stores verified sender and rejects forged or edited submissions', async () => {
  const ref = doc(client('doctor'), 'YEU_CAU_BAC_SI', 'request');
  await assertSucceeds(getDoc(ref)); // Transaction retry can check a new id.
  await assertSucceeds(setDoc(ref, report()));
  const saved = (await assertSucceeds(getDoc(ref))).data();
  assert.equal(saved.senderId, 'doctor');
  assert.ok(saved.createdAt.toMillis() > 0);
  for (const bad of [{ senderId: 'other-doctor' }, { doctorId: 'other-doctor' }, { status: 'APPROVED' },
    { reviewedBy: 'admin' }, { createdAt: new Date(0) }, { reason: '' }, { date: new Date(0) }]) {
    await assertFails(setDoc(doc(client('doctor'), 'YEU_CAU_BAC_SI', randomUUID()), report(bad)));
  }
  await assertFails(getDoc(doc(client('other-doctor'), 'YEU_CAU_BAC_SI', 'request')));
  await assertFails(getDoc(doc(client('patient'), 'YEU_CAU_BAC_SI', 'request')));
  await assertFails(updateDoc(ref, { reason: 'Tự sửa sau khi gửi' }));
  await assertFails(updateDoc(doc(client('admin'), 'YEU_CAU_BAC_SI', 'request'), { reviewedBy: 'someone' }));
});

test('ADM-18: backend review uses authenticated admin, replies and server time; exact retry is idempotent', async () => {
  await assertSucceeds(setDoc(doc(client('doctor'), 'YEU_CAU_BAC_SI', 'request'), report()));
  const requestId = randomUUID(), values = { status: 'APPROVED', adminResponse: 'Đã tiếp nhận.', reviewedBy: 'forged' };
  await assert.rejects(command('doctor', values), (e) => e.code === 'permission-denied');
  await command('admin', values, { requestId });
  await command('admin', values, { requestId });
  const saved = (await db.collection('YEU_CAU_BAC_SI').doc('request').get()).data();
  assert.equal(saved.senderId, 'doctor');
  assert.equal(saved.reviewedBy, 'admin');
  assert.equal(saved.adminResponse, 'Đã tiếp nhận.');
  assert.equal(saved.status, 'APPROVED');
  assert.ok(saved.reviewedAt instanceof Timestamp);
  assert.ok(saved.reviewedAt.toMillis() >= saved.createdAt.toMillis());
  await assert.rejects(command('admin2', { status: 'REJECTED', adminResponse: 'Duyệt lần hai' }));
});

test('ADM-20: only admin reviews pending patients; clients cannot elevate roles', async () => {
  await db.collection('TAI_KHOAN').doc('pending').set({ role: 'patient', isActive: false, status: 'PENDING', email: 'pending@example.com', fullName: 'Chờ duyệt', phone: '' });
  await assertSucceeds(getDocs(query(collection(client('admin'), 'TAI_KHOAN'), where('status', '==', 'PENDING'))));
  await assertFails(getDocs(collection(client('patient'), 'TAI_KHOAN')));
  await assertFails(updateDoc(doc(client('patient'), 'TAI_KHOAN', 'patient'), { role: 'admin' }));
  await assertFails(updateDoc(doc(client('pending'), 'TAI_KHOAN', 'pending'), { status: 'APPROVED', isActive: true }));
  await assertSucceeds(updateDoc(doc(client('admin'), 'TAI_KHOAN', 'pending'), { status: 'APPROVED', isActive: true, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(client('admin'), 'TAI_KHOAN', 'pending'), { role: 'admin' }));
  await assertFails(updateDoc(doc(client('locked'), 'TAI_KHOAN', 'patient'), { role: 'admin' }));
});
