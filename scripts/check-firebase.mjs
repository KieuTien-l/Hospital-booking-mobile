import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';

const sa = JSON.parse(await readFile('C:/Users/acer/bookinghospitalapp-admin.json', 'utf8'));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

console.log('--- DANH SÁCH BÁC SĨ TỪ FIREBASE ---');
const docs = await db.collection('BAC_SI').get();
docs.forEach(doc => console.log(doc.id, '=>', doc.data().fullName, '| ID:', doc.data().userId, '| Tiền khám:', doc.data().consultationFee));
