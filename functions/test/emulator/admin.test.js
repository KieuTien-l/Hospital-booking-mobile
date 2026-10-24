import test, { before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, writeBatch, collection, query, where, getDocs, runTransaction, serverTimestamp } from 'firebase/firestore';
import { executeAdminCommand } from '../../src/commands.js';
import { date } from '../../src/policy.js';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('These tests require local Firestore + Auth emulators. Never run against production.');
const projectId = 'demo-healway-admin';
const app = initializeApp({ projectId }, `test-${randomUUID()}`), db = getFirestore(app), auth = getAuth(app);
let env;
const day = (() => { const d = new Date(Date.now() + 15 * 86400000); while ([0, 6].includes(d.getUTCDay())) d.setUTCDate(d.getUTCDate() + 1); return d.toISOString().slice(0, 10); })();
const command = (operation, extra = {}, uid = 'admin') => executeAdminCommand(db, auth, uid, { requestId: randomUUID(), operation, reason: 'Kiểm thử emulator', ...extra });
const get = async (c, key) => (await db.collection(c).doc(key).get()).data();

before(async () => { env = await initializeTestEnvironment({ projectId, firestore: { rules: await readFile(new URL('../../../firestore.rules', import.meta.url), 'utf8') } }); });
beforeEach(async () => {
  await env.clearFirestore();
  await db.collection('TAI_KHOAN').doc('admin').set({ role: 'admin', isActive: true, fullName: 'Admin' });
  await db.collection('TAI_KHOAN').doc('patient').set({ role: 'patient', isActive: true, fullName: 'Bệnh nhân', phone: '' });
  await db.collection('TAI_KHOAN').doc('doctor').set({ role: 'doctor', isActive: true, fullName: 'Bác sĩ', phone: '' });
  await db.collection('CHUYEN_KHOA').doc('specialty').set({ name: 'Nội', status: 'ACTIVE' });
  await db.collection('BAC_SI').doc('doctor').set({ userId: 'doctor', fullName: 'BS An', specialtyId: 'specialty', status: 'ACTIVE', acceptingBookings: true, isActive: true, consultationFee: 150000, yearsOfExperience: 4 });
  await db.collection('BENH_NHAN').doc('patient').set({ authUserId: 'patient', fullName: 'Bệnh nhân', isActive: true, status: 'ACTIVE' });
  await db.collection('LICH_LAM_VIEC').doc('schedule').set({ doctorId: 'doctor', workDate: date(day), startTime: '08:00', endTime: '11:00', status: 'ACTIVE' });
  for (const [key, startTime, endTime] of [['slot', '08:00', '08:30'], ['other', '09:00', '09:30']]) await db.collection('CA_KHAM').doc(key).set({ doctorId: 'doctor', workScheduleId: 'schedule', startTime, endTime, capacity: 5, bookedCount: 0, status: 'AVAILABLE' });
});
after(async () => { await env?.cleanup(); await deleteApp(app); });

test('ADM-20: legacy accountKey profiles can be edited but their account role cannot change', async () => {
  await db.collection('TAI_KHOAN').doc('doctor').update({ accountKey: '161' });
  await db.collection('BAC_SI').doc('doctor').update({ userId: '161' });
  await command('save', { collection: 'BAC_SI', id: 'doctor', values: { fullName: 'BS cập nhật', phone: '0901234567' } });
  assert.equal((await get('TAI_KHOAN', 'doctor')).fullName, 'BS cập nhật');
  assert.equal((await get('BAC_SI', 'doctor')).phone, '0901234567');
  for (const role of ['patient', 'admin']) {
    await assert.rejects(command('accountAccess', { collection: 'TAI_KHOAN', id: 'doctor', values: { role, isActive: true } }));
  }
  await command('accountAccess', { collection: 'TAI_KHOAN', id: 'doctor', values: { role: 'doctor', isActive: false } });
  assert.equal((await get('TAI_KHOAN', 'doctor')).isActive, false);
});
test('regression: re-enabling an overlapping schedule is rejected', async () => {
  await db.collection('LICH_LAM_VIEC').doc('overlap').set({ doctorId: 'doctor', workDate: date(day), startTime: '09:00', endTime: '12:00', status: 'INACTIVE' });
  await assert.rejects(command('setAvailability', { collection: 'LICH_LAM_VIEC', id: 'overlap', values: { enabled: true } }), /trùng giờ/);
  assert.equal((await get('LICH_LAM_VIEC', 'overlap')).status, 'INACTIVE');
});
test('regression: editing a cancelled slot preserves its cancellation', async () => {
  await db.collection('CA_KHAM').doc('slot').update({ status: 'CANCELLED' });
  await command('saveSlot', { collection: 'CA_KHAM', id: 'slot', values: { startTime: '08:00', endTime: '08:30', capacity: 6 } });
  assert.equal((await get('CA_KHAM', 'slot')).status, 'CANCELLED');
});
test('regression: requests prevent deleting their schedule or doctor', async () => {
  await db.collection('YEU_CAU_BAC_SI').doc('request').set({ doctorId: 'doctor', scheduleId: 'schedule', status: 'PENDING' });
  await assert.rejects(command('delete', { collection: 'LICH_LAM_VIEC', id: 'schedule' }), /dữ liệu liên quan/);
  await db.collection('BAC_SI').doc('unused-doctor').set({ userId: 'doctor', status: 'ACTIVE' });
  await db.collection('YEU_CAU_BAC_SI').doc('other-request').set({ doctorId: 'unused-doctor', scheduleId: 'historical', status: 'PENDING' });
  await assert.rejects(command('delete', { collection: 'BAC_SI', id: 'unused-doctor' }), /dữ liệu liên quan/);
  assert.ok(await get('LICH_LAM_VIEC', 'schedule')); assert.ok(await get('BAC_SI', 'unused-doctor'));
});

