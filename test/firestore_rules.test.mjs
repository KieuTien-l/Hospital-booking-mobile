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
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'demo-healway-rules';
const configuredEmulatorPort = process.env.FIRESTORE_EMULATOR_HOST
  ?.match(/:(\d+)$/)?.[1];
const firestorePort = Number.parseInt(
  configuredEmulatorPort ?? process.env.FIRESTORE_EMULATOR_PORT ?? '9080',
  10,
);
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
      set(['TAI_KHOAN', 'locked-patient-user'], {
        isActive: false,
        role: 'patient',
        status: 'INACTIVE',
      }),
      set(['TAI_KHOAN', 'doctor-user'], { isActive: true, role: 'doctor' }),
      set(['TAI_KHOAN', 'disabled-doctor-user'], {
        isActive: true,
        role: 'doctor',
      }),
      set(['TAI_KHOAN', 'admin-user'], { isActive: true, role: 'admin' }),
      set(['BENH_NHAN', 'patient-1'], { authUserId: 'patient-user' }),
      set(['BENH_NHAN', 'patient-2'], { authUserId: 'other-patient-user' }),
      set(['BENH_NHAN', 'locked-patient-1'], {
        authUserId: 'locked-patient-user',
      }),
      set(['BAC_SI', 'doctor-1'], {
        userId: 'doctor-user',
        status: 'ACTIVE',
      }),
      set(['BAC_SI', 'disabled-doctor-1'], {
        userId: 'disabled-doctor-user',
        isActive: false,
        status: 'ACTIVE',
      }),
      set(['LICH_HEN', 'appointment-1'], {
        patientId: 'patient-1',
        doctorId: 'doctor-1',
        status: 'PENDING',
      }),
      set(['LICH_HEN', 'appointment-2'], {
        patientId: 'patient-2',
        doctorId: 'doctor-2',
        status: 'PENDING',
      }),
      set(['LICH_HEN', 'disabled-doctor-appointment'], {
        patientId: 'patient-1',
        doctorId: 'disabled-doctor-1',
        status: 'PENDING',
      }),
      set(['THONG_BAO', 'notification-1'], {
        patientId: 'patient-1',
        isRead: false,
      }),
      set(['THONG_BAO', 'notification-2'], {
        patientId: 'patient-2',
        isRead: false,
      }),
      set(['LICH_HEN', 'past-appointment'], {
        patientId: 'patient-1',
        doctorId: 'doctor-1',
        workScheduleId: 'past-schedule',
        timeSlotId: 'past-slot',
        specialtyId: 'specialty-1',
        appointmentDate: new Date('2020-01-01T00:00:00.000Z'),
        startTime: '08:00',
        endTime: '08:30',
        peopleCount: 1,
        status: 'PENDING',
      }),
      set(['CA_KHAM', 'past-slot'], {
        workScheduleId: 'past-schedule',
        doctorId: 'doctor-1',
        appointmentId: 'past-appointment',
        bookedCount: 1,
        capacity: 5,
        reservationCounts: {'past-appointment': 1},
        startsAt: new Date('2020-01-01T08:00:00.000Z'),
        status: 'AVAILABLE',
      }),
      set(['LICH_HEN', 'future-appointment'], {
        patientId: 'patient-1',
        doctorId: 'doctor-1',
        workScheduleId: 'future-schedule',
        timeSlotId: 'future-slot',
        specialtyId: 'specialty-1',
        appointmentDate: new Date('2030-01-01T00:00:00.000Z'),
        startTime: '08:00',
        endTime: '08:30',
        peopleCount: 1,
        status: 'PENDING',
      }),
      set(['CA_KHAM', 'future-slot'], {
        workScheduleId: 'future-schedule',
        doctorId: 'doctor-1',
        appointmentId: 'future-appointment',
        bookedCount: 1,
        capacity: 5,
        reservationCounts: {'future-appointment': 1},
        startsAt: new Date('2030-01-01T08:00:00.000Z'),
        status: 'AVAILABLE',
      }),
    ]);
  });
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: firestorePort,
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

async function cancelAppointment(database, appointmentId, slotId) {
  return runTransaction(database, async (transaction) => {
    transaction.update(doc(database, 'LICH_HEN', appointmentId), {
      status: 'CANCELLED',
      cancellationReason: 'Không thể đến khám',
      updatedAt: new Date(),
    });
    transaction.update(doc(database, 'CA_KHAM', slotId), {
      bookedCount: 0,
      status: 'AVAILABLE',
      appointmentId,
      reservationCounts: {},
      updatedAt: new Date(),
    });
  });
}

