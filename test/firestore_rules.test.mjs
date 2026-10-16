import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'demo-healway-rules';
let testEnvironment;

const databaseFor = (userId) =>
  testEnvironment.authenticatedContext(userId).firestore();

const patientDatabase = () => databaseFor('patient-user');
const doctorDatabase = () => databaseFor('doctor-user');
const adminDatabase = () => databaseFor('admin-user');

async function seedFirestore() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const set = (path, value) => setDoc(doc(database, ...path), value);

    await Promise.all([
      set(['TAI_KHOAN', 'patient-user'], {
        isActive: true,
        role: 'patient',
      }),
      set(['TAI_KHOAN', 'other-patient-user'], {
        isActive: true,
        role: 'patient',
      }),
      set(['TAI_KHOAN', 'doctor-user'], { isActive: true, role: 'doctor' }),
      set(['TAI_KHOAN', 'admin-user'], { isActive: true, role: 'admin' }),
      set(['BENH_NHAN', 'patient-1'], { authUserId: 'patient-user' }),
      set(['BENH_NHAN', 'patient-2'], { authUserId: 'other-patient-user' }),
      set(['BAC_SI', 'doctor-1'], {
        userId: 'doctor-user',
        status: 'ACTIVE',
      }),
      set(['LICH_HEN', 'appointment-1'], {
        patientId: 'patient-1',
        doctorId: 'doctor-1',
      }),
      set(['LICH_HEN', 'appointment-2'], {
        patientId: 'patient-2',
        doctorId: 'doctor-2',
      }),
      set(['THONG_BAO', 'notification-1'], {
        patientId: 'patient-1',
        isRead: false,
      }),
      set(['THONG_BAO', 'notification-2'], {
        patientId: 'patient-2',
        isRead: false,
      }),
    ]);
  });
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 9080,
      rules: await readFile('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await seedFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

test('patient reads only their own appointment and notification', async () => {
  await assertSucceeds(
    getDoc(doc(patientDatabase(), 'LICH_HEN', 'appointment-1')),
  );
  await assertFails(
    getDoc(doc(patientDatabase(), 'LICH_HEN', 'appointment-2')),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(patientDatabase(), 'THONG_BAO'),
        where('patientId', '==', 'patient-1'),
      ),
    ),
  );
  await assertFails(
    getDocs(collection(patientDatabase(), 'THONG_BAO')),
  );
});

test('patient can mark only their own THONG_BAO notification as read', async () => {
  await assertSucceeds(
    updateDoc(doc(patientDatabase(), 'THONG_BAO', 'notification-1'), {
      isRead: true,
    }),
  );
  await assertFails(
    updateDoc(doc(patientDatabase(), 'THONG_BAO', 'notification-2'), {
      isRead: true,
    }),
  );
});

test('doctor accesses appointments assigned to their doctor profile only', async () => {
  await assertSucceeds(
    getDoc(doc(doctorDatabase(), 'LICH_HEN', 'appointment-1')),
  );
  await assertFails(
    getDoc(doc(doctorDatabase(), 'LICH_HEN', 'appointment-2')),
  );
});

test('admin can read every appointment', async () => {
  const snapshot = await assertSucceeds(
    getDoc(doc(adminDatabase(), 'LICH_HEN', 'appointment-2')),
  );
  assert.equal(snapshot.data().patientId, 'patient-2');
});

test('anonymous users cannot access protected appointment data', async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(database, 'LICH_HEN', 'appointment-1')));
});
