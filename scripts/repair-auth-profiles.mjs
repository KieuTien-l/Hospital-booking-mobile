import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
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

const firestore = getFirestore();
const auth = getAuth();
const [users, accountSnapshot, patientSnapshot] = await Promise.all([
  listAllUsers(),
  firestore.collection('TAI_KHOAN').get(),
  firestore.collection('BENH_NHAN').get(),
]);

const accountIds = new Set(accountSnapshot.docs.map((document) => document.id));
const patientAuthUserIds = new Set(
  patientSnapshot.docs
      .map((document) => document.data().authUserId)
      .filter((value) => typeof value === 'string' && value.length > 0),
);
const pendingAccounts = [];
const pendingPatients = [];

for (const user of users) {
  if (accountIds.has(user.uid)) continue;

  const active = !user.disabled;
  const fullName = user.displayName?.trim() ?? '';
  const email = user.email?.trim() ?? '';
  const phone = user.phoneNumber?.trim() ?? '';

  pendingAccounts.push({
    reference: firestore.collection('TAI_KHOAN').doc(user.uid),
    data: {
      email,
      fullName,
      phone,
      role: 'patient',
      isActive: active,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  });

  if (!patientAuthUserIds.has(user.uid)) {
    pendingPatients.push({
      reference: firestore.collection('BENH_NHAN').doc(user.uid),
      data: {
        authUserId: user.uid,
        email,
        fullName,
        phone,
        isActive: active,
        status: active ? 'ACTIVE' : 'INACTIVE',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }
}

if (apply) {
  await createInBatches([...pendingAccounts, ...pendingPatients]);
}

console.table([
  {
    item: 'Firebase Auth users scanned',
    count: users.length,
  },
  {
    item: 'TAI_KHOAN documents to create',
    count: pendingAccounts.length,
  },
  {
    item: 'BENH_NHAN documents to create',
    count: pendingPatients.length,
  },
]);
console.log(
  apply
    ? 'Profile repair completed. Only missing documents were created.'
    : 'Dry run completed. No Firestore document was changed. Run again with --apply to create the missing profiles.',
);

async function listAllUsers() {
  const users = [];
  let pageToken;

  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);

  return users;
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
