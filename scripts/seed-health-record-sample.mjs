import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
const email = argumentValue('--email').toLowerCase();
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!email || !email.includes('@')) {
  throw new Error('Use --email=<patient account email>.');
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
const accountMatches = await firestore
    .collection('TAI_KHOAN')
    .where('email', '==', email)
    .limit(2)
    .get();
if (accountMatches.size !== 1) {
  throw new Error(
    `Expected exactly one TAI_KHOAN account for ${email}; found ${accountMatches.size}.`,
  );
}

const account = accountMatches.docs[0];
const patientMatches = await firestore
    .collection('BENH_NHAN')
    .where('authUserId', '==', account.id)
    .limit(2)
    .get();
if (patientMatches.size > 1) {
  throw new Error(
    `Expected at most one BENH_NHAN profile for ${email}; found ${patientMatches.size}.`,
  );
}
const patient = patientMatches.size === 1
    ? patientMatches.docs[0]
    : await firestore.collection('BENH_NHAN').doc(account.id).get();
if (!patient.exists) {
  throw new Error(`No BENH_NHAN profile was found for ${email}.`);
}

const doctor = await activeDoctor(firestore);
const now = Timestamp.fromDate(new Date());
const records = [
  sampleRecord('test_health_record', '2026-10-10T09:30:00+07:00', {
    diagnosis: 'Tăng huyết áp cần theo dõi',
    prescription: 'Amlodipine 5mg, uống 1 viên mỗi ngày sau ăn sáng.',
    notes: 'Theo dõi huyết áp tại nhà và tái khám sau 30 ngày.',
    recordType: 'OUTPATIENT',
    documentCategory: 'PRESCRIPTION',
  }),
  sampleRecord('test_health_record_order', '2026-10-05T14:00:00+07:00', {
    diagnosis: 'Rối loạn mỡ máu, cần xét nghiệm theo dõi',
    notes: 'Đã chỉ định xét nghiệm mỡ máu và chức năng gan.',
    attachments: ['phieu-chi-dinh-xet-nghiem-mo-mau.pdf'],
    recordType: 'OUTPATIENT',
    documentCategory: 'ORDER',
  }),
  sampleRecord('test_health_record_inpatient', '2026-09-25T08:30:00+07:00', {
    diagnosis: 'Theo dõi sau nhập viện do tăng huyết áp',
    prescription: 'Amlodipine 5mg, uống 1 viên mỗi ngày sau ăn sáng.',
    notes: 'Huyết áp ổn định. Tiếp tục dùng thuốc và tái khám đúng hẹn.',
    recordType: 'INPATIENT',
  }),
  sampleRecord('test_health_record_checkup', '2026-09-12T08:00:00+07:00', {
    diagnosis: 'Khám sức khỏe định kỳ',
    notes: 'Các chỉ số cơ bản trong giới hạn cho phép.',
    attachments: ['giay-chung-nhan-suc-khoe.pdf'],
    recordType: 'CHECKUP',
    documentCategory: 'CERTIFICATE',
  }),
];

if (apply) {
  const batch = firestore.batch();
  for (const record of records) {
    batch.set(
      firestore.collection('HO_SO_SUC_KHOE').doc(record.id),
      record.data,
      { merge: true },
    );
  }
  await batch.commit();
}

console.table([
  { item: 'Project', value: projectId },
  { item: 'Patient profile found', value: patient.exists ? 'yes' : 'no' },
  { item: 'Sample records', value: records.length },
  { item: 'Doctor found', value: doctor.exists ? 'yes' : 'no' },
  { item: 'Collection', value: 'HO_SO_SUC_KHOE' },
]);
console.log(
  apply
      ? 'Sample Health Records were added or updated.'
      : 'Dry run completed. Add --apply to write the sample Health Records.',
);

function sampleRecord(idPrefix, recordDate, details) {
  return {
    id: `${idPrefix}_${patient.id}`,
    data: {
      patientId: patient.id,
      doctorId: doctor.id,
      recordDate: Timestamp.fromDate(new Date(recordDate)),
      prescription: null,
      notes: null,
      attachments: [],
      source: 'TEST_HEALTH_RECORD',
      createdAt: now,
      updatedAt: now,
      ...details,
    },
  };
}

async function activeDoctor(database) {
  const preferred = await database
      .collection('BAC_SI')
      .doc('sample_bs_pham_ngoc_mai')
      .get();
  if (preferred.exists) return preferred;

  const byStatus = await database
      .collection('BAC_SI')
      .where('status', '==', 'ACTIVE')
      .limit(1)
      .get();
  if (!byStatus.empty) return byStatus.docs[0];

  const byFlag = await database
      .collection('BAC_SI')
      .where('isActive', '==', true)
      .limit(1)
      .get();
  if (!byFlag.empty) return byFlag.docs[0];

  throw new Error('No active BAC_SI doctor is available for the sample record.');
}

function argumentValue(name) {
  const argument = process.argv.slice(2).find((value) =>
    value.startsWith(`${name}=`),
  );
  return argument?.slice(name.length + 1).trim() ?? '';
}
