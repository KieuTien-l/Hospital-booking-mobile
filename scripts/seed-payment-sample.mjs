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

const appointmentSnapshot = await firestore
  .collection('LICH_HEN')
  .where('patientId', '==', patient.id)
  .limit(10)
  .get();
if (appointmentSnapshot.empty) {
  throw new Error(
    `No LICH_HEN record was found for ${email}; create a booking before adding payment test data.`,
  );
}

const samplePayments = paymentSamples(patient.id, appointmentSnapshot.docs.map((doc) => doc.id));
const paymentNotifications = samplePayments.map(paymentNotification);
if (apply) {
  const batch = firestore.batch();
  for (const payment of samplePayments) {
    batch.set(
      firestore.collection('THANH_TOAN').doc(payment.id),
      payment.data,
      { merge: true },
    );
  }
  for (const notification of paymentNotifications) {
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
  { item: 'Patient email', value: email },
  { item: 'Linked appointments', value: appointmentSnapshot.size },
  { item: 'Test payment records', value: samplePayments.length },
  { item: 'Payment notifications', value: paymentNotifications.length },
  { item: 'Collection', value: 'THANH_TOAN' },
]);
console.log(
  apply
    ? 'Payment test data was added or updated. Records are marked isTestData=true.'
    : 'Dry run completed. Add --apply to write payment test data.',
);

function paymentSamples(patientId, appointmentIds) {
  const now = new Date();
  const at = (daysAgo, hour) => {
    const date = new Date(now);
    date.setDate(date.getDate() - daysAgo);
    date.setHours(hour, 30, 0, 0);
    return Timestamp.fromDate(date);
  };
  const templates = [
    {
      key: 'success',
      amount: 250000,
      paymentMethod: 'MOMO',
      status: 'SUCCESS',
      transactionCode: 'TT-TEST-001',
      paidAt: at(2, 9),
    },
    {
      key: 'pending',
      amount: 180000,
      paymentMethod: 'BANK_TRANSFER',
      status: 'PENDING',
      transactionCode: 'TT-TEST-002',
    },
    {
      key: 'failed',
      amount: 320000,
      paymentMethod: 'BANK_QR',
      status: 'FAILED',
      transactionCode: 'TT-TEST-003',
      paidAt: at(6, 14),
    },
  ];
  return templates.map((template, index) => ({
    id: `sample_payment_${template.key}_${patientId}`,
    data: {
      patientId,
      appointmentId: appointmentIds[index % appointmentIds.length],
      amount: template.amount,
      paymentMethod: template.paymentMethod,
      status: template.status,
      transactionCode: template.transactionCode,
      isTestData: true,
      createdAt: at(index + 1, 8),
      updatedAt: Timestamp.fromDate(now),
      ...(template.paidAt ? { paidAt: template.paidAt } : {}),
    },
  }));
}

function paymentNotification(payment) {
  const { amount, paymentMethod, status } = payment.data;
  const amountLabel = `${new Intl.NumberFormat('vi-VN').format(amount)}đ`;
  const methodLabel = paymentMethod.replaceAll('_', ' ');
  const messages = {
    SUCCESS: {
      title: 'Thanh toán thành công',
      content: `Bạn đã thanh toán ${amountLabel} qua ${methodLabel}.`,
    },
    PENDING: {
      title: 'Thanh toán đang chờ xử lý',
      content: `Khoản thanh toán ${amountLabel} qua ${methodLabel} đang được xử lý.`,
    },
    FAILED: {
      title: 'Thanh toán không thành công',
      content: `Khoản thanh toán ${amountLabel} qua ${methodLabel} chưa thành công. Vui lòng thử lại.`,
    },
  };
  const message = messages[status] ?? {
    title: 'Cập nhật thanh toán',
    content: `Khoản thanh toán ${amountLabel} có trạng thái ${status}.`,
  };
  return {
    id: `payment_${payment.id}`,
    data: {
      patientId: payment.data.patientId,
      paymentId: payment.id,
      appointmentId: payment.data.appointmentId,
      title: message.title,
      content: message.content,
      isRead: false,
      createdAt: payment.data.updatedAt,
      source: 'TEST_PAYMENT',
    },
  };
}

function argumentValue(name) {
  const argument = process.argv.slice(2).find((value) =>
    value.startsWith(`${name}=`),
  );
  return argument?.slice(name.length + 1).trim() ?? '';
}
