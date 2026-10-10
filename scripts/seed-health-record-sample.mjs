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
const recordId = `test_health_record_${patient.id}`;
const now = Timestamp.fromDate(new Date());
const recordDate = Timestamp.fromDate(new Date('2026-10-10T09:30:00+07:00'));
const record = {
  patientId: patient.id,
  doctorId: doctor.id,
  recordDate,
  diagnosis: 'Tăng huyết áp cần theo dõi',
  prescription: 'Amlodipine 5mg, uống 1 viên mỗi ngày sau ăn sáng.',
  notes: 'Theo dõi huyết áp tại nhà và tái khám sau 30 ngày.',
  attachments: [],
  source: 'TEST_HEALTH_RECORD',
  createdAt: now,
  updatedAt: now,
};

if (apply) {
  await firestore.collection('HO_SO_SUC_KHOE').doc(recordId).set(record, {
    merge: true,
  });
}

console.table([
  { item: 'Project', value: projectId },
  { item: 'Patient profile found', value: patient.exists ? 'yes' : 'no' },
  { item: 'Sample record', value: apply ? 'added or updated' : 'ready to add' },
  { item: 'Doctor found', value: doctor.exists ? 'yes' : 'no' },
  { item: 'Collection', value: 'HO_SO_SUC_KHOE' },
]);
console.log(
  apply
      ? 'One sample Health Record was added or updated.'
      : 'Dry run completed. Add --apply to write the sample Health Record.',
);

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
