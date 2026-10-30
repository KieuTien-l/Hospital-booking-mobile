import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const apply = process.argv.includes('--apply');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
if (!serviceAccountPath) {
  throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.');
}
const serviceAccount = JSON.parse(await readFile(resolve(serviceAccountPath), 'utf8'));
if (!getApps().length) {
  initializeApp({ credential: cert(serviceAccount), projectId: serviceAccount.project_id });
}

const firestore = getFirestore();
const rows = await firestore.collection('HO_SO_SUC_KHOE').get();
const hasPrescription = (value) => {
  const normalized = String(value ?? '')
    .trim()
    .toLocaleLowerCase('vi-VN')
    .replace(/đ/g, 'd')
    .replace(/\s+/g, ' ');
  return normalized.length > 0 &&
      !/^(k|hk|khong|ko|chua) co don thuoc[.!]?$/.test(normalized);
};

const prescriptions = rows.docs
  .map((doc) => ({ id: doc.id, data: doc.data() }))
  .filter(({ data }) =>
    typeof data.patientId === 'string' &&
    typeof data.appointmentId === 'string' &&
    typeof data.doctorId === 'string' &&
    hasPrescription(data.prescription),
  )
  .map(({ id, data }) => ({
    id: `DT_${data.appointmentId}`,
    healthRecordId: id,
    data,
  }));

console.log(`${apply ? 'Applying' : 'Dry run'}: ${prescriptions.length} prescription(s) to migrate.`);
for (const row of prescriptions) {
  console.log(`UPSERT ${row.id} from HO_SO_SUC_KHOE/${row.healthRecordId}`);
}

if (apply) {
  for (let index = 0; index < prescriptions.length; index += 400) {
    const batch = firestore.batch();
    for (const row of prescriptions.slice(index, index + 400)) {
      const data = row.data;
      batch.set(
        firestore.collection('DON_THUOC').doc(row.id),
        {
          patientId: data.patientId,
          patientCode: data.patientCode ?? '',
          appointmentId: data.appointmentId,
          examinationId: data.examinationId ?? data.appointmentId,
          healthRecordId: row.healthRecordId,
          doctorId: data.doctorId,
          specialtyId: data.specialtyId ?? '',
          diagnosis: data.diagnosis ?? 'Đơn thuốc',
          instructions: data.prescription,
          status: 'ISSUED',
          issuedAt: data.recordDate ?? data.createdAt,
          createdAt: data.createdAt ?? data.recordDate,
          updatedAt: data.updatedAt ?? data.recordDate,
        },
        { merge: true },
      );
    }
    await batch.commit();
  }
}
