import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldPath, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const startDate = argumentValue('--start-date') || '2026-10-20';
const days = Number(argumentValue('--days') || '7');
const strict = process.argv.slice(2).includes('--strict');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate)) {
  throw new Error('Use --start-date=YYYY-MM-DD.');
}
if (!Number.isInteger(days) || days < 1 || days > 31) {
  throw new Error('Use --days between 1 and 31.');
}
if (!serviceAccountPath) {
  throw new Error(
    'Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.',
  );
}

const serviceAccount = JSON.parse(
  await readFile(resolve(serviceAccountPath), 'utf8'),
);
if (serviceAccount.project_id !== projectId) {
  throw new Error(
    `The service account is for ${serviceAccount.project_id}, not ${projectId}.`,
  );
}
if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount), projectId });
}

const firestore = getFirestore();
const [accountsSnapshot, specialtiesSnapshot, doctorsSnapshot, patientsSnapshot,
  schedulesSnapshot, appointmentsSnapshot, paymentsSnapshot,
  notificationsSnapshot] = await Promise.all([
  firestore.collection('TAI_KHOAN').get(),
  firestore.collection('CHUYEN_KHOA').get(),
  firestore.collection('BAC_SI').get(),
  firestore.collection('BENH_NHAN').get(),
  firestore.collection('LICH_LAM_VIEC').get(),
  firestore.collection('LICH_HEN').get(),
  firestore.collection('THANH_TOAN').get(),
  firestore.collection('THONG_BAO').get(),
]);
// CA_KHAM is the largest collection after seeding. Read it in bounded pages
// so the diagnostic works within Firestore response limits.
const slotsSnapshot = {
  docs: await readCollectionInPages('CA_KHAM'),
};

const specialties = documentMap(specialtiesSnapshot);
const doctors = documentMap(doctorsSnapshot);
const accounts = documentMap(accountsSnapshot);
const patients = documentMap(patientsSnapshot);
const schedules = documentMap(schedulesSnapshot);
const slots = documentMap(slotsSnapshot);
const appointments = documentMap(appointmentsSnapshot);
const payments = documentMap(paymentsSnapshot);
const notifications = documentMap(notificationsSnapshot);
const dates = Array.from({ length: days }, (_, index) =>
  addVietnamDays(startDate, index),
);

const findings = {
  patientProfilesWithMissingIdentity: [],
  patientProfilesWithoutAccount: [],
  patientAccountsWithoutProfile: [],
  duplicatePatientProfiles: [],
  doctorProfilesWithoutAccountLink: [],
  doctorsWithoutActiveSpecialty: [],
  schedulesWithInvalidDoctor: [],
  schedulesWithInvalidDate: [],
  slotsWithInvalidSchedule: [],
  slotsWithDoctorMismatch: [],
  slotsWithInvalidCapacity: [],
  slotsWithInvalidStatus: [],
  slotsWithReservationMismatch: [],
  appointmentsWithInvalidReferences: [],
  appointmentsWithScheduleMismatch: [],
  paymentsWithInvalidPatient: [],
  paymentsWithInvalidAppointment: [],
  paymentsWithPatientMismatch: [],
  paymentsWithInvalidAmount: [],
  paymentsWithInvalidStatus: [],
  successfulPaymentsWithoutPaidAt: [],
  notificationsWithInvalidPatient: [],
  notificationsWithInvalidAppointment: [],
};

const patientProfileIdsByAuthUserId = new Map();
const doctorAccountIdsByLegacyKey = new Map();
for (const [accountId, account] of accounts) {
  if (stringValue(account.role).toLowerCase() !== 'doctor') continue;
  const accountKey = stringValue(account.accountKey);
  if (accountKey === '') continue;
  const accountIds = doctorAccountIdsByLegacyKey.get(accountKey) ?? [];
  accountIds.push(accountId);
  doctorAccountIdsByLegacyKey.set(accountKey, accountIds);
}
for (const [patientId, patient] of patients) {
  const authUserId = stringValue(patient.authUserId);
  if (authUserId === '' || stringValue(patient.fullName) === '') {
    findings.patientProfilesWithMissingIdentity.push(patientId);
  }
  if (authUserId !== '') {
    if (!accounts.has(authUserId)) {
      findings.patientProfilesWithoutAccount.push(patientId);
    }
    const ids = patientProfileIdsByAuthUserId.get(authUserId) ?? [];
    ids.push(patientId);
    patientProfileIdsByAuthUserId.set(authUserId, ids);
  }
}
for (const [accountId, account] of accounts) {
  if (stringValue(account.role).toLowerCase() !== 'patient') continue;
  if (!patientProfileIdsByAuthUserId.has(accountId)) {
    findings.patientAccountsWithoutProfile.push(accountId);
  }
}
for (const [authUserId, patientIds] of patientProfileIdsByAuthUserId) {
  if (patientIds.length > 1) findings.duplicatePatientProfiles.push(authUserId);
}

