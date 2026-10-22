import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

// This script creates a coherent, explicitly labelled training data set.  It
// never changes documents from a different source and may safely be rerun.
const PROJECT_ID = 'bookinghospitalapp';
const SOURCE = 'SEED_HOSPITAL_OPERATIONAL_2026';
const APPLY = process.argv.includes('--apply');
const VERIFY = process.argv.includes('--verify');
const START_DATE = argumentValue('--start-date') || '2026-09-08';
const END_DATE = argumentValue('--end-date') || '2026-10-27';
const DOCTORS_PER_SPECIALTY = Number(
  argumentValue('--doctors-per-specialty') || '1',
);
const PATIENT_PASSWORD =
  argumentValue('--patient-password') || process.env.SEED_PATIENT_PASSWORD;
const SERVICE_ACCOUNT_PATH =
  argumentValue('--service-account') || process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!isDateString(START_DATE) || !isDateString(END_DATE) || START_DATE > END_DATE) {
  throw new Error('Use an inclusive --start-date and --end-date in YYYY-MM-DD format.');
}
if (!Number.isInteger(DOCTORS_PER_SPECIALTY) || DOCTORS_PER_SPECIALTY < 1 ||
    DOCTORS_PER_SPECIALTY > 5) {
  throw new Error('Use --doctors-per-specialty between 1 and 5.');
}
if (APPLY && !PATIENT_PASSWORD) {
  throw new Error(
    'Set SEED_PATIENT_PASSWORD or pass --patient-password before using --apply.',
  );
}
if (!SERVICE_ACCOUNT_PATH) {
  throw new Error(
    'Set FIREBASE_SERVICE_ACCOUNT_PATH or pass --service-account=<path>.',
  );
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
const dates = dateRange(START_DATE, END_DATE);
const rangeStart = at(START_DATE, '00:00');
const rangeEndExclusive = at(addVietnamDays(END_DATE, 1), '00:00');

const [specialtiesSnapshot, doctorsSnapshot, accountsSnapshot, schedulesSnapshot] = await Promise.all([
  firestore.collection('CHUYEN_KHOA').get(),
  firestore.collection('BAC_SI').get(),
  firestore.collection('TAI_KHOAN').get(),
  firestore
      .collection('LICH_LAM_VIEC')
      .where('workDate', '>=', rangeStart)
      .where('workDate', '<', rangeEndExclusive)
      .get(),
]);

const activeSpecialties = new Map(
  specialtiesSnapshot.docs
      .filter((document) => isActive(document.data()))
      .map((document) => [document.id, specialtyName(document.data(), document.id)]),
);
const doctorAccounts = new Set(
  accountsSnapshot.docs
      .filter((document) => stringValue(document.data().role).toLowerCase() === 'doctor')
      .flatMap((document) => [document.id, stringValue(document.data().accountKey)])
      .filter((value) => value !== ''),
);
const operationalDoctors = doctorsSnapshot.docs
    .filter((document) => isOperationalDoctor(document.id, document.data()))
    .filter((document) => activeSpecialties.has(stringValue(document.data().specialtyId)));
const doctors = [];
for (const specialtyId of activeSpecialties.keys()) {
  const candidates = operationalDoctors
      .filter((document) => stringValue(document.data().specialtyId) === specialtyId)
      .sort((left, right) => {
        const leftHasLogin = doctorAccounts.has(stringValue(left.data().userId));
        const rightHasLogin = doctorAccounts.has(stringValue(right.data().userId));
        if (leftHasLogin !== rightHasLogin) return leftHasLogin ? -1 : 1;
        return left.id.localeCompare(right.id);
      });
  doctors.push(...candidates.slice(0, DOCTORS_PER_SPECIALTY));
}

if (doctors.length === 0) {
  throw new Error(
    'No active non-sample doctor with an active specialty was found. No data was written.',
  );
}

const existingActiveScheduleKeys = new Set();
for (const document of schedulesSnapshot.docs) {
  const data = document.data();
  const workDate = vietnamDateString(toDate(data.workDate));
  if (
    stringValue(data.status).toUpperCase() === 'ACTIVE' &&
    stringValue(data.doctorId) !== '' &&
    workDate !== ''
  ) {
    existingActiveScheduleKeys.add(`${data.doctorId}|${workDate}`);
  }
}

// The number is derived from the number of doctors so that no synthetic
// patient is double-booked on the busiest (17 October) dashboard day.
const patients = buildPatients(Math.max(48, doctors.length * 12));
const documents = [];
for (const patient of patients) {
  documents.push(
    document('TAI_KHOAN', patient.authUserId, accountDocument(patient)),
    document('BENH_NHAN', patient.id, patientDocument(patient)),
  );
}

let schedulesCreated = 0;
let schedulesSkippedForExistingData = 0;
let slotsCreated = 0;
let appointmentsCreated = 0;
const appointmentsPerPatientDay = new Map();

for (const [doctorIndex, doctorDocument] of doctors.entries()) {
  const doctor = doctorDocument.data();
  const doctorId = doctorDocument.id;
  const specialtyId = stringValue(doctor.specialtyId);
  const specialty = activeSpecialties.get(specialtyId) ?? specialtyId;

  for (const [dateIndex, date] of dates.entries()) {
    if (!isDoctorWorking(date, doctorIndex)) continue;

    const scheduleKey = `${doctorId}|${date}`;
    if (existingActiveScheduleKeys.has(scheduleKey)) {
      schedulesSkippedForExistingData += 1;
      continue;
    }

    const scheduleId = `seed_hospital_2026_schedule_${safeId(doctorId)}_${date.replaceAll('-', '')}`;
    const slotPlans = slotPlansForDate(date);
    const schedule = {
      doctorId,
      workDate: at(date, '00:00'),
      startTime: slotPlans[0].startTime,
      endTime: slotPlans.at(-1).endTime,
      status: 'ACTIVE',
      source: SOURCE,
      isTestData: true,
      createdAt: at(date, '05:30'),
      updatedAt: FieldValue.serverTimestamp(),
    };
    documents.push(document('LICH_LAM_VIEC', scheduleId, schedule));
    schedulesCreated += 1;

    let patientCursor = (dateIndex * doctors.length * 12) + doctorIndex * 12;
    for (const [slotIndex, plan] of slotPlans.entries()) {
      const slotId = `${scheduleId}_${plan.startTime.replace(':', '')}`;
      const reservationCounts = {};
      const bookedAppointments = [];
      const capacity = 3;
      const places = placesForSlot(date, slotIndex);

      for (let place = 0; place < places; place += 1) {
        let patient;
        // A patient has at most one seeded appointment per day. This is both
        // clinically sensible and prevents confusing entries in the patient UI.
        do {
          patient = patients[patientCursor % patients.length];
          patientCursor += 1;
        } while (appointmentsPerPatientDay.has(`${patient.id}|${date}`));
        appointmentsPerPatientDay.set(`${patient.id}|${date}`, true);

        const appointmentId = [
          'seed_hospital_2026_appointment',
          date.replaceAll('-', ''),
          safeId(doctorId),
          plan.startTime.replace(':', ''),
          String(place + 1),
        ].join('_');
        const status = appointmentStatus(date, slotIndex, place);
        const appointment = {
          patientId: patient.id,
          doctorId,
          workScheduleId: scheduleId,
          timeSlotId: slotId,
          specialtyId,
          appointmentDate: at(date, '00:00'),
          startTime: plan.startTime,
          endTime: plan.endTime,
          bookedAt: bookedAt(date, doctorIndex, slotIndex, place),
          status,
          reason: visitReason(specialty, place),
          symptoms: visitSymptoms(specialty, place),
          peopleCount: 1,
          queueNumber: bookedAppointments.length + 1,
          ...(status === 'COMPLETED'
              ? { checkInTime: checkInAt(date, plan.startTime, place) }
              : {}),
          source: SOURCE,
          isTestData: true,
          createdAt: bookedAt(date, doctorIndex, slotIndex, place),
          updatedAt: FieldValue.serverTimestamp(),
        };
        documents.push(document('LICH_HEN', appointmentId, appointment));
        reservationCounts[appointmentId] = 1;
        bookedAppointments.push(appointmentId);
        appointmentsCreated += 1;
      }

      documents.push(
        document('CA_KHAM', slotId, {
          workScheduleId: scheduleId,
          doctorId,
          startTime: plan.startTime,
          endTime: plan.endTime,
          capacity,
          bookedCount: bookedAppointments.length,
          ...(bookedAppointments.length > 0
              ? { appointmentId: bookedAppointments.at(-1) }
              : {}),
          reservationCounts,
          status: bookedAppointments.length >= capacity ? 'BOOKED' : 'AVAILABLE',
          source: SOURCE,
          isTestData: true,
          createdAt: at(date, '05:30'),
          updatedAt: FieldValue.serverTimestamp(),
        }),
      );
      slotsCreated += 1;
    }
  }
}

await assertOnlySeedDocumentsWillChange(documents);
const authPlan = await inspectPatientAuthUsers(patients);

if (APPLY) {
  await createMissingAuthUsers(authPlan, PATIENT_PASSWORD);
  await writeInBatches(documents);
}

if (APPLY || VERIFY) {
  await verifySeedData();
}

console.table([
  { item: 'Project', value: PROJECT_ID },
  { item: 'Date range (Asia/Ho_Chi_Minh)', value: `${START_DATE} → ${END_DATE}` },
  { item: 'Active specialties', value: activeSpecialties.size },
  { item: 'Doctors per specialty limit', value: DOCTORS_PER_SPECIALTY },
  { item: 'Operational doctors selected', value: doctors.length },
  { item: 'Synthetic patient accounts', value: patients.length },
  { item: 'Firebase Auth users to create', value: authPlan.toCreate.length },
  { item: 'Existing schedules preserved', value: schedulesSkippedForExistingData },
  { item: 'Work schedules to write', value: schedulesCreated },
  { item: 'Time slots to write', value: slotsCreated },
  { item: 'Appointments to write', value: appointmentsCreated },
  { item: 'Firestore documents to write', value: documents.length },
]);
console.log(
  APPLY
    ? 'Operational sample data was written. Only documents labelled with this seed source were changed.'
    : VERIFY
    ? 'Verification completed without changing Firebase Auth or Firestore.'
    : 'Dry run completed. No Firebase Auth user or Firestore document was changed.',
);

function argumentValue(name) {
  const argument = process.argv.find((value) => value.startsWith(`${name}=`));
  return argument?.slice(name.length + 1).trim() ?? '';
}

function isDateString(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function document(collection, id, data) {
  return { reference: firestore.collection(collection).doc(id), data };
}

function stringValue(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function isActive(value) {
  const status = stringValue(value.status).toUpperCase();
  return value.isActive !== false &&
      !new Set(['INACTIVE', 'DISABLED', 'FALSE', '0']).has(status);
}

function isOperationalDoctor(id, value) {
  return isActive(value) &&
      !/^(mock_|sample_|seed_range_)/.test(id) &&
      stringValue(value.specialtyId) !== '';
}

function specialtyName(value, fallback) {
  const name = value.name ?? value.TenChuyenKhoa;
  return stringValue(name) || fallback;
}

function dateRange(start, end) {
  const values = [];
  for (let date = start; date <= end; date = addVietnamDays(date, 1)) {
    values.push(date);
  }
  return values;
}

function addVietnamDays(date, offset) {
  const value = new Date(`${date}T00:00:00+07:00`);
  value.setUTCDate(value.getUTCDate() + offset);
  return vietnamDateString(value);
}

function vietnamDateString(value) {
  if (!value) return '';
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

function toDate(value) {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function at(date, time) {
  return Timestamp.fromDate(new Date(`${date}T${time}:00+07:00`));
}

function isDoctorWorking(date, doctorIndex) {
  const weekday = new Date(`${date}T00:00:00+07:00`).getUTCDay();
  if (weekday === 0) return false; // Sunday is closed.
  const weeklyDayOff = (doctorIndex % 5) + 1; // A different Mon–Fri day off.
  return weekday !== weeklyDayOff;
}

function slotPlansForDate() {
  return [
    ['06:30', '07:30'],
    ['07:30', '08:30'],
    ['08:30', '09:30'],
    ['09:30', '10:30'],
    ['10:30', '11:30'],
    ['13:00', '14:00'],
    ['14:00', '15:00'],
    ['15:00', '16:00'],
  ].map(([startTime, endTime]) => ({ startTime, endTime }));
}

function placesForSlot(date, slotIndex) {
  if (date === '2026-10-17') {
    // The live doctor dashboard therefore reports 12 booked, 7 completed and
    // 5 waiting patients for every seeded doctor on 17 October.
    return [3, 3, 1, 0, 0, 3, 2, 0][slotIndex];
  }
  if (date < '2026-10-17') {
    return [2, 2, 1, 1, 0, 1, 0, 0][slotIndex];
  }
  return [1, 1, 1, 0, 0, 1, 0, 0][slotIndex];
}

function appointmentStatus(date, slotIndex, place) {
  if (date < '2026-10-17') {
    return slotIndex === 3 && place === 0 && Number(date.slice(-2)) % 3 === 0
        ? 'NO_SHOW'
        : 'COMPLETED';
  }
  if (date === '2026-10-17') {
    return slotIndex <= 2 ? 'COMPLETED' : 'CONFIRMED';
  }
  return slotIndex % 2 === 0 ? 'PENDING' : 'CONFIRMED';
}

function bookedAt(date, doctorIndex, slotIndex, place) {
  const daysBefore = 2 + ((doctorIndex + slotIndex + place) % 6);
  return at(addVietnamDays(date, -daysBefore), '09:00');
}

function checkInAt(date, startTime, place) {
  const [hour, minute] = startTime.split(':').map(Number);
  const checkIn = new Date(`${date}T${startTime}:00+07:00`);
  checkIn.setUTCMinutes(checkIn.getUTCMinutes() - 10 + place * 3);
  // The local variables make malformed time values fail loudly during future
  // edits instead of quietly producing an invalid Timestamp.
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) {
    throw new Error(`Invalid slot time ${startTime}.`);
  }
  return Timestamp.fromDate(checkIn);
}

function visitReason(specialty, sequence) {
  const label = specialty.toLowerCase();
  if (label.includes('tim')) return sequence % 2 === 0 ? 'Tái khám tăng huyết áp' : 'Theo dõi rối loạn nhịp tim';
  if (label.includes('thần') || label.includes('than')) return 'Đau đầu và chóng mặt tái diễn';
  if (label.includes('da')) return 'Tái khám tình trạng da liễu';
  if (label.includes('nhi')) return 'Khám sức khỏe định kỳ cho trẻ';
  if (label.includes('sản') || label.includes('san')) return 'Khám phụ khoa định kỳ';
  if (label.includes('mắt') || label.includes('mat')) return 'Kiểm tra thị lực định kỳ';
  if (label.includes('tai') || label.includes('mũi') || label.includes('mui')) return 'Khám tai mũi họng';
  return 'Khám và tư vấn sức khỏe theo chuyên khoa';
}

function visitSymptoms(specialty, sequence) {
  const suffix = sequence % 2 === 0 ? 'triệu chứng ổn định' : 'cần được bác sĩ đánh giá';
  return `${specialty}: ${suffix}.`;
}

function safeId(value) {
  return value.replaceAll(/[^A-Za-z0-9_-]/g, '_');
}

function buildPatients(count) {
  const familyNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Võ', 'Đặng', 'Bùi'];
  const givenNames = [
    'Minh Anh', 'Quốc Bảo', 'Thu Hà', 'Gia Hân', 'Đức Minh', 'Khánh Linh',
    'Hoàng Nam', 'Ngọc Mai', 'Thanh Tâm', 'Anh Khoa', 'Bảo Ngân', 'Phương Vy',
  ];
  return Array.from({ length: count }, (_, index) => {
    const ordinal = index + 1;
    const code = String(ordinal).padStart(3, '0');
    return {
      id: `seed_hospital_2026_patient_${code}`,
      authUserId: `seed_hospital_2026_user_${code}`,
      email: `seed.benhnhan.${code}@bookinghospitalapp.local`,
      fullName: `${familyNames[index % familyNames.length]} ${givenNames[index % givenNames.length]}`,
      phone: `090${String(1000000 + ordinal).slice(-7)}`,
      gender: index % 2 === 0 ? 'Nữ' : 'Nam',
      dateOfBirth: at(`${1970 + (index % 31)}-${String((index % 12) + 1).padStart(2, '0')}-${String((index % 27) + 1).padStart(2, '0')}`, '00:00'),
      address: `Địa chỉ mẫu ${code}, TP. Hồ Chí Minh`,
      insuranceNumber: `DN${String(2600000000 + ordinal)}`,
    };
  });
}

function accountDocument(patient) {
  return {
    email: patient.email,
    fullName: patient.fullName,
    phone: patient.phone,
    role: 'patient',
    accountKey: patient.authUserId,
    permission: 'PATIENT',
    status: 'ACTIVE',
    isActive: true,
    source: SOURCE,
    isTestData: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function patientDocument(patient) {
  return {
    authUserId: patient.authUserId,
    email: patient.email,
    fullName: patient.fullName,
    phone: patient.phone,
    dateOfBirth: patient.dateOfBirth,
    gender: patient.gender,
    address: patient.address,
    insuranceNumber: patient.insuranceNumber,
    isActive: true,
    status: 'ACTIVE',
    source: SOURCE,
    isTestData: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function assertOnlySeedDocumentsWillChange(records) {
  for (const references of chunks(records.map((record) => record.reference), 300)) {
    const snapshots = await firestore.getAll(...references);
    const conflicts = snapshots.filter(
      (snapshot) => snapshot.exists && snapshot.data().source !== SOURCE,
    );
    if (conflicts.length > 0) {
      throw new Error(
        `Refusing to overwrite documents from another source: ${conflicts
            .slice(0, 5)
            .map((snapshot) => snapshot.ref.path)
            .join(', ')}`,
      );
    }
  }
}

async function inspectPatientAuthUsers(seedPatients) {
  const existing = [];
  const toCreate = [];
  for (const group of chunks(seedPatients, 12)) {
    const results = await Promise.all(
      group.map(async (patient) => {
        try {
          const user = await auth.getUser(patient.authUserId);
          if (user.email?.toLowerCase() !== patient.email.toLowerCase()) {
            throw new Error(
              `Auth UID ${patient.authUserId} belongs to a different email.`,
            );
          }
          return { patient, exists: true };
        } catch (error) {
          if (error?.code !== 'auth/user-not-found') throw error;
          try {
            const userWithEmail = await auth.getUserByEmail(patient.email);
            throw new Error(
              `Email ${patient.email} is already linked to Auth UID ${userWithEmail.uid}.`,
            );
          } catch (emailError) {
            if (emailError?.code !== 'auth/user-not-found') throw emailError;
            return { patient, exists: false };
          }
        }
      }),
    );
    for (const result of results) {
      (result.exists ? existing : toCreate).push(result.patient);
    }
  }
  return { existing, toCreate };
}

async function createMissingAuthUsers(authPlan, password) {
  for (const group of chunks(authPlan.toCreate, 20)) {
    await Promise.all(
      group.map((patient) =>
        auth.createUser({
          uid: patient.authUserId,
          email: patient.email,
          password,
          displayName: patient.fullName,
          phoneNumber: undefined,
          disabled: false,
        }),
      ),
    );
  }
}

async function writeInBatches(records) {
  for (const group of chunks(records, 400)) {
    const batch = firestore.batch();
    for (const record of group) {
      batch.set(record.reference, record.data, { merge: false });
    }
    await batch.commit();
  }
}

async function verifySeedData() {
  const [accountsSnapshot, patientsSnapshot, schedulesSnapshot, slotsSnapshot,
    appointmentsSnapshot] = await Promise.all([
    firestore.collection('TAI_KHOAN').where('source', '==', SOURCE).get(),
    firestore.collection('BENH_NHAN').where('source', '==', SOURCE).get(),
    firestore.collection('LICH_LAM_VIEC').where('source', '==', SOURCE).get(),
    firestore.collection('CA_KHAM').where('source', '==', SOURCE).get(),
    firestore.collection('LICH_HEN').where('source', '==', SOURCE).get(),
  ]);
  const accounts = new Map(accountsSnapshot.docs.map((entry) => [entry.id, entry.data()]));
  const patients = new Map(patientsSnapshot.docs.map((entry) => [entry.id, entry.data()]));
  const schedules = new Map(schedulesSnapshot.docs.map((entry) => [entry.id, entry.data()]));
  const slots = new Map(slotsSnapshot.docs.map((entry) => [entry.id, entry.data()]));
  const appointments = new Map(
    appointmentsSnapshot.docs.map((entry) => [entry.id, entry.data()]),
  );
  const findings = [];

  for (const [patientId, patient] of patients) {
    const account = accounts.get(patient.authUserId);
    if (!account || account.role !== 'patient' || account.email !== patient.email) {
      findings.push(`Patient ${patientId} does not have its matching patient account.`);
    }
  }
  for (const [slotId, slot] of slots) {
    const schedule = schedules.get(slot.workScheduleId);
    const reservationCounts = slot.reservationCounts;
    const reserved = reservationCounts && typeof reservationCounts === 'object'
        ? Object.values(reservationCounts).reduce(
          (sum, value) => sum + (Number.isInteger(value) ? value : 0),
          0,
        )
        : -1;
    if (!schedule || schedule.doctorId !== slot.doctorId) {
      findings.push(`Slot ${slotId} does not match its work schedule.`);
    }
    if (!Number.isInteger(slot.capacity) || !Number.isInteger(slot.bookedCount) ||
        slot.capacity < 1 || slot.bookedCount < 0 || slot.bookedCount > slot.capacity) {
      findings.push(`Slot ${slotId} has an invalid capacity or booked count.`);
    }
    if (reserved !== slot.bookedCount) {
      findings.push(`Slot ${slotId} has a reservation count mismatch.`);
    }
    const expectedStatus = slot.bookedCount === slot.capacity ? 'BOOKED' : 'AVAILABLE';
    if (slot.status !== expectedStatus) {
      findings.push(`Slot ${slotId} has status ${slot.status}, expected ${expectedStatus}.`);
    }
  }
  for (const [appointmentId, appointment] of appointments) {
    const patient = patients.get(appointment.patientId);
    const schedule = schedules.get(appointment.workScheduleId);
    const slot = slots.get(appointment.timeSlotId);
    if (!patient || !schedule || !slot || schedule.doctorId !== appointment.doctorId ||
        slot.doctorId !== appointment.doctorId ||
        slot.workScheduleId !== appointment.workScheduleId ||
        slot.reservationCounts?.[appointmentId] !== appointment.peopleCount) {
      findings.push(`Appointment ${appointmentId} has an invalid relationship.`);
    }
  }
  console.table([
    { item: 'Seed accounts verified', value: accounts.size },
    { item: 'Seed patients verified', value: patients.size },
    { item: 'Seed work schedules verified', value: schedules.size },
    { item: 'Seed time slots verified', value: slots.size },
    { item: 'Seed appointments verified', value: appointments.size },
    { item: 'Relationship findings', value: findings.length },
  ]);
  if (findings.length > 0) {
    throw new Error(`Seed verification failed: ${findings.slice(0, 5).join(' ')}`);
  }
}

function* chunks(values, size) {
  for (let start = 0; start < values.length; start += size) {
    yield values.slice(start, start + size);
  }
}
