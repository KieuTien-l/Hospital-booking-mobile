import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const PROJECT_ID = 'bookinghospitalapp';
const SEED_VERSION = 'DEMO_V2';
const TODAY = '2026-10-17';
const END_DATE = argumentValue('--end-date');
const APPLY = process.argv.slice(2).includes('--apply');
const REPAIR = process.argv.slice(2).includes('--repair');
const SERVICE_ACCOUNT_PATH = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
const DEMO_PASSWORD = process.env.DEMO_ACCOUNT_PASSWORD;

if (!/^\d{4}-\d{2}-\d{2}$/.test(END_DATE ?? '')) {
  throw new Error('Use --end-date=YYYY-MM-DD.');
}
if (!SERVICE_ACCOUNT_PATH) {
  throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.');
}
if (APPLY && !DEMO_PASSWORD) {
  throw new Error('Set DEMO_ACCOUNT_PASSWORD before using --apply.');
}

const serviceAccount = JSON.parse(
  await readFile(resolve(SERVICE_ACCOUNT_PATH), 'utf8'),
);
if (serviceAccount.project_id !== PROJECT_ID) {
  throw new Error(
    `The service account is for ${serviceAccount.project_id}, not ${PROJECT_ID}.`,
  );
}
if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount), projectId: PROJECT_ID });
}

const firestore = getFirestore();
const auth = getAuth();
const scheduleDates = scheduleDatesFor(TODAY, END_DATE);
const plan = buildPlan(scheduleDates);

const existing = await inventory();
printDryRun(existing, plan);

if (!APPLY) {
  console.log('\nDry run completed. No Firestore document or Firebase Auth user was changed.');
  console.log('Run again with --apply only after reviewing this plan.');
  process.exit(0);
}

const adminAccounts = await activeAdminAccounts();
const seedUsers = await ensureSeedUsers(
  plan.authUsers,
  new Set(adminAccounts.map((account) => account.id)),
);
if (REPAIR) {
  await removeDemoDocuments();
  await writePlan(plan.documents);
  await verifySeed(adminAccounts, plan);
  console.log(`\n${SEED_VERSION} repair completed successfully.`);
  process.exit(0);
}
await deleteNonAdminAuthUsers(
  new Set([...adminAccounts.map((account) => account.id), ...seedUsers.map((user) => user.uid)]),
);
await resetFirestore(adminAccounts);
await writePlan(plan.documents);
await verifySeed(adminAccounts, plan);

console.log(`\n${SEED_VERSION} reset and seed completed successfully.`);

async function inventory() {
  const collections = await firestore.listCollections();
  const counts = await Promise.all(
    collections.map(async (collection) => ({
      name: collection.id,
      count: (await collection.count().get()).data().count,
    })),
  );
  const [admins, authUsers] = await Promise.all([
    firestore.collection('TAI_KHOAN').where('role', '==', 'admin').get(),
    listAuthUsers(),
  ]);
  return {
    collections: counts.sort((left, right) => left.name.localeCompare(right.name)),
    admins: admins.size,
    authUsers: authUsers.length,
  };
}