const activeSpecialtyIds = new Set(
  [...specialties.entries()]
      .filter(([, value]) => isActive(value))
      .map(([id]) => id),
);
const activeDoctors = new Map(
  [...doctors.entries()].filter(([, value]) => isActive(value)),
);

for (const [doctorId, doctor] of activeDoctors) {
  const doctorUserId = stringValue(doctor.userId);
  const linkedAccount = accounts.get(doctorUserId);
  const isLinkedByAuthUid =
      linkedAccount && stringValue(linkedAccount.role).toLowerCase() === 'doctor';
  const legacyAccountIds = doctorAccountIdsByLegacyKey.get(doctorUserId) ?? [];
  // Historical imports can retain more than one account record with the same
  // accountKey. A doctor is still resolvable whenever at least one doctor
  // account has that key; requiring exactly one would falsely flag valid
  // dashboard logins.
  if (!isLinkedByAuthUid && legacyAccountIds.length === 0) {
    findings.doctorProfilesWithoutAccountLink.push(doctorId);
  }
  if (
    typeof doctor.specialtyId !== 'string' ||
    !activeSpecialtyIds.has(doctor.specialtyId)
  ) {
    findings.doctorsWithoutActiveSpecialty.push(doctorId);
  }
}

for (const [scheduleId, schedule] of schedules) {
  if (!doctors.has(schedule.doctorId)) {
    findings.schedulesWithInvalidDoctor.push(scheduleId);
  }
  if (!toDate(schedule.workDate)) {
    findings.schedulesWithInvalidDate.push(scheduleId);
  }
}

for (const [slotId, slot] of slots) {
  const schedule = schedules.get(slot.workScheduleId);
  if (!schedule) {
    findings.slotsWithInvalidSchedule.push(slotId);
    continue;
  }
  if (slot.doctorId !== schedule.doctorId) {
    findings.slotsWithDoctorMismatch.push(slotId);
  }
  const capacity = slot.capacity;
  const bookedCount = slot.bookedCount;
  if (
    !Number.isInteger(capacity) ||
    capacity < 1 ||
    !Number.isInteger(bookedCount) ||
    bookedCount < 0 ||
    bookedCount > capacity
  ) {
    findings.slotsWithInvalidCapacity.push(slotId);
  }
  if (
    (slot.status === 'AVAILABLE' && bookedCount >= capacity) ||
    (slot.status === 'BOOKED' && bookedCount !== capacity)
  ) {
    findings.slotsWithInvalidStatus.push(slotId);
  }
  if (slot.reservationCounts && typeof slot.reservationCounts === 'object') {
    const reserved = Object.values(slot.reservationCounts).reduce(
      (sum, value) => sum + (Number.isInteger(value) ? value : 0),
      0,
    );
    if (reserved !== bookedCount) {
      findings.slotsWithReservationMismatch.push(slotId);
    }
  }
}

for (const [appointmentId, appointment] of appointments) {
  const patient = patients.get(appointment.patientId);
  const doctor = doctors.get(appointment.doctorId);
  const schedule = schedules.get(appointment.workScheduleId);
  const slot = slots.get(appointment.timeSlotId);
  if (!patient || !doctor || !schedule || !slot) {
    findings.appointmentsWithInvalidReferences.push(appointmentId);
    continue;
  }
  if (
    schedule.doctorId !== appointment.doctorId ||
    slot.doctorId !== appointment.doctorId ||
    slot.workScheduleId !== appointment.workScheduleId
  ) {
    findings.appointmentsWithScheduleMismatch.push(appointmentId);
  }
}

const validPaymentStatuses = new Set([
  'PENDING',
  'SUCCESS',
  // Existing records and the client both use these as successful aliases.
  'PAID',
  'COMPLETED',
  'FAILED',
  'FAIL',
  'REFUNDED',
  'CANCELLED',
  'CANCELED',
]);
const successfulPaymentStatuses = new Set(['SUCCESS', 'PAID', 'COMPLETED']);
for (const [paymentId, payment] of payments) {
  const patient = patients.get(payment.patientId);
  if (!patient) findings.paymentsWithInvalidPatient.push(paymentId);
  if (!Number.isInteger(payment.amount) || payment.amount <= 0) {
    findings.paymentsWithInvalidAmount.push(paymentId);
  }
  const status = stringValue(payment.status).toUpperCase();
  if (!validPaymentStatuses.has(status)) {
    findings.paymentsWithInvalidStatus.push(paymentId);
  }
  if (successfulPaymentStatuses.has(status) && !toDate(payment.paidAt)) {
    findings.successfulPaymentsWithoutPaidAt.push(paymentId);
  }
  const appointmentId = stringValue(payment.appointmentId);
  if (appointmentId !== '') {
    const appointment = appointments.get(appointmentId);
    if (!appointment) {
      findings.paymentsWithInvalidAppointment.push(paymentId);
    } else if (appointment.patientId !== payment.patientId) {
      findings.paymentsWithPatientMismatch.push(paymentId);
    }
  }
}

