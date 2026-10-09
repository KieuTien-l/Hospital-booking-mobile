import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
const requestedDate = process.argv
    .slice(2)
    .find((argument) => argument.startsWith('--date='))
    ?.replace('--date=', '');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

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

const date = requestedDate ?? nextVietnamDate();
if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
  throw new Error('Use --date=YYYY-MM-DD.');
}

const firestore = getFirestore();
const [doctorsSnapshot, schedulesSnapshot, slotsSnapshot] = await Promise.all([
  firestore.collection('BAC_SI').get(),
  firestore.collection('LICH_LAM_VIEC').get(),
  firestore.collection('CA_KHAM').get(),
]);
const activeDoctors = doctorsSnapshot.docs.filter((document) => {
  const data = document.data();
  return data.isActive !== false && data.status !== 'INACTIVE';
});
const schedulesByDoctorId = new Map();

for (const document of schedulesSnapshot.docs) {
  const data = document.data();
  if (data.doctorId && isSameVietnamDate(data.workDate, date)) {
    schedulesByDoctorId.set(data.doctorId, document.id);
  }
}

const existingSlotKeys = new Set(
  slotsSnapshot.docs.map((document) => {
    const data = document.data();
    return `${data.workScheduleId}|${data.startTime}`;
  }),
);
const pendingSchedules = [];
const pendingSlots = [];
const scheduleDate = Timestamp.fromDate(new Date(`${date}T00:00:00+07:00`));

for (const doctor of activeDoctors) {
  const doctorId = doctor.id;
  const scheduleId =
      schedulesByDoctorId.get(doctorId) ?? `seed_${date}_${doctorId}`;

  if (!schedulesByDoctorId.has(doctorId)) {
    pendingSchedules.push({
      reference: firestore.collection('LICH_LAM_VIEC').doc(scheduleId),
      data: {
        doctorId,
        workDate: scheduleDate,
        startTime: '08:00',
        endTime: '12:00',
        status: 'ACTIVE',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }

  for (const [startTime, endTime] of timeRanges()) {
    const slotKey = `${scheduleId}|${startTime}`;
    if (existingSlotKeys.has(slotKey)) continue;
    pendingSlots.push({
      reference: firestore
          .collection('CA_KHAM')
          .doc(`seed_${date}_${doctorId}_${startTime.replace(':', '')}`),
      data: {
        workScheduleId: scheduleId,
        doctorId,
        startTime,
        endTime,
        bookedCount: 0,
        capacity: 5,
        reservationCounts: {},
        status: 'AVAILABLE',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }
}

if (apply) {
  await createInBatches([...pendingSchedules, ...pendingSlots]);
}

console.table([
  { item: 'Seed date (Asia/Ho_Chi_Minh)', count: date },
  { item: 'Active doctors scanned', count: activeDoctors.length },
  { item: 'Work schedules to create', count: pendingSchedules.length },
  { item: 'Time slots to create', count: pendingSlots.length },
]);
console.log(
  apply
    ? 'Booking sample data completed. Existing schedules and slots were preserved.'
    : 'Dry run completed. No Firestore document was changed. Run again with --apply to create the sample data.',
);

function nextVietnamDate() {
  const nextDate = new Date(`${vietnamDateString(new Date())}T00:00:00+07:00`);
  nextDate.setUTCDate(nextDate.getUTCDate() + 1);
  return vietnamDateString(nextDate);
}

function isSameVietnamDate(value, date) {
  if (value instanceof Timestamp) {
    return vietnamDateString(value.toDate()) === date;
  }
  if (value instanceof Date) {
    return vietnamDateString(value) === date;
  }
  if (typeof value === 'string') return value.slice(0, 10) === date;
  return false;
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

function timeRanges() {
  return [
    ['08:00', '08:30'],
    ['08:30', '09:00'],
    ['09:00', '09:30'],
    ['09:30', '10:00'],
    ['10:00', '10:30'],
    ['10:30', '11:00'],
    ['11:00', '11:30'],
    ['11:30', '12:00'],
  ];
}

async function createInBatches(documents) {
  const batchSize = 400;
  for (let start = 0; start < documents.length; start += batchSize) {
    const batch = firestore.batch();
    for (const { reference, data } of documents.slice(start, start + batchSize)) {
      batch.create(reference, data);
    }
    await batch.commit();
  }
}