test('non-admin, locked admin and stale writes are rejected', async () => {
  await assert.rejects(command('create', { collection: 'CHUYEN_KHOA', values: { name: 'X' } }, 'doctor'), (e) => e.code === 'permission-denied');
  await db.collection('TAI_KHOAN').doc('admin').update({ isActive: false });
  await assert.rejects(command('create', { collection: 'CHUYEN_KHOA', values: { name: 'X' } }), (e) => e.code === 'permission-denied');
  await db.collection('TAI_KHOAN').doc('admin').update({ isActive: true });
  await db.collection('CHUYEN_KHOA').doc('specialty').update({ updatedAt: new Date() });
  await assert.rejects(command('save', { collection: 'CHUYEN_KHOA', id: 'specialty', expectedUpdatedAt: 1, values: { name: 'Stale' } }), (e) => e.code === 'aborted');
  assert.equal((await get('CHUYEN_KHOA', 'specialty')).name, 'Nội');
});
test('doctor provisioning creates linked identities without touching admin, retries are idempotent', async () => {
  const loginEmail = `${randomUUID()}@example.com`;
  const input = { requestId: randomUUID(), operation: 'createDoctor', reason: 'Tuyển bác sĩ', values: { loginEmail, fullName: 'Bác sĩ mới', email: 'contact@example.com', specialtyId: 'specialty', yearsOfExperience: 4, consultationFee: 180000 } };
  const result = await executeAdminCommand(db, auth, 'admin', input);
  const again = await executeAdminCommand(db, auth, 'admin', input);
  assert.equal(result.id, again.id);
  assert.equal((await get('TAI_KHOAN', result.id)).role, 'doctor');
  assert.equal((await get('TAI_KHOAN', result.id)).email, loginEmail);
  assert.equal((await get('BAC_SI', result.id)).userId, result.id);
  assert.equal((await get('BAC_SI', result.id)).email, 'contact@example.com');
  assert.equal((await get('TAI_KHOAN', 'admin')).role, 'admin');
  assert.equal((await auth.getUser(result.id)).email, loginEmail);
  assert.equal((await get('ADMIN_PROVISIONING', input.requestId)).status, 'READY');
  assert.equal(JSON.stringify(await get('NHAT_KY_ADMIN', input.requestId)).includes('password'), false);
  await auth.deleteUser(result.id);
});
test('failed doctor profile commit rolls Auth user back; lost commit acknowledgement never deletes a valid user', async () => {
  const values = { loginEmail: `${randomUUID()}@example.com`, fullName: 'BS Test', specialtyId: 'specialty', consultationFee: 1, yearsOfExperience: 1 };
  let calls = 0;
  const brokenDb = { collection: (c) => db.collection(c), runTransaction: (cb) => ++calls === 2 ? Promise.reject(new Error('failure')) : db.runTransaction(cb) };
  const requestId = randomUUID();
  await assert.rejects(executeAdminCommand(brokenDb, auth, 'admin', { requestId, operation: 'createDoctor', reason: 'test', values }));
  assert.equal((await get('ADMIN_PROVISIONING', requestId)).status, 'FAILED');
  await assert.rejects(auth.getUserByEmail(values.loginEmail));
  calls = 0;
  const uncertainDb = { collection: (c) => db.collection(c), runTransaction: async (cb) => { const result = await db.runTransaction(cb); if (++calls === 2) throw new Error('ack lost'); return result; } };
  const ready = await executeAdminCommand(uncertainDb, auth, 'admin', { requestId: randomUUID(), operation: 'createDoctor', reason: 'test', values });
  assert.equal((await auth.getUser(ready.id)).email, values.loginEmail);
  assert.ok(await get('BAC_SI', ready.id));
  await auth.deleteUser(ready.id);
});
test('concurrent booking cannot overbook and exact retries do not duplicate notifications', async () => {
  await db.collection('CA_KHAM').doc('slot').update({ capacity: 1 });
  const input = { requestId: randomUUID(), operation: 'book', reason: 'Tiếp nhận', values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 1 } };
  const results = await Promise.allSettled([executeAdminCommand(db, auth, 'admin', input), command('book', { values: input.values })]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal((await get('CA_KHAM', 'slot')).bookedCount, 1);
  const winner = results.find((r) => r.status === 'fulfilled').value;
  if (winner.id === input.requestId) await executeAdminCommand(db, auth, 'admin', input);
  assert.equal((await db.collection('LICH_HEN').get()).size, 1);
  assert.equal((await db.collection('THONG_BAO').get()).size, 1);
});
test('cancel returns exactly the group size and keeps locked slots locked', async () => {
  const first = await command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 3 } });
  const other = await command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 2 } });
  await command('setAvailability', { collection: 'CA_KHAM', id: 'slot', values: { enabled: false } });
  const input = { requestId: randomUUID(), operation: 'appointmentStatus', id: first.id, reason: 'Bệnh nhân hủy', values: { status: 'CANCELLED' } };
  await executeAdminCommand(db, auth, 'admin', input);
  await executeAdminCommand(db, auth, 'admin', input);
  assert.equal((await get('CA_KHAM', 'slot')).bookedCount, 2);
  assert.equal((await get('CA_KHAM', 'slot')).status, 'UNAVAILABLE');
  assert.equal((await get('CA_KHAM', 'slot')).appointmentId, other.id);
  await assert.rejects(command('appointmentStatus', { id: first.id, values: { status: 'CANCELLED' } }));
});
test('rescheduling is all-or-nothing and cannot move a completed appointment', async () => {
  const booking = await command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 2 } });
  await db.collection('CA_KHAM').doc('other').update({ bookedCount: 5, status: 'BOOKED' });
  await assert.rejects(command('reschedule', { id: booking.id, values: { timeSlotId: 'other' } }));
  assert.equal((await get('CA_KHAM', 'slot')).bookedCount, 2);
  await db.collection('CA_KHAM').doc('other').update({ bookedCount: 0, status: 'AVAILABLE' });
  await command('reschedule', { id: booking.id, values: { timeSlotId: 'other' } });
  assert.equal((await get('CA_KHAM', 'slot')).bookedCount, 0);
  assert.equal((await get('CA_KHAM', 'other')).bookedCount, 2);
  assert.equal((await get('LICH_HEN', booking.id)).timeSlotId, 'other');
  await db.collection('LICH_HEN').doc(booking.id).update({ status: 'COMPLETED' });
  await assert.rejects(command('reschedule', { id: booking.id, values: { timeSlotId: 'slot' } }));
});