for (const [notificationId, notification] of notifications) {
  if (!patients.has(notification.patientId)) {
    findings.notificationsWithInvalidPatient.push(notificationId);
  }
  if (
    notification.appointmentId &&
    !appointments.has(notification.appointmentId)
  ) {
    findings.notificationsWithInvalidAppointment.push(notificationId);
  }
}

const activeScheduleByDoctorAndDate = new Map();
for (const [scheduleId, schedule] of schedules) {
  const date = toDate(schedule.workDate);
  if (!date || schedule.status !== 'ACTIVE') continue;
  activeScheduleByDoctorAndDate.set(
    `${schedule.doctorId}|${vietnamDateString(date)}`,
    scheduleId,
  );
}
const availableSlotsBySchedule = new Map();
for (const slot of slots.values()) {
  if (slot.status !== 'AVAILABLE') continue;
  const values = availableSlotsBySchedule.get(slot.workScheduleId) ?? [];
  values.push(slot);
  availableSlotsBySchedule.set(slot.workScheduleId, values);
}

const coverage = [];
for (const [specialtyId, specialty] of specialties) {
  if (!isActive(specialty)) continue;
  const specialtyDoctors = [...activeDoctors.entries()]
      .filter(([, doctor]) => doctor.specialtyId === specialtyId)
      .map(([doctorId]) => doctorId);
  const perDay = Object.fromEntries(
    dates.map((date) => {
      const doctorCount = specialtyDoctors.filter((doctorId) => {
        const scheduleId = activeScheduleByDoctorAndDate.get(
          `${doctorId}|${date}`,
        );
        return scheduleId && (availableSlotsBySchedule.get(scheduleId)?.length ?? 0) > 0;
      }).length;
      return [date, doctorCount];
    }),
  );
  coverage.push({
    specialty: dataName(specialty, specialtyId),
    activeDoctors: specialtyDoctors.length,
    doctorsWithSlotsByDay: perDay,
  });
}

const findingRows = Object.entries(findings).map(([item, ids]) => ({
  item,
  count: ids.length,
  examples: ids.slice(0, 3).join(', ') || '-',
}));
console.table([
  { item: 'Project', value: projectId },
  { item: 'Audit dates (Asia/Ho_Chi_Minh)', value: `${dates[0]} → ${dates.at(-1)}` },
  { item: 'Active specialties', value: activeSpecialtyIds.size },
  { item: 'Active doctors', value: activeDoctors.size },
  { item: 'Patients', value: patients.size },
  { item: 'Accounts', value: accounts.size },
  { item: 'Work schedules', value: schedules.size },
  { item: 'Time slots', value: slots.size },
  { item: 'Appointments', value: appointments.size },
  { item: 'Payments', value: payments.size },
  { item: 'Notifications', value: notifications.size },
]);
console.table(findingRows);
console.log(JSON.stringify({ coverage }, null, 2));
if (strict && findingRows.some((row) => row.count > 0)) {
  process.exitCode = 2;
}

function argumentValue(name) {
  const argument = process.argv
      .slice(2)
      .find((value) => value.startsWith(`${name}=`));
  return argument?.slice(name.length + 1).trim() ?? '';
}

function documentMap(snapshot) {
  return new Map(snapshot.docs.map((document) => [document.id, document.data()]));
}

async function readCollectionInPages(collectionName, pageSize = 250) {
  const documents = [];
  let lastDocument;
  do {
    let query = firestore
        .collection(collectionName)
        .orderBy(FieldPath.documentId())
        .limit(pageSize);
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    documents.push(...page.docs);
    lastDocument = page.docs.at(-1);
    if (page.docs.length < pageSize) break;
  } while (lastDocument);
  return documents;
}

function isActive(value) {
  const status = stringValue(value.status).toUpperCase();
  return value.isActive !== false &&
      !new Set(['INACTIVE', 'DISABLED', 'FALSE', '0']).has(status);
}

function stringValue(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function dataName(data, fallback) {
  const value = data.name ?? data.TenChuyenKhoa;
  return typeof value === 'string' && value.trim().length > 0
      ? value.trim()
      : fallback;
}

function toDate(value) {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function addVietnamDays(date, offset) {
  const value = new Date(`${date}T00:00:00+07:00`);
  value.setUTCDate(value.getUTCDate() + offset);
  return vietnamDateString(value);
}

function vietnamDateString(value) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const values = Object.fromEntries(
    parts
        .filter((part) => ['year', 'month', 'day'].includes(part.type))
        .map((part) => [part.type, part.value]),
  );
  return `${values.year}-${values.month}-${values.day}`;
}
