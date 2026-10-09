import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
const date = argumentValue('--date') ?? '2027-09-16';
const specialtyId =
  argumentValue('--specialty-id') ?? '1ZxtGNs4VpqGymAFSDYU';
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
  throw new Error('Use --date=YYYY-MM-DD.');
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
const specialty = await firestore.collection('CHUYEN_KHOA').doc(specialtyId).get();
if (!specialty.exists) {
  throw new Error(
    `Specialty ${specialtyId} does not exist. Pass the correct ID with --specialty-id=...`,
  );
}

const source = `SAMPLE_CARDIOLOGY_${date.replaceAll('-', '_')}`;
const workDate = Timestamp.fromDate(new Date(`${date}T00:00:00+07:00`));
const doctors = [
  {
    id: 'sample_bs_pham_ngoc_mai',
    userId: 'sample_user_pham_ngoc_mai',
    fullName: 'Phạm Ngọc Mai',
    qualification: 'BS.CKII',
    yearsOfExperience: 14,
    consultationFee: 180000,
    slots: [
      ['08:00', '08:30'],
      ['08:30', '09:00'],
      ['09:00', '09:30'],
      ['09:30', '10:00'],
    ],
  },
  {
    id: 'sample_bs_nguyen_quoc_huy',
    userId: 'sample_user_nguyen_quoc_huy',
    fullName: 'Nguyễn Quốc Huy',
    qualification: 'ThS.BS',
    yearsOfExperience: 11,
    consultationFee: 160000,
    slots: [
      ['08:00', '08:30'],
      ['08:30', '09:00'],
      ['09:00', '09:30'],
      ['09:30', '10:00'],
    ],
  },
  {
    id: 'sample_bs_le_thu_ha',
    userId: 'sample_user_le_thu_ha',
    fullName: 'Lê Thu Hà',
    qualification: 'BS.CKI',
    yearsOfExperience: 9,
    consultationFee: 150000,
    slots: [
      ['13:00', '13:30'],
      ['13:30', '14:00'],
      ['14:00', '14:30'],
      ['14:30', '15:00'],
    ],
  },
];

const documents = [];
for (const doctor of doctors) {
  const scheduleId = `sample_llv_${date}_${doctor.id}`;
  documents.push({
    reference: firestore.collection('BAC_SI').doc(doctor.id),
    data: {
      userId: doctor.userId,
      fullName: doctor.fullName,
      email: `${doctor.id}@sample.local`,
      phone: '',
      specialtyId,
      specialtyName: 'Khoa Nội tim mạch',
      qualification: doctor.qualification,
      biography: 'Dữ liệu mẫu phục vụ kiểm thử luồng đặt lịch.',
      yearsOfExperience: doctor.yearsOfExperience,
      consultationFee: doctor.consultationFee,
      isActive: true,
      status: 'ACTIVE',
      source,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  });
  documents.push({
    reference: firestore.collection('LICH_LAM_VIEC').doc(scheduleId),
    data: {
      doctorId: doctor.id,
      workDate,
      startTime: doctor.slots[0][0],
      endTime: doctor.slots[doctor.slots.length - 1][1],
      status: 'ACTIVE',
      source,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  });
  for (const finalSlot of doctor.slots) {
    const [startTime, endTime] = finalSlot;
    documents.push({
      reference: firestore
          .collection('CA_KHAM')
          .doc(`sample_ca_${date}_${doctor.id}_${startTime.replace(':', '')}`),
      data: {
        workScheduleId: scheduleId,
        doctorId: doctor.id,
        startTime,
        endTime,
        bookedCount: 0,
        capacity: 5,
        reservationCounts: {},
        status: 'AVAILABLE',
        source,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }
}

if (apply) {
  const batch = firestore.batch();
  for (const { reference, data } of documents) {
    batch.set(reference, data, { merge: true });
  }
  await batch.commit();
}

console.table([
  { item: 'Project', value: projectId },
  { item: 'Specialty', value: specialtyId },
  { item: 'Date (Asia/Ho_Chi_Minh)', value: date },
  { item: 'Doctors', value: doctors.length },
  { item: 'Schedules', value: doctors.length },
  { item: 'Available slots', value: documents.length - doctors.length * 2 },
]);
console.log(
  apply
    ? 'Cardiology sample data was added or updated.'
    : 'Dry run only. Re-run with --apply to write the sample documents.',
);

function argumentValue(name) {
  return process.argv
      .slice(2)
      .find((argument) => argument.startsWith(`${name}=`))
      ?.slice(name.length + 1);
}
