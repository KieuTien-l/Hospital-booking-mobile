import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const apply = process.argv.includes('--apply');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
if (!serviceAccountPath) {
  throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.');
}
const serviceAccount = JSON.parse(await readFile(resolve(serviceAccountPath), 'utf8'));
if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount), projectId: serviceAccount.project_id });
}

const firestore = getFirestore();
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function codeFor(seed, salt = 0) {
  const digest = createHash('sha256').update(`${seed}:${salt}`).digest();
  const text = Array.from({ length: 8 }, (_, index) =>
    alphabet[digest[index] % alphabet.length],
  ).join('');
  return `HS-${text.slice(0, 4)}-${text.slice(4)}`;
}

const patients = await firestore.collection('BENH_NHAN').get();
const existingRegistries = new Map(
  (await firestore.collection('MA_HO_SO').get()).docs.map((document) => [
    document.id,
    document.data(),
  ]),
);
const reserved = new Set(existingRegistries.keys());
const updates = [];
for (const document of patients.docs) {
  const data = document.data();
  const ownerUserId = String(data.ownerUserId ?? data.authUserId ?? '').trim();
  if (!ownerUserId) {
    console.warn(`Skip ${document.id}: missing authUserId/ownerUserId.`);
    continue;
  }
  let patientCode = String(data.patientCode ?? '').trim();
  if (!/^HS-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(patientCode) ||
      (existingRegistries.has(patientCode) &&
        existingRegistries.get(patientCode).patientId !== document.id)) {
    let salt = 0;
    do patientCode = codeFor(document.id, salt++);
    while (reserved.has(patientCode));
  }
  reserved.add(patientCode);
  const changes = {};
  if (data.ownerUserId !== ownerUserId) changes.ownerUserId = ownerUserId;
  if (data.patientCode !== patientCode) changes.patientCode = patientCode;
  const registry = existingRegistries.get(patientCode);
  const registryNeedsRepair = registry?.patientId !== document.id ||
    registry?.ownerUserId !== ownerUserId;
  if (Object.keys(changes).length || registryNeedsRepair) {
    updates.push({ patient: document.ref, code: patientCode, ownerUserId, changes });
  }
}

if (apply) {
  for (let start = 0; start < updates.length; start += 300) {
    const batch = firestore.batch();
    for (const update of updates.slice(start, start + 300)) {
      batch.update(update.patient, update.changes);
      batch.set(firestore.collection('MA_HO_SO').doc(update.code), {
        patientId: update.patient.id,
        ownerUserId: update.ownerUserId,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
  }
}

console.log(`${apply ? 'Migrated' : 'Would migrate'} ${updates.length} patient profiles.`);
