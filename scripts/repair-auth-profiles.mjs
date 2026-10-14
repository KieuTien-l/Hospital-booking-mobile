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

const accounts = new Map(
  accountSnapshot.docs.map((document) => [document.id, document.data()]),
);
const patientsByAuthUserId = new Map();
for (const document of patientSnapshot.docs) {
  const authUserId = normalizeString(document.data().authUserId);
  if (authUserId === '') continue;
  const profiles = patientsByAuthUserId.get(authUserId) ?? [];
  profiles.push({ id: document.id, data: document.data() });
  patientsByAuthUserId.set(authUserId, profiles);
}
const pendingAccounts = [];
const pendingPatients = [];
const pendingPatientUpdates = [];
const duplicatePatientProfileUserIds = [];
let nonPatientAuthUsersSkipped = 0;

for (const user of users) {
  const active = !user.disabled;
  const fullName = user.displayName?.trim() ?? '';
  const email = user.email?.trim() ?? '';
  const phone = user.phoneNumber?.trim() ?? '';

  const account = accounts.get(user.uid);
  if (!account) {
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
  } else if (normalizeRole(account.role) !== 'patient') {
    nonPatientAuthUsersSkipped += 1;
    continue;
  }

  const profiles = patientsByAuthUserId.get(user.uid) ?? [];
  if (profiles.length === 0) {
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
  } else if (profiles.length === 1) {
    const profile = profiles[0];
    const changes = missingPatientFields({
      profile: profile.data,
      active,
      fullName,
      email,
      phone,
    });
    if (Object.keys(changes).length > 0) {
      pendingPatientUpdates.push({
        reference: firestore.collection('BENH_NHAN').doc(profile.id),
        data: { ...changes, updatedAt: FieldValue.serverTimestamp() },
      });
    }
  } else {
    duplicatePatientProfileUserIds.push(user.uid);
  }
}

if (apply) {
  await createInBatches([...pendingAccounts, ...pendingPatients]);
  await updateInBatches(pendingPatientUpdates);
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
  {
    item: 'BENH_NHAN documents to complete safely',
    count: pendingPatientUpdates.length,
  },
  {
    item: 'Auth users with duplicate patient profiles (not changed)',
    count: duplicatePatientProfileUserIds.length,
  },
  {
    item: 'Non-patient Auth users skipped',
    count: nonPatientAuthUsersSkipped,
  },
]);
console.log(
  apply
    ? 'Profile repair completed. Missing profiles were created and only empty patient fields were completed.'
    : 'Dry run completed. No Firestore document was changed. Run again with --apply to create missing profiles and complete empty patient fields.',
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

async function updateInBatches(documents) {
  const batchSize = 400;
  for (let start = 0; start < documents.length; start += batchSize) {
    const batch = firestore.batch();
    for (const { reference, data } of documents.slice(start, start + batchSize)) {
      batch.update(reference, data);
    }
    await batch.commit();
  }
}

function missingPatientFields({ profile, active, fullName, email, phone }) {
  const changes = {};
  if (normalizeString(profile.fullName) === '' && fullName !== '') {
    changes.fullName = fullName;
  }
  if (normalizeString(profile.email) === '' && email !== '') {
    changes.email = email;
  }
  if (normalizeString(profile.phone) === '' && phone !== '') {
    changes.phone = phone;
  }
  if (typeof profile.isActive !== 'boolean') changes.isActive = active;
  if (normalizeString(profile.status) === '') {
    changes.status = active ? 'ACTIVE' : 'INACTIVE';
  }
  return changes;
}

function normalizeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeRole(value) {
  return normalizeString(value).toLowerCase();
}
