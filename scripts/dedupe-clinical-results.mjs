import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const apply = process.argv.includes('--apply');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
if (!serviceAccountPath) throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.');
const serviceAccount = JSON.parse(await readFile(resolve(serviceAccountPath), 'utf8'));
if (!getApps().length) initializeApp({ credential: cert(serviceAccount), projectId: serviceAccount.project_id });
const firestore = getFirestore();
const rows = await firestore.collection('KET_QUA_CLS').get();
const groups = new Map();
const millis = (value) => value?.toMillis?.() ?? 0;
for (const doc of rows.docs) {
  const data = doc.data();
  const key = String(data.orderId || `${data.appointmentId || ''}|${data.testName || ''}`);
  if (!key || key === '|') continue;
  const list = groups.get(key) ?? [];
  list.push(doc);
  groups.set(key, list);
}
const removals = [];
for (const [key, docs] of groups) {
  docs.sort((a, b) => millis(b.data().updatedAt) - millis(a.data().updatedAt) || b.id.localeCompare(a.id));
  for (const duplicate of docs.slice(1)) removals.push({ key, id: duplicate.id, ref: duplicate.ref });
}
console.log(`${apply ? 'Applying' : 'Dry run'}: keep newest result and delete ${removals.length} duplicate(s).`);
for (const row of removals) console.log(`DELETE ${row.id} (${row.key})`);
if (apply) {
  for (let index = 0; index < removals.length; index += 400) {
    const batch = firestore.batch();
    for (const row of removals.slice(index, index + 400)) batch.delete(row.ref);
    await batch.commit();
  }
}