function printDryRun(existing, value) {
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Seed version: ${SEED_VERSION}`);
  console.log(`Schedule range: ${TODAY} to ${END_DATE} (Asia/Ho_Chi_Minh)`);
  console.log(`Existing Firebase Auth users: ${existing.authUsers}`);
  console.log(`Existing admin accounts to preserve: ${existing.admins}`);
  console.table(existing.collections.map(({ name, count }) => ({ collection: name, documents: count })));
  console.table(
    Object.entries(value.collectionCounts).map(([collection, documents]) => ({ collection, documents })),
  );
  console.table([
    { item: 'Doctor Auth users', value: 60 },
    { item: 'Patient Auth users', value: 60 },
    { item: 'Total new Auth users', value: value.authUsers.length },
    { item: 'Total new Firestore documents', value: value.documents.length },
  ]);
}

async function activeAdminAccounts() {
  const snapshot = await firestore
    .collection('TAI_KHOAN')
    .where('role', '==', 'admin')
    .get();
  if (snapshot.size !== 1) {
    throw new Error(`Expected exactly one admin account to preserve; found ${snapshot.size}.`);
  }
  const account = snapshot.docs[0];
  const user = await auth.getUser(account.id).catch(() => null);
  if (!user) {
    throw new Error('The admin TAI_KHOAN document has no matching Firebase Auth user. Reset stopped.');
  }
  return [{ id: account.id, data: account.data() }];
}

async function ensureSeedUsers(users, adminUids) {
  const resolved = [];
  for (const user of users) {
    const existing = await auth.getUser(user.uid).catch((error) => {
      if (error.code === 'auth/user-not-found') return null;
      throw error;
    });
    if (existing) {
      if (existing.email?.toLowerCase() !== user.email) {
        throw new Error(`Seed UID ${user.uid} already belongs to another email.`);
      }
      resolved.push(existing);
      continue;
    }
    const emailOwner = await auth.getUserByEmail(user.email).catch((error) => {
      if (error.code === 'auth/user-not-found') return null;
      throw error;
    });
    if (emailOwner && emailOwner.uid !== user.uid) {
      if (adminUids.has(emailOwner.uid)) {
        throw new Error(`Demo email ${user.email} belongs to the preserved administrator.`);
      }
      await retryAuthOperation(`delete conflicting user for ${user.email}`, () =>
        auth.deleteUser(emailOwner.uid),
      );
      console.log(`Removed legacy Auth user occupying ${user.email}.`);
    }
    resolved.push(
      await retryAuthOperation(`create ${user.uid}`, () =>
        auth.createUser({
          uid: user.uid,
          email: user.email,
          password: DEMO_PASSWORD,
          displayName: user.fullName,
          disabled: false,
          emailVerified: true,
        }),
      ),
    );
    await delay(250);
  }
  return resolved;
}

async function deleteNonAdminAuthUsers(preservedUids) {
  const users = await listAuthUsers();
  const userIdsToDelete = users
    .map((user) => user.uid)
    .filter((uid) => !preservedUids.has(uid));
  for (const batch of chunks(userIdsToDelete, 900)) {
    const result = await auth.deleteUsers(batch);
    if (result.failureCount > 0) {
      throw new Error(`Unable to delete ${result.failureCount} Firebase Auth user(s). Reset stopped.`);
    }
  }
  console.log(`Deleted ${userIdsToDelete.length} non-admin legacy Firebase Auth user(s).`);
}

async function resetFirestore(adminAccounts) {
  const collections = await firestore.listCollections();
  for (const collection of collections) {
    console.log(`Deleting Firestore collection recursively: ${collection.id}`);
    await firestore.recursiveDelete(collection);
  }
  const writer = firestore.bulkWriter();
  for (const account of adminAccounts) {
    writer.set(firestore.collection('TAI_KHOAN').doc(account.id), account.data);
  }
  await writer.close();
  console.log(`Restored ${adminAccounts.length} admin account document(s).`);
}

async function writePlan(documents) {
  const writer = firestore.bulkWriter();
  writer.onWriteError((error) => {
    console.error(`Write failed for ${error.documentRef.path}: ${error.message}`);
    return error.failedAttempts < 3;
  });
  for (const document of documents) {
    writer.set(firestore.collection(document.collection).doc(document.id), document.data);
  }
  await writer.close();
  console.log(`Wrote ${documents.length} ${SEED_VERSION} Firestore document(s).`);
}

async function removeDemoDocuments() {
  const collections = await firestore.listCollections();
  const writer = firestore.bulkWriter();
  let deleted = 0;
  for (const collection of collections) {
    const snapshot = await collection.where('source', '==', SEED_VERSION).get();
    for (const document of snapshot.docs) {
      writer.delete(document.ref);
      deleted += 1;
    }
  }
  await writer.close();
  console.log(`Removed ${deleted} existing ${SEED_VERSION} document(s) before repair.`);
}

async function verifySeed(adminAccounts, value) {
  const [specialties, doctors, patients, appointments, accounts] = await Promise.all([
    firestore.collection('CHUYEN_KHOA').where('source', '==', SEED_VERSION).count().get(),
    firestore.collection('BAC_SI').where('source', '==', SEED_VERSION).count().get(),
    firestore.collection('BENH_NHAN').where('source', '==', SEED_VERSION).count().get(),
    firestore.collection('LICH_HEN').where('source', '==', SEED_VERSION).count().get(),
    firestore.collection('TAI_KHOAN').where('source', '==', SEED_VERSION).count().get(),
  ]);
  const actual = {
    specialties: specialties.data().count,
    doctors: doctors.data().count,
    patients: patients.data().count,
    appointments: appointments.data().count,
    accounts: accounts.data().count,
  };
  const expected = {
    specialties: 12,
    doctors: 60,
    patients: 60,
    appointments: 300,
    accounts: 120,
  };
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Post-seed verification failed: ${JSON.stringify(actual)}.`);
  }
  for (const account of adminAccounts) {
    if (!(await firestore.collection('TAI_KHOAN').doc(account.id).get()).exists) {
      throw new Error('Admin account document was not restored.');
    }
  }
  if (value.authUsers.length !== 120) {
    throw new Error('Unexpected Auth user plan.');
  }
}

