import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const PROJECT_ID = 'bookinghospitalapp';
const SOURCE = 'TEST_CLINICAL_TIMELINE_2026';
const APPLY = process.argv.includes('--apply');
const PATIENT_EMAIL = argumentValue('--patient-email') || 'vanne@gmail.com';
const DOCTOR_EMAIL = argumentValue('--doctor-email') || 'viet3@gmail.com';
const SERVICE_ACCOUNT_PATH =
  process.env.FIREBASE_SERVICE_ACCOUNT_PATH || argumentValue('--service-account');

if (!SERVICE_ACCOUNT_PATH) {
  throw new Error(
    'Set FIREBASE_SERVICE_ACCOUNT_PATH or pass --service-account=<path>.',
  );
}

const serviceAccount = JSON.parse(
  await readFile(resolve(SERVICE_ACCOUNT_PATH), 'utf8'),
);
if (serviceAccount.project_id !== PROJECT_ID) {
  throw new Error(
    `The service account is for ${serviceAccount.project_id}, not ${PROJECT_ID}.`,
  );
}
if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount), projectId: PROJECT_ID });
}

const firestore = getFirestore();
const patient = await findPatient(PATIENT_EMAIL);
const doctor = await findDoctor(DOCTOR_EMAIL);
const doctorData = doctor.data();
if (doctorData.isActive === false || doctorData.status === 'INACTIVE') {
  throw new Error(`Doctor ${DOCTOR_EMAIL} is not active.`);
}

const specialtyId = String(doctorData.specialtyId ?? '').trim();
if (!specialtyId) {
  throw new Error(`Doctor ${DOCTOR_EMAIL} has no specialtyId.`);
}

const now = Timestamp.now();
const visitDates = [
  '2026-09-08',
  '2026-09-15',
  '2026-09-22',
  '2026-09-29',
  '2026-10-06',
  '2026-10-13',
];
const upcomingDates = ['2026-10-26', '2026-10-27'];
const records = [];

for (const date of visitDates) {
  records.push(...completedVisit({ date, patientId: patient.id, doctorId: doctor.id }));
}
for (const date of upcomingDates) {
  records.push(...upcomingAppointment({ date, patientId: patient.id, doctorId: doctor.id }));
}

// A result is deliberately limited to two past visits. Its wording makes clear
// that this is test data, not an actual clinical conclusion for the account.
for (const date of ['2026-09-22', '2026-10-13']) {
  records.push(...testResult({ date, patientId: patient.id, doctorId: doctor.id }));
}

await ensureSafeToWrite(records);
if (APPLY) {
  const batch = firestore.batch();
  for (const { collection, id, data } of records) {
    batch.set(firestore.collection(collection).doc(id), data, { merge: false });
  }
  await batch.commit();
}

const byCollection = Object.entries(
  records.reduce((counts, record) => {
    counts[record.collection] = (counts[record.collection] ?? 0) + 1;
    return counts;
  }, {}),
).map(([collection, count]) => ({ collection, count }));

console.table([
  { item: 'Patient profile', value: patient.id },
  { item: 'Doctor profile', value: doctor.id },
  { item: 'Historical completed visits', value: visitDates.length },
  { item: 'Upcoming appointments only', value: upcomingDates.length },
  { item: 'Synthetic test results', value: 2 },
  { item: 'Documents prepared', value: records.length },
]);
console.table(byCollection);
console.log(
  APPLY
    ? 'Clinical timeline test data was written successfully.'
    : 'Dry run completed. Add --apply to write the validated test data.',
);

async function findPatient(email) {
  const accountSnapshot = await firestore
    .collection('TAI_KHOAN')
    .where('email', '==', email.trim().toLowerCase())
    .limit(2)
    .get();
  if (accountSnapshot.size !== 1) {
    throw new Error(`Expected exactly one TAI_KHOAN account for ${email}.`);
  }
  const account = accountSnapshot.docs[0];
  const profiles = await firestore
    .collection('BENH_NHAN')
    .where('authUserId', '==', account.id)
    .limit(2)
    .get();
  if (profiles.size > 1) {
    throw new Error(`More than one BENH_NHAN profile is linked to ${email}.`);
  }
  const patient = profiles.docs[0] ?? await firestore.collection('BENH_NHAN').doc(account.id).get();
  if (!patient.exists) {
    throw new Error(`No BENH_NHAN profile was found for ${email}.`);
  }
  return patient;
}

async function findDoctor(email) {
  const doctors = await firestore
    .collection('BAC_SI')
    .where('email', '==', email.trim().toLowerCase())
    .limit(2)
    .get();
  if (doctors.size === 1) return doctors.docs[0];
  if (doctors.size > 1) {
    throw new Error(`More than one BAC_SI profile is linked to ${email}.`);
  }

  const fixture = await firestore.collection('BAC_SI').doc('test_doctor_viet3').get();
  if (fixture.exists && String(fixture.data().email ?? '').toLowerCase() === email.toLowerCase()) {
    return fixture;
  }
  throw new Error(`No BAC_SI profile was found for ${email}.`);
}

