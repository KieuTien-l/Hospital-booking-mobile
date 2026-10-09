import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
const patientId = argumentValue('--patient-id');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!patientId) {
  throw new Error('Use --patient-id=<BENH_NHAN document id>.');
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
const patient = await firestore.collection('BENH_NHAN').doc(patientId).get();
if (!patient.exists) {
  throw new Error(`Patient ${patientId} does not exist.`);
}

const now = new Date();
const notifications = [
  {
    id: `test_booking_${patientId}`,
    title: 'Đặt lịch thành công',
    content:
      'Đây là thông báo kiểm thử. Lịch hẹn của bạn đã được ghi nhận.',
    isRead: false,
    createdAt: Timestamp.fromDate(now),
  },
  {
    id: `test_reminder_${patientId}`,
    title: 'Nhắc lịch khám',
    content:
      'Đây là thông báo kiểm thử. Vui lòng đến đúng giờ theo lịch hẹn của bạn.',
    isRead: true,
    createdAt: Timestamp.fromDate(new Date(now.getTime() - 5 * 60 * 1000)),
  },
];

if (apply) {
  const batch = firestore.batch();
  for (const notification of notifications) {
    batch.set(
      firestore.collection('notifications').doc(notification.id),
      {
        patientId,
        title: notification.title,
        content: notification.content,
        isRead: notification.isRead,
        createdAt: notification.createdAt,
        source: 'TEST_NOTIFICATION',
      },
      { merge: true },
    );
  }
  await batch.commit();
}

console.table([
  { item: 'Project', value: projectId },
  { item: 'Patient', value: patientId },
  { item: 'Collection', value: 'notifications' },
  { item: 'Test notifications', value: notifications.length },
  { item: 'Unread notifications', value: 1 },
]);
console.log(
  apply
    ? 'Test notifications were added or updated.'
    : 'Dry run completed. Add --apply to write the test notifications.',
);

function argumentValue(name) {
  const argument = process.argv.slice(2).find((value) =>
    value.startsWith(`${name}=`),
  );
  return argument?.slice(name.length + 1).trim() ?? '';
}
