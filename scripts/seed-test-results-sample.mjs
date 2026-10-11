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
const patient = patientMatches.size === 1
    ? patientMatches.docs[0]
    : await firestore.collection('BENH_NHAN').doc(account.id).get();
if (!patient.exists) {
  throw new Error(`No BENH_NHAN profile was found for ${email}.`);
}

const doctor = await activeDoctor(firestore);
const now = Timestamp.fromDate(new Date());
const doctorName = displayName(doctor.data());
const results = [
  sampleResult('blood_count', '2026-10-10T09:30:00+07:00', {
    resultType: 'Xét nghiệm',
    testName: 'Công thức máu toàn bộ',
    resultDescription: 'Hồng cầu, bạch cầu và tiểu cầu trong giới hạn tham chiếu.',
    referenceRange: 'Theo ngưỡng tham chiếu của phòng xét nghiệm.',
    conclusion: 'Chưa ghi nhận bất thường huyết học.',
  }),
  sampleResult('blood_glucose', '2026-10-08T08:45:00+07:00', {
    resultType: 'Xét nghiệm',
    testName: 'Đường huyết lúc đói',
    resultDescription: '5.1 mmol/L.',
    referenceRange: '3.9 - 5.6 mmol/L.',
    conclusion: 'Đường huyết trong giới hạn bình thường.',
  }),
  sampleResult('echo', '2026-10-06T10:00:00+07:00', {
    resultType: 'Siêu âm',
    testName: 'Siêu âm tim Doppler màu',
    resultDescription: 'Chức năng co bóp thất trái bảo tồn, không ghi nhận tràn dịch màng tim.',
    conclusion: 'Theo dõi huyết áp và tái khám theo hẹn.',
  }),
  sampleResult('chest_xray', '2026-09-28T14:15:00+07:00', {
    resultType: 'X Quang',
    testName: 'X Quang ngực thẳng',
    resultDescription: 'Nhu mô phổi thông khí tốt, bóng tim không to.',
    conclusion: 'Chưa thấy tổn thương phổi cấp trên phim.',
  }),
];
const resultNotifications = results.map((result) => ({
  id: `result_available_${result.id}`,
  data: {
    patientId: patient.id,
    resultId: result.id,
    title: 'Có kết quả cận lâm sàng mới',
    content:
      `Kết quả ${result.data.testName} đã có. ` +
      'Bạn có thể xem chi tiết trong mục Kết quả cận lâm sàng.',
    isRead: false,
    createdAt: now,
    source: 'TEST_RESULT',
  },
}));

if (apply) {
  const batch = firestore.batch();
  for (const result of results) {
    batch.set(
      firestore.collection('KET_QUA_CLS').doc(result.id),
      result.data,
      { merge: true },
    );
  }
  for (const notification of resultNotifications) {
    batch.set(
      firestore.collection('notifications').doc(notification.id),
      notification.data,
      { merge: true },
    );
  }
  await batch.commit();
}

console.table([
  { item: 'Project', value: projectId },
  { item: 'Patient profile', value: patient.id },
  { item: 'Sample results', value: results.length },
  { item: 'Result notifications', value: resultNotifications.length },
  { item: 'Doctor', value: doctorName },
  { item: 'Collection', value: 'KET_QUA_CLS' },
]);
console.log(
  apply
      ? 'Sample test results were added or updated.'
      : 'Dry run completed. Add --apply to write sample test results.',
);

function sampleResult(key, resultDate, details) {
  return {
    id: `test_result_${key}_${patient.id}`,
    data: {
      patientId: patient.id,
      doctorId: doctor.id,
      doctorName,
      testDate: Timestamp.fromDate(new Date(resultDate)),
      source: 'TEST_RESULT',
      status: 'FINAL',
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

  throw new Error('No active BAC_SI doctor is available for the sample result.');
}

function displayName(data = {}) {
  return data.fullName ?? data.TenBacSi ?? data.name ?? 'Bác sĩ phụ trách';
}

function argumentValue(name) {
  const argument = process.argv.slice(2).find((value) =>
    value.startsWith(`${name}=`),
  );
  return argument?.slice(name.length + 1).trim() ?? '';
}