function completedVisit({ date, patientId, doctorId }) {
  const key = date.replaceAll('-', '');
  const scheduleId = `timeline_viet3_${date}`;
  const slotId = `${scheduleId}_0900`;
  const appointmentId = `timeline_vanne_viet3_${key}`;
  const appointmentAt = at(date, '09:00');

  return [
    doc('LICH_LAM_VIEC', scheduleId, schedule({ date, doctorId })),
    doc('CA_KHAM', slotId, slot({ scheduleId, slotId, doctorId, appointmentId })),
    doc('LICH_HEN', appointmentId, appointment({
      date,
      patientId,
      doctorId,
      scheduleId,
      slotId,
      status: 'COMPLETED',
      appointmentAt,
    })),
    doc('HO_SO_SUC_KHOE', `timeline_record_${appointmentId}`, {
      patientId,
      doctorId,
      recordDate: appointmentAt,
      diagnosis: 'Khám sức khỏe định kỳ (dữ liệu kiểm thử)',
      notes: 'Dữ liệu mô phỏng phục vụ kiểm thử, không dùng để chẩn đoán hoặc điều trị.',
      prescription: null,
      attachments: [],
      recordType: 'CHECKUP',
      source: SOURCE,
      isTestData: true,
      createdAt: now,
      updatedAt: now,
    }),
    doc('THANH_TOAN', `timeline_payment_${appointmentId}`, {
      patientId,
      appointmentId,
      amount: 150000,
      paymentMethod: 'BANK_TRANSFER',
      status: 'SUCCESS',
      transactionCode: `TT-TIMELINE-${key}`,
      isTestData: true,
      source: SOURCE,
      createdAt: appointmentAt,
      updatedAt: now,
      paidAt: at(date, '10:00'),
    }),
  ];
}

function upcomingAppointment({ date, patientId, doctorId }) {
  const key = date.replaceAll('-', '');
  const scheduleId = `timeline_viet3_${date}`;
  const slotId = `${scheduleId}_0900`;
  const appointmentId = `timeline_vanne_viet3_${key}`;
  return [
    doc('LICH_LAM_VIEC', scheduleId, schedule({ date, doctorId })),
    doc('CA_KHAM', slotId, slot({ scheduleId, slotId, doctorId, appointmentId })),
    doc('LICH_HEN', appointmentId, appointment({
      date,
      patientId,
      doctorId,
      scheduleId,
      slotId,
      status: 'CONFIRMED',
      appointmentAt: at(date, '09:00'),
    })),
  ];
}

function testResult({ date, patientId, doctorId }) {
  const key = date.replaceAll('-', '');
  return [
    doc('KET_QUA_CLS', `timeline_result_${key}`, {
      patientId,
      doctorId,
      doctorName: 'Bác sĩ Việt (tài khoản kiểm thử)',
      testDate: at(date, '10:00'),
      resultType: 'Xét nghiệm',
      testName: 'Phiếu theo dõi sau khám (dữ liệu kiểm thử)',
      resultDescription: 'Dữ liệu mô phỏng phục vụ kiểm thử giao diện; không phải kết quả y tế.',
      referenceRange: 'Không áp dụng cho dữ liệu kiểm thử.',
      conclusion: 'Không sử dụng để chẩn đoán hoặc điều trị.',
      status: 'FINAL',
      source: SOURCE,
      isTestData: true,
      createdAt: now,
      updatedAt: now,
    }),
  ];
}

function schedule({ date, doctorId }) {
  return {
    doctorId,
    workDate: at(date, '00:00'),
    startTime: '08:00',
    endTime: '12:00',
    status: 'ACTIVE',
    source: SOURCE,
    isTestData: true,
    createdAt: now,
    updatedAt: now,
  };
}

function slot({ scheduleId, slotId, doctorId, appointmentId }) {
  return {
    id: slotId,
    workScheduleId: scheduleId,
    doctorId,
    startTime: '09:00',
    endTime: '09:30',
    capacity: 1,
    bookedCount: 1,
    appointmentId,
    reservationCounts: { [appointmentId]: 1 },
    status: 'BOOKED',
    source: SOURCE,
    isTestData: true,
    createdAt: now,
    updatedAt: now,
  };
}

function appointment({
  date,
  patientId,
  doctorId,
  scheduleId,
  slotId,
  status,
  appointmentAt,
}) {
  return {
    patientId,
    doctorId,
    workScheduleId: scheduleId,
    timeSlotId: slotId,
    specialtyId,
    appointmentDate: appointmentAt,
    startTime: '09:00',
    endTime: '09:30',
    bookedAt: at(date, '08:30'),
    status,
    reason: 'Khám theo dõi định kỳ (dữ liệu kiểm thử)',
    symptoms: 'Không áp dụng — dữ liệu kiểm thử.',
    peopleCount: 1,
    queueNumber: 1,
    ...(status === 'COMPLETED' ? { checkInTime: at(date, '08:55') } : {}),
    source: SOURCE,
    isTestData: true,
    createdAt: now,
    updatedAt: now,
  };
}

function doc(collection, id, data) {
  return { collection, id, data };
}

function at(date, time) {
  return Timestamp.fromDate(new Date(`${date}T${time}:00+07:00`));
}

async function ensureSafeToWrite(recordsToCheck) {
  const references = recordsToCheck.map(({ collection, id }) =>
    firestore.collection(collection).doc(id),
  );
  const existing = await firestore.getAll(...references);
  const conflicts = existing.filter((document) =>
    document.exists && document.data().source !== SOURCE,
  );
  if (conflicts.length > 0) {
    const targets = conflicts.map((document) => document.ref.path).join(', ');
    throw new Error(`Refusing to overwrite non-test documents: ${targets}`);
  }
}

function argumentValue(name) {
  const value = process.argv.find((argument) => argument.startsWith(`${name}=`));
  return value?.slice(name.length + 1).trim() ?? '';
}