test('admin booking, cancellation and rescheduling preserve reservations created by patient flow', async () => {
  const patientBooking = 'patient-booking';
  const schedule = await get('LICH_LAM_VIEC', 'schedule');
  await db.collection('LICH_HEN').doc(patientBooking).set({ patientId: 'patient', doctorId: 'doctor',
    workScheduleId: 'schedule', timeSlotId: 'slot', specialtyId: 'specialty',
    appointmentDate: schedule.workDate, startTime: '08:00', endTime: '08:30', peopleCount: 2, status: 'PENDING' });
  await db.collection('CA_KHAM').doc('slot').update({ bookedCount: 2, reservationCounts: { [patientBooking]: 2 }, appointmentId: patientBooking });
  const added = await command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 1 } });
  assert.deepEqual((await get('CA_KHAM', 'slot')).reservationCounts, { [patientBooking]: 2, [added.id]: 1 });
  await command('appointmentStatus', { id: added.id, values: { status: 'CANCELLED' } });
  assert.deepEqual((await get('CA_KHAM', 'slot')).reservationCounts, { [patientBooking]: 2 });
  await command('reschedule', { id: patientBooking, values: { timeSlotId: 'other' } });
  assert.deepEqual((await get('CA_KHAM', 'slot')).reservationCounts, {});
  assert.deepEqual((await get('CA_KHAM', 'other')).reservationCounts, { [patientBooking]: 2 });
  assert.equal((await get('CA_KHAM', 'other')).bookedCount, 2);
});
test('referenced records cannot be deleted, appointments cannot be deleted at all', async () => {
  await assert.rejects(command('delete', { collection: 'CHUYEN_KHOA', id: 'specialty' }));
  await assert.rejects(command('delete', { collection: 'BAC_SI', id: 'doctor' }));
  await command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 1 } });
  await assert.rejects(command('delete', { collection: 'LICH_LAM_VIEC', id: 'schedule' }));
  await assert.rejects(command('delete', { collection: 'LICH_HEN', id: 'anything' }));
  const result = await command('create', { collection: 'CHUYEN_KHOA', values: { name: 'Chuyên khoa mới' } });
  await command('delete', { collection: 'CHUYEN_KHOA', id: result.id });
  assert.equal(await get('CHUYEN_KHOA', result.id), undefined);
  assert.ok((await db.collection('ADMIN_ARCHIVES').get()).size);
});
test('schedule creation generates slots, checks overlap, and cannot edit a booked schedule', async () => {
  const values = { doctorId: 'doctor', workDate: day, startTime: '13:00', endTime: '14:00', slotDuration: 30, capacity: 3, repeatWeeks: 1 };
  const schedule = await command('createSchedule', { values });
  const slots = await db.collection('CA_KHAM').where('workScheduleId', '==', schedule.id).get();
  assert.equal(slots.size, 2);
  await assert.rejects(command('createSchedule', { values }));
  await command('book', { values: { patientId: 'patient', timeSlotId: slots.docs[0].id, peopleCount: 1 } });
  await assert.rejects(command('editSchedule', { id: schedule.id, values: { ...values, startTime: '14:00', endTime: '15:00' } }));
});