function buildPlan(dates) {
  const timestamp = FieldValue.serverTimestamp();
  const specialties = [
    ['CK00001', 'Nội tổng quát', 'Khám và điều trị các bệnh lý nội khoa thường gặp.'],
    ['CK00002', 'Tim mạch', 'Khám, tư vấn và điều trị bệnh lý tim mạch.'],
    ['CK00003', 'Thần kinh', 'Khám và điều trị bệnh lý não, thần kinh và cột sống.'],
    ['CK00004', 'Hô hấp', 'Khám và điều trị bệnh hô hấp.'],
    ['CK00005', 'Tiêu hóa', 'Khám và điều trị bệnh lý hệ tiêu hóa.'],
    ['CK00006', 'Cơ xương khớp', 'Khám và điều trị bệnh lý cơ, xương và khớp.'],
    ['CK00007', 'Nhi khoa', 'Chăm sóc sức khỏe trẻ em.'],
    ['CK00008', 'Sản phụ khoa', 'Khám sản khoa và phụ khoa.'],
    ['CK00009', 'Da liễu', 'Khám và điều trị bệnh lý da liễu.'],
    ['CK00010', 'Mắt', 'Khám và chăm sóc sức khỏe mắt.'],
    ['CK00011', 'Tai Mũi Họng', 'Khám và điều trị tai, mũi, họng.'],
    ['CK00012', 'Răng Hàm Mặt', 'Khám và điều trị răng, hàm, mặt.'],
  ].map(([code, name, description]) => ({ code, name, description }));

  const doctors = specialties.flatMap((specialty, specialtyIndex) =>
    Array.from({ length: 5 }, (_, doctorOffset) => {
      const number = specialtyIndex * 5 + doctorOffset + 1;
      const code = `BS${String(number).padStart(5, '0')}`;
      const fullName = sampleName(number, 'doctor');
      return {
        code,
        uid: `demo_v2_doctor_${code.toLowerCase()}`,
        email: `${code.toLowerCase()}@hospital.test`,
        fullName,
        phone: `090${String(number).padStart(7, '0')}`,
        specialty,
        yearsOfExperience: 5 + (number % 18),
        consultationFee: 150000 + (number % 4) * 50000,
      };
    }),
  );
  const patients = Array.from({ length: 60 }, (_, index) => {
    const number = index + 1;
    const code = `BN${String(number).padStart(5, '0')}`;
    return {
      code,
      uid: `demo_v2_patient_${code.toLowerCase()}`,
      email: `${code.toLowerCase()}@hospital.test`,
      fullName: sampleName(number, 'patient'),
      phone: `091${String(number).padStart(7, '0')}`,
      gender: number % 2 === 0 ? 'Nữ' : 'Nam',
    };
  });

  const documents = [];
  const add = (collection, id, data) => {
    documents.push({ collection, id, data: { ...data, source: SEED_VERSION, seedVersion: 2 } });
  };

  for (const specialty of specialties) {
    add('CHUYEN_KHOA', `demo_v2_specialty_${specialty.code.toLowerCase()}`, {
      specialtyCode: specialty.code,
      name: specialty.name,
      description: specialty.description,
      isActive: true,
      status: 'ACTIVE',
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  }

  for (const doctor of doctors) {
    const doctorId = `demo_v2_doctor_profile_${doctor.code.toLowerCase()}`;
    const specialtyId = `demo_v2_specialty_${doctor.specialty.code.toLowerCase()}`;
    add('TAI_KHOAN', doctor.uid, {
      accountCode: doctor.code,
      accountKey: doctor.uid,
      email: doctor.email,
      fullName: doctor.fullName,
      phone: doctor.phone,
      role: 'doctor',
      permission: 'DOCTOR',
      isActive: true,
      status: 'ACTIVE',
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    add('BAC_SI', doctorId, {
      doctorCode: doctor.code,
      userId: doctor.uid,
      fullName: doctor.fullName,
      email: doctor.email,
      phone: doctor.phone,
      specialtyId,
      specialtyName: doctor.specialty.name,
      qualification: 'Bác sĩ chuyên khoa I',
      biography: `Bác sĩ ${doctor.fullName} chuyên khám và tư vấn ${doctor.specialty.name.toLowerCase()}.`,
      yearsOfExperience: doctor.yearsOfExperience,
      consultationFee: doctor.consultationFee,
      isActive: true,
      status: 'ACTIVE',
      createdAt: timestamp,
      updatedAt: timestamp,
    });

    for (const [dateIndex, date] of dates.entries()) {
      const scheduleId = `demo_v2_schedule_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`;
      add('LICH_LAM_VIEC', scheduleId, {
        doctorId,
        workDate: Timestamp.fromDate(vietnamDate(date)),
        startTime: '08:00',
        endTime: '10:30',
        status: 'ACTIVE',
        createdAt: timestamp,
        updatedAt: timestamp,
      });
      for (const [slotIndex, [startTime, endTime]] of timeRanges().entries()) {
        const slotId = `demo_v2_slot_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}_${slotIndex + 1}`;
        const appointmentIndex = dateIndex;
        const appointmentId = `demo_v2_appointment_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`;
        const isBooked = slotIndex === appointmentIndex;
        add('CA_KHAM', slotId, {
          workScheduleId: scheduleId,
          doctorId,
          startTime,
          endTime,
          capacity: 5,
          bookedCount: isBooked ? 1 : 0,
          status: 'AVAILABLE',
          ...(isBooked
            ? {
                appointmentId,
                reservationCounts: { [appointmentId]: 1 },
              }
            : { reservationCounts: {} }),
          createdAt: timestamp,
          updatedAt: timestamp,
        });
      }

      const patient = patients[(doctors.indexOf(doctor) * dates.length + dateIndex) % patients.length];
      const appointmentId = `demo_v2_appointment_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`;
      const slotStart = timeRanges()[dateIndex][0];
      const slotEnd = timeRanges()[dateIndex][1];
      const slotId = `demo_v2_slot_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}_${dateIndex + 1}`;
      const patientId = `demo_v2_patient_profile_${patient.code.toLowerCase()}`;
      const isCompleted = dateIndex < 2;
      const status = isCompleted ? 'COMPLETED' : dateIndex === 3 ? 'CONFIRMED' : 'PENDING';
      add('LICH_HEN', appointmentId, {
        patientId,
        doctorId,
        workScheduleId: scheduleId,
        timeSlotId: slotId,
        specialtyId,
        appointmentDate: Timestamp.fromDate(vietnamDate(date)),
        startTime: slotStart,
        endTime: slotEnd,
        bookedAt: Timestamp.fromDate(vietnamDate(date, 7, 30)),
        status,
        reason: `Khám ${doctor.specialty.name.toLowerCase()} định kỳ.`,
        symptoms: isCompleted ? 'Triệu chứng đã được bác sĩ thăm khám.' : 'Cần được bác sĩ tư vấn.',
        note: isCompleted ? 'Đã hoàn tất buổi khám.' : 'Lịch hẹn dữ liệu demo.',
        peopleCount: 1,
        queueNumber: dateIndex + 1,
        ...(isCompleted ? { checkInTime: Timestamp.fromDate(vietnamDate(date, 7, 50)) } : {}),
        createdAt: timestamp,
        updatedAt: timestamp,
      });
      add('THONG_BAO', `demo_v2_notification_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`, {
        patientId,
        appointmentId,
        title: isCompleted ? 'Hoàn tất lịch khám' : 'Nhắc lịch hẹn khám',
        content: isCompleted
          ? `Lịch khám với ${doctor.fullName} đã hoàn tất.`
          : `Bạn có lịch khám với ${doctor.fullName} vào ${date} lúc ${slotStart}.`,
        isRead: isCompleted,
        createdAt: timestamp,
      });
      add('THANH_TOAN', `demo_v2_payment_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`, {
        patientId,
        appointmentId,
        amount: doctor.consultationFee,
        paymentMethod: dateIndex % 2 === 0 ? 'MOMO' : 'BANK_TRANSFER',
        status: isCompleted ? 'SUCCESS' : 'PENDING',
        ...(isCompleted ? { paidAt: Timestamp.fromDate(vietnamDate(date, 8, 15)) } : {}),
        transactionCode: isCompleted ? `DEMO-${doctor.code}-${date.replaceAll('-', '')}` : null,
        isTestData: true,
        createdAt: timestamp,
      });
      if (isCompleted) {
        add('HO_SO_SUC_KHOE', `demo_v2_record_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`, {
          patientId,
          doctorId,
          recordDate: Timestamp.fromDate(vietnamDate(date, 9)),
          diagnosis: `Theo dõi ${doctor.specialty.name.toLowerCase()}.`,
          notes: 'Hồ sơ sức khỏe mô phỏng cho môi trường demo.',
          prescription: 'Dùng thuốc theo chỉ định của bác sĩ.',
          attachments: [],
          recordType: 'OUTPATIENT',
          documentCategory: 'PRESCRIPTION',
          createdAt: timestamp,
          updatedAt: timestamp,
        });
        add('KET_QUA_CLS', `demo_v2_result_${doctor.code.toLowerCase()}_${date.replaceAll('-', '')}`, {
          patientId,
          testName: dateIndex === 0 ? 'Xét nghiệm máu tổng quát' : 'Đo huyết áp và chỉ số cơ bản',
          resultDescription: 'Kết quả trong giới hạn tham chiếu.',
          testDate: Timestamp.fromDate(vietnamDate(date, 9, 30)),
          resultType: 'Xét nghiệm',
          conclusion: 'Theo dõi định kỳ theo hướng dẫn bác sĩ.',
          referenceRange: 'Theo tiêu chuẩn phòng xét nghiệm.',
          doctorName: doctor.fullName,
          createdAt: timestamp,
        });
      }
    }
  }

  for (const patient of patients) {
    const patientId = `demo_v2_patient_profile_${patient.code.toLowerCase()}`;
    add('TAI_KHOAN', patient.uid, {
      accountCode: patient.code,
      accountKey: patient.uid,
      email: patient.email,
      fullName: patient.fullName,
      phone: patient.phone,
      role: 'patient',
      permission: 'PATIENT',
      isActive: true,
      status: 'ACTIVE',
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    add('BENH_NHAN', patientId, {
      patientCode: patient.code,
      authUserId: patient.uid,
      fullName: patient.fullName,
      email: patient.email,
      phone: patient.phone,
      gender: patient.gender,
      dateOfBirth: Timestamp.fromDate(vietnamDate(`19${70 + (Number(patient.code.slice(-2)) % 25)}-06-15`)),
      address: 'Quận 1, Thành phố Hồ Chí Minh',
      district: 'Quận 1',
      province: 'Thành phố Hồ Chí Minh',
      country: 'Việt Nam',
      insuranceNumber: `BHYT${patient.code.slice(-5)}`,
      isActive: true,
      status: 'ACTIVE',
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    add('PHAN_HOI', `demo_v2_feedback_${patient.code.toLowerCase()}`, {
      patientId,
      title: 'Phản hồi dịch vụ',
      content: 'Quy trình đặt lịch rõ ràng, nhân viên hỗ trợ nhiệt tình.',
      category: 'Dịch vụ',
      rating: 4 + (Number(patient.code.slice(-1)) % 2),
      createdAt: timestamp,
    });
    add('LS_CHAT_AI', `demo_v2_chat_${patient.code.toLowerCase()}`, {
      userId: patient.uid,
      sessionId: `demo_v2_session_${patient.code.toLowerCase()}`,
      userMessage: 'Tôi cần đặt lịch khám.',
      aiReply: 'Bạn hãy chọn chuyên khoa, bác sĩ và khung giờ phù hợp.',
      timestamp,
    });
  }

  const collectionCounts = documents.reduce((counts, document) => {
    counts[document.collection] = (counts[document.collection] ?? 0) + 1;
    return counts;
  }, {});
  return {
    authUsers: [...doctors, ...patients].map((person) => ({
      uid: person.uid,
      email: person.email,
      fullName: person.fullName,
    })),
    documents,
    collectionCounts,
  };
}

async function listAuthUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

function scheduleDatesFor(today, endDate) {
  const start = vietnamDate(today);
  const end = vietnamDate(endDate);
  const difference = Math.round((end.getTime() - start.getTime()) / 86400000);
  if (difference < 4) {
    throw new Error('The end date must be at least four days after 2026-10-17.');
  }
  const futureMiddle = Math.max(1, Math.floor(difference / 2));
  return [
    dateString(addDays(start, -2)),
    dateString(addDays(start, -1)),
    dateString(start),
    dateString(addDays(start, futureMiddle)),
    dateString(end),
  ];
}

function vietnamDate(value, hour = 0, minute = 0) {
  if (value instanceof Date) return value;
  return new Date(`${value}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00+07:00`);
}

function addDays(value, days) {
  const result = new Date(value.getTime());
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

function dateString(value) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const values = Object.fromEntries(
    parts
      .filter((part) => ['year', 'month', 'day'].includes(part.type))
      .map((part) => [part.type, part.value]),
  );
  return `${values.year}-${values.month}-${values.day}`;
}

function timeRanges() {
  return [
    ['08:00', '08:30'],
    ['08:30', '09:00'],
    ['09:00', '09:30'],
    ['09:30', '10:00'],
    ['10:00', '10:30'],
  ];
}

function sampleName(index, type) {
  const familyNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Võ', 'Đặng', 'Bùi', 'Đỗ', 'Hồ'];
  const middleNames = type === 'doctor'
    ? ['Minh', 'Thành', 'Ngọc', 'Quốc', 'Thanh', 'Thu', 'Gia', 'Khánh', 'Bảo', 'Phương']
    : ['Anh', 'Thị', 'Văn', 'Ngọc', 'Minh', 'Hoài', 'Quốc', 'Thanh', 'Gia', 'Bảo'];
  const givenNames = ['An', 'Bình', 'Châu', 'Dũng', 'Hà', 'Huy', 'Lan', 'Linh', 'Mai', 'Nam'];
  return `${familyNames[index % familyNames.length]} ${middleNames[Math.floor(index / 2) % middleNames.length]} ${givenNames[(index * 3) % givenNames.length]}`;
}

function chunks(values, size) {
  return Array.from({ length: Math.ceil(values.length / size) }, (_, index) =>
    values.slice(index * size, index * size + size),
  );
}

async function retryAuthOperation(label, operation) {
  let lastError;
  for (let attempt = 1; attempt <= 5; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (!['auth/internal-error', 'auth/too-many-requests', 'auth/network-request-failed', 'auth/quota-exceeded'].includes(error.code) || attempt === 5) {
        throw error;
      }
      const delayMs = attempt * 1500;
      console.log(`Retrying ${label} in ${delayMs}ms (${error.code}).`);
      await delay(delayMs);
    }
  }
  throw lastError;
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function argumentValue(name) {
  const argument = process.argv.slice(2).find((value) => value.startsWith(`${name}=`));
  return argument?.slice(name.length + 1).trim();
}