test('patient cannot cancel after a slot starts but can cancel a future slot', async () => {
  await assertFails(
    cancelAppointment(patientDatabase(), 'past-appointment', 'past-slot'),
  );
  await assertSucceeds(
    cancelAppointment(patientDatabase(), 'future-appointment', 'future-slot'),
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

test('locked patients cannot read, create, or update a patient profile', async () => {
  const locked = databaseFor('locked-patient-user');
  await assertFails(getDoc(doc(locked, 'BENH_NHAN', 'locked-patient-1')));
  await assertFails(
    setDoc(doc(locked, 'BENH_NHAN', 'locked-patient-user'), {
      authUserId: 'locked-patient-user',
      fullName: 'Nguyễn Bị Khóa',
      phone: '0912345678',
      email: 'locked@example.com',
      isActive: true,
      status: 'ACTIVE',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

async function createFamilyProfile(database, id, code, relationship = 'Tôi') {
  const patient = doc(database, 'BENH_NHAN', id);
  const codeReservation = doc(database, 'MA_HO_SO', code);
  return runTransaction(database, async (transaction) => {
    // This mirrors the mobile app: check one candidate code, then reserve it
    // atomically with the patient profile.
    assert.equal((await transaction.get(codeReservation)).exists(), false);
    transaction.set(patient, {
      authUserId: 'patient-user',
      ownerUserId: 'patient-user',
      patientCode: code,
      fullName: 'Nguyễn Minh Anh',
      phone: '0912345678',
      email: 'anh@example.com',
      isActive: true,
      status: 'ACTIVE',
      relationshipToAccountHolder: relationship,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.set(codeReservation, {
      patientId: id,
      ownerUserId: 'patient-user',
      createdAt: serverTimestamp(),
    });
  });
}

test('active patient can create multiple valid family profiles with reserved codes', async () => {
  const database = databaseFor('patient-user');
  await assertSucceeds(
    createFamilyProfile(database, 'profile-self', 'HS-ABCD-2345'),
  );
  await assertSucceeds(
    createFamilyProfile(database, 'profile-mother', 'HS-EFGH-6789', 'Cha / Mẹ'),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(database, 'BENH_NHAN'),
        where('ownerUserId', '==', 'patient-user'),
      ),
    ),
  );
  await assertFails(setDoc(doc(database, 'MA_HO_SO', 'HS-ABCD-2345'), {
    patientId: 'profile-other', ownerUserId: 'patient-user', createdAt: serverTimestamp(),
  }));
  await assertFails(getDocs(collection(database, 'MA_HO_SO')));
});

test('a disabled doctor cannot read or mutate appointment data directly', async () => {
  const disabledDoctor = databaseFor('disabled-doctor-user');
  await assertFails(
    getDoc(doc(disabledDoctor, 'LICH_HEN', 'disabled-doctor-appointment')),
  );
  await assertFails(
    updateDoc(doc(doctorDatabase(), 'LICH_HEN', 'appointment-1'), {
      status: 'CANCELLED',
    }),
  );
});

test('admin can read every appointment', async () => {
  const snapshot = await assertSucceeds(
    getDoc(doc(adminDatabase(), 'LICH_HEN', 'appointment-2')),
  );
  assert.equal(snapshot.data().patientId, 'patient-2');
});

test('admin clients cannot write schedules directly; adminCommand must do it', async () => {
  await assertFails(
    setDoc(doc(adminDatabase(), 'LICH_LAM_VIEC', 'invalid-schedule'), {
      doctorId: 'missing-doctor',
      workDate: new Date(),
      startTime: '08:00',
      endTime: '12:00',
      status: 'ACTIVE',
    }),
  );
});

test('admin clients cannot bypass adminCommand for an active doctor either', async () => {
  await assertFails(
    setDoc(doc(adminDatabase(), 'LICH_LAM_VIEC', 'valid-schedule'), {
      doctorId: 'doctor-1',
      workDate: new Date(),
      startTime: '08:00',
      endTime: '12:00',
      status: 'ACTIVE',
    }),
  );
});

test('anonymous users cannot access protected appointment data', async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(database, 'LICH_HEN', 'appointment-1')));
});
