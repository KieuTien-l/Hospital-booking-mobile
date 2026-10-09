import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
const startDate = argumentValue('--start-date') ?? '2026-10-20';
const days = Number(argumentValue('--days') ?? '7');
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
const [specialtiesSnapshot, doctorsSnapshot, schedulesSnapshot, slotsSnapshot] =
  await Promise.all([
    firestore.collection('CHUYEN_KHOA').get(),
    firestore.collection('BAC_SI').get(),
    firestore.collection('LICH_LAM_VIEC').get(),
    firestore.collection('CA_KHAM').get(),
  ]);

const activeSpecialties = new Map(
  specialtiesSnapshot.docs
      .filter((document) => {
        const data = document.data();
        return data.isActive !== false && data.status !== 'INACTIVE';
      })
      .map((document) => [
        document.id,
        dataName(document.data(), document.id),
      ]),
);

const doctorsBySpecialty = new Map(
  [...activeSpecialties.keys()].map((specialtyId) => [specialtyId, []]),
);
for (const document of doctorsSnapshot.docs) {
  const data = document.data();
  if (
    activeSpecialties.has(data.specialtyId) &&
    data.isActive !== false &&
    data.status !== 'INACTIVE'
  ) {
    doctorsBySpecialty.get(data.specialtyId).push(document);
  }
}

// Prefer real doctors. A legacy mock doctor is used only when its specialty
// has no real doctor, and a labelled sample doctor is created only when a
// specialty has no doctor at all. This keeps every active specialty bookable.
const doctors = [];
const pendingDoctors = [];
for (const [specialtyId, specialtyName] of activeSpecialties) {
  const candidates = doctorsBySpecialty.get(specialtyId) ?? [];
  const realDoctors = candidates.filter(
    (document) =>
      !document.id.startsWith('mock_') && !document.id.startsWith('sample_'),
  );
  if (realDoctors.length > 0) {
    doctors.push(...realDoctors);
    continue;
  }
  if (candidates.length > 0) {
    doctors.push(...candidates);
    continue;
  }

  const doctorId = `seed_range_doctor_${specialtyId}`;
  doctors.push({ id: doctorId });
  pendingDoctors.push({
    reference: firestore.collection('BAC_SI').doc(doctorId),
    data: {
      userId: `seed_range_user_${specialtyId}`,
      fullName: `Bác sĩ ${specialtyName} (mẫu)`,
      email: `${doctorId}@sample.local`,
      phone: '',
      specialtyId,
      specialtyName,
      qualification: 'Bác sĩ',
      yearsOfExperience: 5,
      consultationFee: 150000,
      isActive: true,
      status: 'ACTIVE',
      source: 'SEED_MULTISPECIALTY_BOOKING',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  });
}
if (doctors.length === 0) {
  throw new Error('No doctors were found for active specialties.');
}

const dates = Array.from({ length: days }, (_, index) =>
  addVietnamDays(startDate, index),
);
const activeScheduleByDoctorDate = new Map();
for (const document of schedulesSnapshot.docs) {
  const data = document.data();
  if (
    typeof data.doctorId === 'string' &&
    data.status === 'ACTIVE' &&
    typeof data.workDate !== 'undefined'
  ) {
    const date = vietnamDateString(data.workDate.toDate?.() ?? data.workDate);
    activeScheduleByDoctorDate.set(`${data.doctorId}|${date}`, document.id);
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

for (const doctor of doctors) {
  for (const date of dates) {
    const scheduleKey = `${doctor.id}|${date}`;
    const scheduleId =
      activeScheduleByDoctorDate.get(scheduleKey) ??
      `seed_range_${date}_${doctor.id}`;

    if (!activeScheduleByDoctorDate.has(scheduleKey)) {
      pendingSchedules.push({
        reference: firestore.collection('LICH_LAM_VIEC').doc(scheduleId),
        data: {
          doctorId: doctor.id,
          workDate: Timestamp.fromDate(new Date(`${date}T00:00:00+07:00`)),
          startTime: '08:00',
          endTime: '12:00',
          status: 'ACTIVE',
          source: 'SEED_MULTISPECIALTY_BOOKING',
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
            .doc(`seed_range_${date}_${doctor.id}_${startTime.replace(':', '')}`),
        data: {
          workScheduleId: scheduleId,
          doctorId: doctor.id,
          startTime,
          endTime,
          bookedCount: 0,
          capacity: 5,
          reservationCounts: {},
          status: 'AVAILABLE',
          source: 'SEED_MULTISPECIALTY_BOOKING',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
    }
  }
}

if (apply) {
  await createInBatches([
    ...pendingDoctors,
    ...pendingSchedules,
    ...pendingSlots,
  ]);
}

console.table([
  { item: 'Project', value: projectId },
  { item: 'Dates (Asia/Ho_Chi_Minh)', value: `${dates[0]} → ${dates.at(-1)}` },
  { item: 'Active specialties', value: activeSpecialties.size },
  { item: 'Doctors seeded', value: doctors.length },
  { item: 'Doctors to create', value: pendingDoctors.length },
  { item: 'Work schedules to create', value: pendingSchedules.length },
  { item: 'Available slots to create', value: pendingSlots.length },
]);
console.log(
  apply
    ? 'Multi-specialty booking data was added. Existing schedules and slots were preserved.'
    : 'Dry run completed. Add --apply to write the booking data.',
);

function argumentValue(name) {
  const argument = process.argv
      .slice(2)
      .find((value) => value.startsWith(`${name}=`));
  return argument?.slice(name.length + 1).trim() ?? '';
}

function dataName(data, fallback) {
  const value = data.name ?? data.TenChuyenKhoa;
  return typeof value === 'string' && value.trim().length > 0
      ? value.trim()
      : fallback;
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
