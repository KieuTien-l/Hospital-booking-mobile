import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const PROJECT_ID = 'bookinghospitalapp';
const SEED_VERSION = 'DEMO_V2';
const APPLY = process.argv.slice(2).includes('--apply');
const SERVICE_ACCOUNT_PATH = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!SERVICE_ACCOUNT_PATH) {
  throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.');
}

const serviceAccount = JSON.parse(
  await readFile(resolve(SERVICE_ACCOUNT_PATH), 'utf8'),
);
if (serviceAccount.project_id !== PROJECT_ID) {
  throw new Error(`The service account is for ${serviceAccount.project_id}, not ${PROJECT_ID}.`);
}
if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount), projectId: PROJECT_ID });
}

const firestore = getFirestore();
const targets = [
  ['LICH_LAM_VIEC', ['workDate']],
  ['LICH_HEN', ['appointmentDate', 'bookedAt', 'checkInTime']],
  ['THANH_TOAN', ['paidAt']],
  ['HO_SO_SUC_KHOE', ['recordDate']],
  ['KET_QUA_CLS', ['testDate']],
];

const updates = [];
for (const [collectionName, fields] of targets) {
  const snapshot = await firestore
    .collection(collectionName)
    .where('source', '==', SEED_VERSION)
    .get();
  for (const document of snapshot.docs) {
    const changes = {};
    for (const field of fields) {
      const value = document.data()[field];
      if (value?.toMillis instanceof Function) {
        changes[field] = Timestamp.fromMillis(value.toMillis() + 86400000);
      }
    }
    if (Object.keys(changes).length > 0) {
      updates.push({ reference: document.ref, changes });
    }
  }
}

console.table(
  targets.map(([collectionName]) => ({
    collection: collectionName,
    documentsToShift: updates.filter((update) => update.reference.parent.id === collectionName).length,
  })),
);

if (!APPLY) {
  console.log('Dry run completed. No Firestore document was changed.');
  process.exit(0);
}

const writer = firestore.bulkWriter();
for (const { reference, changes } of updates) {
  writer.update(reference, changes);
}
await writer.close();
console.log(`Shifted date fields by one day in ${updates.length} ${SEED_VERSION} document(s).`);