test('unused schedule deletion removes only its unused generated slots and keeps an audit archive', async () => {
  const schedule = await command('createSchedule', { values: { doctorId: 'doctor', workDate: day, startTime: '13:00', endTime: '14:00', slotDuration: 30, capacity: 3 } });
  await command('delete', { collection: 'LICH_LAM_VIEC', id: schedule.id });
  assert.equal(await get('LICH_LAM_VIEC', schedule.id), undefined);
  assert.equal((await db.collection('CA_KHAM').where('workScheduleId', '==', schedule.id).get()).size, 0);
  assert.ok(await get('CA_KHAM', 'slot'));
  assert.equal((await db.collection('ADMIN_ARCHIVES').get()).size, 1);
});

test('patient feedback transaction is idempotent, cannot impersonate another patient, and receives admin response', async () => {
  const patientDb = env.authenticatedContext('patient').firestore();
  const reference = doc(patientDb, 'PHAN_HOI', 'feedback');
  const draft = { userId: 'patient', patientId: 'patient', title: 'Góp ý', content: 'Cần hỗ trợ', category: 'suggestion', rating: 4, processingStatus: 'NEW' };
  const submit = () => runTransaction(patientDb, async (tx) => {
    if (!(await tx.get(reference)).exists()) tx.set(reference, { ...draft, createdAt: serverTimestamp() });
  });
  await assertSucceeds(submit());
  await assertSucceeds(submit());
  await assertFails(setDoc(doc(patientDb, 'PHAN_HOI', 'forged'), { ...draft, patientId: 'someone-else', createdAt: serverTimestamp() }));
  await command('feedback', { collection: 'PHAN_HOI', id: 'feedback', values: { processingStatus: 'RESOLVED', response: 'Đã tiếp nhận và xử lý.' } });
  const feedback = (await assertSucceeds(getDoc(reference))).data();
  assert.equal(feedback.content, draft.content);
  assert.equal(feedback.rating, 4);
  assert.equal(feedback.processingStatus, 'RESOLVED');
  assert.equal(feedback.response, 'Đã tiếp nhận và xử lý.');
  await assertFails(updateDoc(reference, { response: 'Tự sửa' }));
  const notices = await assertSucceeds(getDocs(query(collection(patientDb, 'THONG_BAO'), where('userId', '==', 'patient'), where('status', '==', 'SENT'))));
  assert.equal(notices.size, 1);
});
test('doctor edits require admin, patient registration requires approval and existing patient profile edits remain allowed', async () => {
  const doctorDb = env.authenticatedContext('doctor').firestore();
  await assertFails(updateDoc(doc(doctorDb, 'BAC_SI', 'doctor'), { fullName: 'Hacked' }));
  await assertFails(updateDoc(doc(doctorDb, 'TAI_KHOAN', 'doctor'), { phone: '123' }));
  const adminDb = env.authenticatedContext('admin').firestore();
  await assertSucceeds(updateDoc(doc(adminDb, 'BAC_SI', 'doctor'), { fullName: 'Admin updated doctor' }));
  const patientDb = env.authenticatedContext('patient').firestore();
  await assertSucceeds(updateDoc(doc(patientDb, 'TAI_KHOAN', 'patient'), { phone: '0901234567' }));
  const signup = env.authenticatedContext('new-patient').firestore();
  const batch = writeBatch(signup);
  await assertFails(setDoc(doc(signup, 'TAI_KHOAN', 'new-patient'), { fullName: 'Mới', phone: '', email: 'new@example.com', role: 'patient', isActive: true, status: 'ACTIVE', createdAt: new Date(), updatedAt: new Date() }));
  batch.set(doc(signup, 'TAI_KHOAN', 'new-patient'), { fullName: 'Mới', phone: '', email: 'new@example.com', role: 'patient', isActive: false, status: 'PENDING', createdAt: new Date(), updatedAt: new Date() });
  batch.set(doc(signup, 'BENH_NHAN', 'new-patient'), { authUserId: 'new-patient', fullName: 'Mới' });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(signup, 'TAI_KHOAN', 'forged'), { role: 'doctor', isActive: true }));
});
test('internal notes stay outside appointments and cannot be read by doctors or patients', async () => {
  const booking = await command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 1 } });
  await command('internalNote', { id: booking.id, values: { internalNote: 'Chỉ admin' } });
  assert.equal((await get('LICH_HEN', booking.id)).internalNote, undefined);
  assert.equal((await get('ADMIN_NOTES', booking.id)).internalNote, 'Chỉ admin');
  await assertFails(getDoc(doc(env.authenticatedContext('doctor').firestore(), 'ADMIN_NOTES', booking.id)));
  await assertFails(getDoc(doc(env.authenticatedContext('patient').firestore(), 'ADMIN_NOTES', booking.id)));
});
test('notification preview/draft is private; send is immutable and patient can only mark read', async () => {
  const draft = await command('notificationDraft', { values: { patientId: 'patient', title: 'Thông báo', content: 'Nội dung' } });
  const patientDb = env.authenticatedContext('patient').firestore();
  await assertFails(getDoc(doc(patientDb, 'THONG_BAO', draft.id)));
  await command('sendNotification', { id: draft.id });
  await assertSucceeds(getDoc(doc(patientDb, 'THONG_BAO', draft.id)));
  await assertSucceeds(updateDoc(doc(patientDb, 'THONG_BAO', draft.id), { isRead: true }));
  await assertFails(updateDoc(doc(patientDb, 'THONG_BAO', draft.id), { content: 'Sửa nội dung' }));
  await assert.rejects(command('delete', { collection: 'THONG_BAO', id: draft.id }));
  await assert.rejects(command('sendNotification', { id: draft.id }));
});
test('account guards prevent self-lock and linked-role changes; stopping bookings does not lock doctor access', async () => {
  await assert.rejects(command('accountAccess', { id: 'admin', values: { role: 'admin', isActive: false } }));
  await assert.rejects(command('accountAccess', { id: 'doctor', values: { role: 'admin', isActive: true } }));
  await command('setAvailability', { collection: 'BAC_SI', id: 'doctor', values: { enabled: false } });
  assert.equal((await get('TAI_KHOAN', 'doctor')).isActive, true);
  assert.equal((await get('BAC_SI', 'doctor')).status, 'ACTIVE');
  await assert.rejects(command('book', { values: { patientId: 'patient', timeSlotId: 'slot', peopleCount: 1 } }));
});
test('review/refund requests cannot fake settlement and duplicate refunds are rejected', async () => {
  await db.collection('THANH_TOAN').doc('payment').set({ amount: 150000, status: 'PAID' });
  await command('paymentReview', { id: 'payment', values: { reviewStatus: 'REVIEWED', reviewNote: 'Khớp', status: 'FAILED', amount: 1 } });
  assert.equal((await get('THANH_TOAN', 'payment')).amount, 150000);
  assert.equal((await get('THANH_TOAN', 'payment')).status, 'PAID');
  await command('paymentReview', { id: 'payment', values: { refundRequested: true } });
  assert.equal((await db.collection('YEU_CAU_HOAN_TIEN').get()).docs[0].data().status, 'REQUESTED');
  await assert.rejects(command('paymentReview', { id: 'payment', values: { refundRequested: true } }));
});
