const firebaseJwksUrl = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const googleTokenUrl = 'https://oauth2.googleapis.com/token';
const cloudPlatformScope = 'https://www.googleapis.com/auth/cloud-platform';
const maxBodyBytes = 30_000;

let signingKeyCache = { expiresAt: 0, values: [] };
let serviceTokenCache = { expiresAt: 0, value: '' };

export default {
  async fetch(request, env) {
    const headers = corsHeaders(request, env);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
    if (request.method === 'GET' && new URL(request.url).pathname === '/health') {
      try {
        const credentials = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON, env.FIREBASE_PROJECT_ID);
        await serviceAccessToken(credentials);
        return json({ service: 'healway-admin-command', configured: true }, 200, headers);
      } catch (_) {
        return json({ service: 'healway-admin-command', configured: false }, 503, headers);
      }
    }
    const url = new URL(request.url);
    if (url.pathname.startsWith('/doctor/')) {
      try {
        const session = await authenticatedUser(request, env.FIREBASE_PROJECT_ID);
        const firestore = new FirestoreRest(env);
        const result = await doctorWorkspaceRequest(request, url, session.uid, firestore);
        return json(result, 200, headers);
      } catch (error) {
        const status = error instanceof HttpError ? error.status : 500;
        if (!(error instanceof HttpError)) console.error('doctor workspace worker failed');
        return json({ error: { message: error instanceof HttpError ? error.message : 'Không thể hoàn tất yêu cầu bác sĩ.' } }, status, headers);
      }
    }
    if (request.method !== 'POST' || url.pathname !== '/adminCommand') {
      return json({ error: { message: 'Không tìm thấy dịch vụ.' } }, 404, headers);
    }
    try {
      const session = await authenticatedUser(request, env.FIREBASE_PROJECT_ID);
      const firestore = new FirestoreRest(env);
      const command = await commandInput(request);
      // Patient booking is deliberately the only non-admin command.  It is
      // still authenticated and its ownership checks run again *inside* the
      // Firestore transaction below; this is not a generic client write API.
      const result = patientCommandOperation(command.operation)
        ? await executePatientBooking(command, session.uid, firestore)
        : await (async () => {
            await requireActiveAdmin(session.uid, firestore);
            return executeCommand(command, session.uid, firestore);
          })();
      return json({ result }, 200, headers);
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      if (!(error instanceof HttpError)) console.error('admin command worker failed');
      return json({ error: { message: error instanceof HttpError ? error.message : 'Không thể hoàn tất thao tác.' } }, status, headers);
    }
  },
};

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

async function commandInput(request) {
  const length = Number(request.headers.get('content-length') || 0);
  if (length > maxBodyBytes) throw new HttpError(400, 'Yêu cầu quá lớn.');
  let value;
  try { value = await request.json(); } catch (_) { throw new HttpError(400, 'Yêu cầu không hợp lệ.'); }
  if (!value || typeof value !== 'object' || Array.isArray(value) || JSON.stringify(value).length > maxBodyBytes) {
    throw new HttpError(400, 'Yêu cầu không hợp lệ.');
  }
  requiredId(value.requestId, 'Mã yêu cầu');
  const operation = requiredText(value.operation, 'Thao tác', 60);
  requiredText(value.reason, 'Lý do', 500);
  return { ...value, operation };
}

/**
 * This dispatcher is deliberately fail-closed. A command can only be enabled
 * after its full validation and transaction have been ported from
 * functions/src/commands.js. There is no generic "write any document" route.
 */
async function executeCommand(command, uid, firestore) {
  if (command.operation === 'createDoctor') return provisionDoctor(command, uid, firestore);
  const fingerprint = await commandDigest(command);
  return firestore.runTransaction(async (tx) => {
    const receiptPath = `ADMIN_COMMANDS/${uid}_${command.requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.fingerprint !== fingerprint) throw new HttpError(409, 'Mã yêu cầu đã được dùng cho nội dung khác.');
      return receipt.result;
    }
    const context = new AdminCommandContext(tx, uid, command);
    const result = await context.execute();
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    return result;
  });
}

/**
 * A patient needs the same all-or-nothing reservation as the old client
 * transaction, but no client is allowed to bypass Firestore Rules for it.
 * Keep a separate idempotency receipt namespace so a patient request can
 * never collide with an administrator command that happens to use the same
 * request id.
 */
async function executePatientBooking(command, uid, firestore) {
  if (!patientCommandOperation(command.operation)) {
    throw new HttpError(403, 'Tài khoản bệnh nhân không được thực hiện thao tác này.');
  }
  const fingerprint = await commandDigest(command);
  return firestore.runTransaction(async (tx) => {
    const receiptPath = `PATIENT_COMMANDS/${uid}_${command.requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) {
        throw new HttpError(409, 'Mã yêu cầu đã được dùng cho nội dung khác.');
      }
      return receipt.data.result;
    }
    const context = new AdminCommandContext(tx, uid, command, { patientCommand: true });
    const result = await context.executePatientCommand();
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    return result;
  });
}

function patientCommandOperation(operation) {
  return ['patientBook', 'patientCancel', 'patientReschedule'].includes(operation);
}

/**
 * Doctor screens read a deliberately narrow server projection.  In particular,
 * this is the only path that returns a patient's name/year/gender to a doctor;
 * the mobile client never gets unrestricted access to BENH_NHAN.
 */
async function doctorWorkspaceRequest(request, url, uid, firestore) {
  if (url.pathname === '/doctor/day' && request.method === 'GET') {
    const date = parseWorkDate(url.searchParams.get('date'));
    return firestore.readTransaction(async (tx) => {
      const doctor = await activeDoctor(tx, uid);
      return doctorDay(tx, doctor, date);
    });
  }
  if (url.pathname === '/doctor/reports' && request.method === 'GET') {
    return firestore.readTransaction(async (tx) => {
      const doctor = await activeDoctor(tx, uid);
      const reports = await tx.query('BAO_CAO_BAC_SI', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
      return { reports: reports.map((row) => doctorReportJson(row.id, row.data)).sort((a, b) => b.date.localeCompare(a.date) || b.id.localeCompare(a.id)) };
    });
  }
  if (url.pathname === '/doctor/reports' && request.method === 'POST') {
    return submitDoctorReport(request, uid, firestore);
  }
  if (url.pathname === '/doctor/health-records' && request.method === 'POST') {
    return saveClinicalRecord(request, uid, firestore, 'health');
  }
  if (url.pathname === '/doctor/health-records' && request.method === 'GET') {
    return clinicalRecordsForAppointment(url, uid, firestore, 'health');
  }
  if (url.pathname === '/doctor/test-results' && request.method === 'POST') {
    return saveClinicalRecord(request, uid, firestore, 'result');
  }
  if (url.pathname === '/doctor/test-results' && request.method === 'GET') {
    return clinicalRecordsForAppointment(url, uid, firestore, 'result');
  }
  throw new HttpError(404, 'Không tìm thấy dịch vụ bác sĩ.');
}

async function activeDoctor(tx, uid) {
  const account = await tx.get(`TAI_KHOAN/${uid}`);
  if (!account || account.data.role !== 'doctor' || account.data.isActive !== true ||
      !['ACTIVE', 'APPROVED'].includes(account.data.status)) {
    throw new HttpError(403, 'Tài khoản bác sĩ không còn hoạt động.');
  }
  const profiles = await tx.query('BAC_SI', [{ field: 'userId', op: 'EQUAL', value: uid }], 2);
  if (profiles.length !== 1) throw new HttpError(403, 'Không tìm thấy hồ sơ bác sĩ hợp lệ.');
  const doctor = { id: profiles[0].id, ...profiles[0].data };
  if (doctor.isActive === false || doctor.status !== 'ACTIVE') {
    throw new HttpError(403, 'Hồ sơ bác sĩ không còn hoạt động.');
  }
  return doctor;
}

async function doctorDay(tx, doctor, date) {
  const key = dayKey(date);
  const scheduleRows = await tx.query('LICH_LAM_VIEC', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
  const schedules = scheduleRows
    .filter((row) => dayKey(row.data.workDate) === key)
    .map((row) => scheduleJson(row.id, row.data));
  const scheduleIds = new Set(schedules.map((row) => row.id));
  const slotRows = await tx.query('CA_KHAM', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
  const slots = slotRows
    .filter((row) => scheduleIds.has(row.data.workScheduleId))
    .map((row) => slotJson(row.id, row.data));
  const appointmentRows = await tx.query('LICH_HEN', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
  const appointments = appointmentRows.filter((row) =>
    scheduleIds.has(row.data.workScheduleId) && dayKey(row.data.appointmentDate) === key,
  );
  const patients = new Map();
  for (const row of appointments) {
    const patientId = requiredId(row.data.patientId, 'Hồ sơ bệnh nhân');
    if (!patients.has(patientId)) patients.set(patientId, await tx.get(`BENH_NHAN/${patientId}`));
  }
  const bookings = appointments.map((row) => {
    const patient = patients.get(row.data.patientId)?.data || {};
    return {
      appointment: appointmentJson(row.id, row.data),
      patientName: typeof patient.fullName === 'string' && patient.fullName.trim() ? patient.fullName.trim() : 'Bệnh nhân',
      ...(birthYear(patient.dateOfBirth) == null ? {} : { birthYear: birthYear(patient.dateOfBirth) }),
      ...(typeof patient.gender === 'string' && patient.gender.trim() ? { gender: patient.gender.trim() } : {}),
    };
  });
  return { doctor: doctorJson(doctor), schedules, slots, bookings };
}

async function submitDoctorReport(request, uid, firestore) {
  const length = Number(request.headers.get('content-length') || 0);
  if (length > maxBodyBytes) throw new HttpError(400, 'Yêu cầu quá lớn.');
  let body;
  try { body = await request.json(); } catch (_) { throw new HttpError(400, 'Nội dung báo cáo không hợp lệ.'); }
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new HttpError(400, 'Nội dung báo cáo không hợp lệ.');
  const requestId = requiredId(request.headers.get('Idempotency-Key'), 'Mã chống trùng');
  const input = {
    type: choice(body.type, ['Bận đột xuất', 'Sự cố lịch làm', 'Khác'], 'Loại báo cáo'),
    scheduleId: requiredId(body.scheduleId, 'Mã lịch làm việc'),
    date: parseWorkDate(body.date),
    reason: requiredText(body.reason, 'Lý do', 200),
    description: requiredText(body.description, 'Mô tả', 1000),
  };
  const fingerprint = await commandDigest({ requestId, ...input, date: dayKey(input.date) });
  return firestore.runTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const receiptPath = `DOCTOR_REPORT_COMMANDS/${doctor.id}_${requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã chống trùng đã được dùng cho nội dung khác.');
      return receipt.data.result;
    }
    const schedule = await tx.get(`LICH_LAM_VIEC/${input.scheduleId}`);
    if (!schedule || schedule.data.doctorId !== doctor.id || dayKey(schedule.data.workDate) !== dayKey(input.date)) {
      throw new HttpError(403, 'Lịch làm việc không thuộc bác sĩ hoặc không đúng ngày báo cáo.');
    }
    const id = `${doctor.id}_${requestId}`;
    const result = { id, type: input.type, date: dayKey(input.date), reason: input.reason, status: 'PENDING', adminResponse: null };
    tx.create(`BAO_CAO_BAC_SI/${id}`, {
      doctorId: doctor.id, scheduleId: input.scheduleId, date: input.date, type: input.type,
      reason: input.reason, description: input.description, status: 'PENDING',
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    return result;
  });
}

// Clinical documents are server commands, not generic Firestore writes. This
// keeps the appointment/patient/doctor linkage immutable and takes the date
// from Firestore's server clock rather than the doctor's device.
async function saveClinicalRecord(request, uid, firestore, kind) {
  const body = await doctorJsonBody(request);
  const requestId = requiredId(request.headers.get('Idempotency-Key'), 'Mã chống trùng');
  const appointmentId = requiredId(body.appointmentId, 'Mã lịch hẹn');
  const id = body.id == null || body.id === '' ? null : requiredId(body.id, 'Mã hồ sơ');
  const values = kind === 'health' ? {
    diagnosis: requiredText(body.diagnosis, 'Chẩn đoán', 1000),
    notes: optionalText(body.notes, 4000), prescription: optionalText(body.prescription, 4000),
    recordType: choice(body.recordType || 'OUTPATIENT', ['OUTPATIENT', 'INPATIENT', 'CHECKUP'], 'Loại hồ sơ'),
    documentCategory: body.documentCategory == null || body.documentCategory === '' ? null : choice(body.documentCategory, ['PRESCRIPTION', 'ORDER', 'CERTIFICATE'], 'Loại giấy tờ'),
  } : {
    testName: requiredText(body.testName, 'Tên xét nghiệm', 300),
    resultDescription: requiredText(body.resultDescription, 'Kết quả', 4000),
    resultType: optionalText(body.resultType, 120) || 'Khác', conclusion: optionalText(body.conclusion, 2000),
    referenceRange: optionalText(body.referenceRange, 500),
  };
  const fingerprint = await commandDigest({ kind, id, appointmentId, values });
  return firestore.runTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const receiptPath = `DOCTOR_CLINICAL_COMMANDS/${doctor.id}_${requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã chống trùng đã được dùng cho nội dung khác.');
      return receipt.data.result;
    }
    const appointment = await doctorAppointment(tx, doctor.id, appointmentId);
    const collection = kind === 'health' ? 'HO_SO_SUC_KHOE' : 'KET_QUA_CLS';
    const documentId = id || `${doctor.id}_${requestId}`;
    const path = `${collection}/${documentId}`;
    const existing = await tx.get(path);
    if (existing && (existing.data.doctorId !== doctor.id || existing.data.patientId !== appointment.patientId || existing.data.appointmentId !== appointmentId)) {
      throw new HttpError(403, 'Không được sửa hồ sơ của lịch khám khác.');
    }
    const fields = {
      patientId: appointment.patientId, doctorId: doctor.id, appointmentId,
      ...values,
      ...(kind === 'health'
        ? (existing ? {} : { recordDate: serverTimestamp() })
        : { ...(existing ? {} : { testDate: serverTimestamp() }), doctorName: textOrEmpty(doctor.fullName) }),
      updatedAt: serverTimestamp(),
    };
    if (existing) tx.update(path, fields);
    else tx.create(path, { ...fields, createdAt: serverTimestamp() });
    const result = { id: documentId, collection, appointmentId, message: existing ? 'Đã cập nhật hồ sơ y tế.' : 'Đã tạo hồ sơ y tế.' };
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    tx.create(`NHAT_KY_Y_TE/${doctor.id}_${requestId}`, {
      actorId: uid, doctorId: doctor.id, action: existing ? `update_${kind}` : `create_${kind}`,
      collection, targetId: documentId, appointmentId, patientId: appointment.patientId,
      createdAt: serverTimestamp(),
    });
    return result;
  });
}

async function doctorJsonBody(request) {
  const length = Number(request.headers.get('content-length') || 0);
  if (length > maxBodyBytes) throw new HttpError(400, 'Yêu cầu quá lớn.');
  let body;
  try { body = await request.json(); } catch (_) { throw new HttpError(400, 'Nội dung hồ sơ không hợp lệ.'); }
  if (!body || typeof body !== 'object' || Array.isArray(body) || JSON.stringify(body).length > maxBodyBytes) {
    throw new HttpError(400, 'Nội dung hồ sơ không hợp lệ.');
  }
  return body;
}

async function doctorAppointment(tx, doctorId, appointmentId) {
  const appointment = await tx.get(`LICH_HEN/${appointmentId}`);
  if (!appointment || appointment.data.doctorId !== doctorId ||
      !['CONFIRMED', 'COMPLETED'].includes(appointment.data.status) ||
      typeof appointment.data.patientId !== 'string') {
    throw new HttpError(403, 'Chỉ được ghi hồ sơ cho lịch khám đã xác nhận hoặc hoàn tất của chính bác sĩ.');
  }
  return appointment.data;
}

async function clinicalRecordsForAppointment(url, uid, firestore, kind) {
  const appointmentId = requiredId(url.searchParams.get('appointmentId'), 'Mã lịch hẹn');
  return firestore.readTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    await doctorAppointment(tx, doctor.id, appointmentId);
    const collection = kind === 'health' ? 'HO_SO_SUC_KHOE' : 'KET_QUA_CLS';
    const rows = await tx.query(collection, [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
    const records = rows
      .filter((row) => row.data.appointmentId === appointmentId)
      .map((row) => kind === 'health'
        ? { id: row.id, diagnosis: textOrEmpty(row.data.diagnosis), notes: textOrEmpty(row.data.notes), prescription: textOrEmpty(row.data.prescription), recordType: textOrEmpty(row.data.recordType) || 'OUTPATIENT' }
        : { id: row.id, testName: textOrEmpty(row.data.testName), resultDescription: textOrEmpty(row.data.resultDescription), resultType: textOrEmpty(row.data.resultType) || 'Khác', conclusion: textOrEmpty(row.data.conclusion), referenceRange: textOrEmpty(row.data.referenceRange) })
      .sort((left, right) => left.id.localeCompare(right.id));
    return { records };
  });
}

function doctorJson(data) {
  return {
    id: data.id, userId: data.userId, fullName: textOrEmpty(data.fullName), email: textOrEmpty(data.email), phone: textOrEmpty(data.phone),
    specialtyId: textOrEmpty(data.specialtyId), specialtyName: textOrEmpty(data.specialtyName), qualification: textOrEmpty(data.qualification),
    yearsOfExperience: numberOrZero(data.yearsOfExperience), consultationFee: numberOrZero(data.consultationFee),
    isActive: data.isActive !== false, status: textOrEmpty(data.status) || 'ACTIVE', avatarUrl: textOrEmpty(data.avatarUrl),
  };
}
function scheduleJson(id, data) { return { id, doctorId: textOrEmpty(data.doctorId), workDate: dayKey(data.workDate), startTime: textOrEmpty(data.startTime), endTime: textOrEmpty(data.endTime), status: textOrEmpty(data.status) || 'ACTIVE' }; }
function slotJson(id, data) { return { id, workScheduleId: textOrEmpty(data.workScheduleId), doctorId: textOrEmpty(data.doctorId), startTime: textOrEmpty(data.startTime), endTime: textOrEmpty(data.endTime), status: textOrEmpty(data.status), capacity: numberOrZero(data.capacity), bookedCount: numberOrZero(data.bookedCount) }; }
function appointmentJson(id, data) { return { id, patientId: textOrEmpty(data.patientId), doctorId: textOrEmpty(data.doctorId), workScheduleId: textOrEmpty(data.workScheduleId), timeSlotId: textOrEmpty(data.timeSlotId), specialtyId: textOrEmpty(data.specialtyId), appointmentDate: dayKey(data.appointmentDate), startTime: textOrEmpty(data.startTime), endTime: textOrEmpty(data.endTime), status: textOrEmpty(data.status), peopleCount: numberOrZero(data.peopleCount) || 1, ...(typeof data.queueNumber === 'number' ? { queueNumber: data.queueNumber } : {}), ...(typeof data.reason === 'string' ? { reason: data.reason } : {}) }; }
function doctorReportJson(id, data) { return { id, type: textOrEmpty(data.type), date: dayKey(data.date), reason: textOrEmpty(data.reason), status: textOrEmpty(data.status) || 'PENDING', adminResponse: typeof data.adminResponse === 'string' ? data.adminResponse : null }; }
function textOrEmpty(value) { return typeof value === 'string' ? value : ''; }
function numberOrZero(value) { return typeof value === 'number' && Number.isFinite(value) ? value : 0; }
function birthYear(value) { const date = value instanceof Date ? value : new Date(value); return Number.isFinite(date.getTime()) ? Number(dayKey(date).slice(0, 4)) : null; }

/** Auth creation cannot share Firestore's transaction. A durable provisioning
 * record makes the boundary recoverable and prevents a retry from silently
 * creating another doctor account. */
async function provisionDoctor(command, uid, firestore) {
  const values = objectValue(command.values);
  const loginEmail = validEmail(values.loginEmail);
  const fields = cleanDoctorFields(values);
  const fingerprint = await commandDigest(command);
  const receiptPath = `ADMIN_COMMANDS/${uid}_${command.requestId}`;
  const provisioningPath = `ADMIN_PROVISIONING/${command.requestId}`;
  const initial = await firestore.runTransaction(async (tx) => {
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã yêu cầu đã được dùng cho nội dung khác.');
      return { completed: receipt.data.result };
    }
    const specialty = await tx.get(`CHUYEN_KHOA/${fields.specialtyId}`);
    if (!specialty) throw new HttpError(404, 'Chuyên khoa không còn tồn tại.');
    active(specialty.data, 'Chuyên khoa');
    const existing = await tx.get(provisioningPath);
    if (existing && (existing.data.status !== 'FAILED' || existing.data.fingerprint !== fingerprint || existing.data.actorId !== uid)) {
      throw new HttpError(409, 'Yêu cầu đang xử lý hoặc cần kiểm tra mục cấp tài khoản. Không gửi lại bằng yêu cầu mới.');
    }
    if (existing) tx.update(provisioningPath, { status: 'CREATING', updatedAt: serverTimestamp() });
    else tx.create(provisioningPath, { actorId: uid, fingerprint, loginEmail, status: 'CREATING', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    return { completed: null };
  });
  if (initial.completed) return initial.completed;

  let authUserId = null;
  try {
    authUserId = await firestore.createAuthUser(loginEmail, fields.fullName);
    await firestore.runTransaction(async (tx) => {
      const specialty = await tx.get(`CHUYEN_KHOA/${fields.specialtyId}`);
      if (!specialty) throw new HttpError(404, 'Chuyên khoa không còn tồn tại.');
      active(specialty.data, 'Chuyên khoa');
      const result = { id: authUserId, collection: 'BAC_SI', loginEmail, message: 'Đã tạo hồ sơ và tài khoản bác sĩ. Cần gửi email thiết lập mật khẩu.' };
      tx.create(`TAI_KHOAN/${authUserId}`, {
        email: loginEmail, fullName: fields.fullName, phone: fields.phone || '', role: 'doctor', isActive: true, status: 'ACTIVE',
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
      tx.create(`BAC_SI/${authUserId}`, {
        ...fields, userId: authUserId, acceptingBookings: true, status: 'ACTIVE', isActive: true,
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
      tx.create(`NHAT_KY_ADMIN/${command.requestId}`, {
        actorId: uid, action: 'createDoctor', targetCollection: 'BAC_SI', targetId: authUserId,
        reason: command.reason, before: null, after: { ...fields, loginEmail }, createdAt: serverTimestamp(),
      });
      tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
      tx.update(provisioningPath, { status: 'READY', authUserId, updatedAt: serverTimestamp() });
      return result;
    });
    const receipt = await firestore.get(receiptPath);
    if (!receipt?.result) throw new HttpError(503, 'Không thể xác minh kết quả cấp tài khoản.');
    return receipt.result;
  } catch (error) {
    const receipt = await firestore.get(receiptPath);
    if (receipt?.fingerprint === fingerprint && receipt.result) return receipt.result;
    let cleanupSucceeded = !authUserId;
    if (authUserId) cleanupSucceeded = await firestore.deleteAuthUser(authUserId);
    await firestore.runTransaction(async (tx) => {
      const current = await tx.get(provisioningPath);
      if (current) tx.update(provisioningPath, {
        status: cleanupSucceeded ? 'FAILED' : 'NEEDS_RECOVERY', ...(authUserId ? { authUserId } : {}),
        failureCode: error instanceof HttpError ? String(error.status) : 'unknown', updatedAt: serverTimestamp(),
      });
    });
    if (!cleanupSucceeded) throw new HttpError(409, 'Chưa tạo xong hồ sơ; cần kiểm tra ADMIN_PROVISIONING trước khi tạo lại.');
    throw error;
  }
}

class AdminCommandContext {
  constructor(tx, uid, command, { patientCommand = false } = {}) {
    Object.assign(this, { tx, uid, command, patientCommand });
  }

  async get(collection, id) {
    const snapshot = await this.tx.get(`${collection}/${requiredId(id)}`);
    if (!snapshot) throw new HttpError(404, 'Bản ghi không còn tồn tại.');
    return snapshot.data;
  }

  async rows(collection, field, value, limit = 300) {
    const docs = await this.tx.query(collection, [{ field, op: 'EQUAL', value }], limit + 1);
    if (docs.length > limit) throw new HttpError(409, 'Có quá nhiều bản ghi liên quan; cần chia nhỏ thao tác.');
    return docs;
  }

  reason() { return requiredText(this.command.reason, 'Lý do', 500); }

  audit(collection, id, before, after, action = this.command.operation) {
    // NHAT_KY_ADMIN is reserved for administrator activity. Patient booking
    // already has its appointment and automatic notification as its history.
    if (this.patientCommand) return;
    this.tx.create(`NHAT_KY_ADMIN/${this.command.requestId}`, {
      actorId: this.uid, targetCollection: collection, targetId: id, action,
      reason: this.command.reason, before: before || null, after: after || null,
      createdAt: serverTimestamp(),
    });
  }

  notification(key, patient, patientId, title, content, appointmentId = null) {
    this.tx.create(`THONG_BAO/${this.command.requestId}_${key}`, {
      title, content, patientId, userId: patient.authUserId || null, appointmentId,
      status: 'SENT', channel: 'in_app', isRead: false, createdAt: serverTimestamp(), createdBy: this.uid,
    });
  }

  updated(collection, id, before, changes) {
    this.tx.update(`${collection}/${id}`, { ...changes, updatedAt: serverTimestamp() });
    this.audit(collection, id, before, changes);
    return { id, collection, message: 'Đã cập nhật.' };
  }

  async execute() {
    switch (this.command.operation) {
      case 'healthCheck': return { message: 'Admin backend đã xác thực quyền thành công.' };
      case 'book': return this.book();
      case 'appointmentStatus': return this.appointmentStatus();
      case 'reschedule': return this.reschedule();
      case 'setAvailability': return this.setAvailability();
      case 'createSchedule': return this.createSchedule();
      case 'editSchedule': return this.editSchedule();
      case 'saveSlot': return this.saveSlot();
      case 'create': return this.create();
      case 'save': return this.save();
      case 'delete': return this.remove();
      case 'accountAccess': return this.accountAccess();
      case 'accountReview': return this.accountReview();
      case 'passwordSetup': return this.passwordSetup();
      case 'internalNote': return this.internalNote();
      case 'feedback': return this.feedback();
      case 'notificationDraft': return this.notificationDraft();
      case 'sendNotification': return this.sendNotification();
      case 'paymentReview': return this.paymentReview();
      case 'saveSettings': return this.saveSettings();
      case 'backfillSlotTimes': return this.backfillSlotTimes();
      default: throw new HttpError(501, `Thao tác ${this.command.operation} chưa được chuyển sang Worker an toàn.`);
    }
  }

  async executePatientCommand() {
    if (!this.patientCommand) throw new HttpError(403, 'Thao tác bệnh nhân không hợp lệ.');
    switch (this.command.operation) {
      case 'patientBook': return this.book();
      case 'patientCancel': return this.patientCancel();
      case 'patientReschedule': return this.patientReschedule();
      default: throw new HttpError(403, 'Tài khoản bệnh nhân không được thực hiện thao tác này.');
    }
  }

  async destination(slotId, peopleCount) {
    const slot = await this.get('CA_KHAM', slotId);
    const schedule = await this.get('LICH_LAM_VIEC', slot.workScheduleId);
    const doctor = await this.get('BAC_SI', slot.doctorId);
    const specialty = await this.get('CHUYEN_KHOA', doctor.specialtyId);
    active(schedule, 'Lịch làm việc'); active(doctor, 'Bác sĩ'); active(specialty, 'Chuyên khoa');
    if (slot.status !== 'AVAILABLE' || schedule.doctorId !== slot.doctorId ||
        timeMinutes(slot.startTime) < timeMinutes(schedule.startTime) || timeMinutes(slot.endTime) > timeMinutes(schedule.endTime)) {
      throw new HttpError(409, 'Ca khám đã đầy, tạm khóa hoặc sai liên kết.');
    }
    if (slotStart(schedule.workDate, slot.startTime) <= new Date()) throw new HttpError(409, 'Thời gian khám đã qua.');
    return { slot, schedule, doctor, counts: capacityChange(slot, peopleCount) };
  }

  async book() {
    const values = objectValue(this.command.values);
    const patientId = requiredId(values.patientId);
    const patient = await this.get('BENH_NHAN', patientId);
    if (this.patientCommand) await this.assertOwnActivePatient(patient, patientId);
    if (patient.isActive === false || patient.status === 'ARCHIVED') throw new HttpError(409, 'Hồ sơ bệnh nhân đang được lưu trữ.');
    const peopleCount = boundedNumber(values.peopleCount ?? 1, 'Số người', 1, 100, true);
    const slotId = requiredId(values.timeSlotId);
    const target = await this.destination(slotId, peopleCount);
    const id = this.command.requestId;
    const reason = optionalText(values.reason, 1000);
    const fields = {
      patientId, doctorId: target.slot.doctorId, workScheduleId: target.slot.workScheduleId,
      timeSlotId: slotId, specialtyId: target.doctor.specialtyId, appointmentDate: target.schedule.workDate,
      startTime: target.slot.startTime, endTime: target.slot.endTime, status: 'PENDING', peopleCount,
      reason, symptoms: reason,
      ...(Number.isFinite(target.doctor.consultationFee)
        ? { consultationFeeSnapshot: target.doctor.consultationFee }
        : {}),
      bookedAt: serverTimestamp(), createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    this.reason();
    const reservations = exactReservationCounts(
      target.slot,
      await this.rows('LICH_HEN', 'timeSlotId', slotId),
    );
    if (Object.hasOwn(reservations, id)) throw new HttpError(409, 'Ca khám đã có dữ liệu giữ chỗ trùng mã lịch.');
    reservations[id] = peopleCount;
    this.tx.create(`LICH_HEN/${id}`, fields);
    this.tx.update(`CA_KHAM/${slotId}`, {
      ...target.counts, appointmentId: id, reservationCounts: reservations,
      updatedAt: serverTimestamp(),
    });
    this.notification('book', patient, patientId, 'Đã tiếp nhận lịch khám', `Mã lịch ${id}. Lịch đang chờ xác nhận.`, id);
    this.audit('LICH_HEN', id, null, fields);
    return { id, collection: 'LICH_HEN', message: 'Đã tạo lịch hẹn và giữ chỗ.' };
  }

  async assertOwnActivePatient(patient, patientId) {
    const account = await this.get('TAI_KHOAN', this.uid);
    if (account.role !== 'patient' || account.isActive !== true ||
        !['ACTIVE', 'APPROVED'].includes(account.status)) {
      throw new HttpError(403, 'Tài khoản bệnh nhân không còn hoạt động.');
    }
    if (patient.authUserId !== this.uid || patientId !== requiredId(patientId, 'Hồ sơ bệnh nhân')) {
      throw new HttpError(403, 'Bạn chỉ được thao tác với hồ sơ của chính mình.');
    }
    if (patient.isActive === false || patient.status === 'ARCHIVED') {
      throw new HttpError(409, 'Hồ sơ bệnh nhân đang được lưu trữ.');
    }
  }

  async patientAppointment() {
    const id = requiredId(this.command.id, 'Mã lịch hẹn');
    const appointment = await this.get('LICH_HEN', id);
    const patient = await this.get('BENH_NHAN', appointment.patientId);
    await this.assertOwnActivePatient(patient, appointment.patientId);
    return { id, appointment, patient };
  }

  async patientCancel() {
    const { id, appointment, patient } = await this.patientAppointment();
    if (!['PENDING', 'CONFIRMED'].includes(appointment.status)) {
      throw new HttpError(409, 'Chỉ hủy được lịch đang chờ hoặc đã xác nhận.');
    }
    const reason = requiredText(objectValue(this.command.values).cancellationReason, 'Lý do hủy', 1000);
    const slot = await this.get('CA_KHAM', appointment.timeSlotId);
    const peopleCount = boundedNumber(appointment.peopleCount ?? 1, 'Số người', 1, 100, true);
    const others = await this.rows('LICH_HEN', 'timeSlotId', appointment.timeSlotId);
    const reservations = exactReservationCounts(slot, others);
    if (reservations[id] !== peopleCount) throw new HttpError(409, 'Dữ liệu giữ chỗ không nhất quán; không thể tự hủy lịch.');
    delete reservations[id];
    const pointer = others.find((item) => item.id !== id && heldStatus(item.data.status));
    this.tx.update(`LICH_HEN/${id}`, {
      status: 'CANCELLED', cancellationReason: reason, updatedAt: serverTimestamp(),
    });
    this.tx.update(`CA_KHAM/${appointment.timeSlotId}`, {
      ...capacityChange(slot, -peopleCount), appointmentId: pointer?.id ?? deleteField(),
      reservationCounts: reservations, updatedAt: serverTimestamp(),
    });
    this.notification('patient-cancel', patient, appointment.patientId,
      'Hủy lịch thành công', `Mã lịch ${id} đã được hủy. Khung giờ đã được giải phóng.`, id);
    return { id, collection: 'LICH_HEN', message: 'Đã hủy lịch hẹn và giải phóng chỗ.' };
  }

  async patientReschedule() {
    const { id, appointment, patient } = await this.patientAppointment();
    if (!['PENDING', 'CONFIRMED'].includes(appointment.status)) {
      throw new HttpError(409, 'Chỉ đổi được lịch chưa kết thúc.');
    }
    const slotId = requiredId(objectValue(this.command.values).timeSlotId, 'Ca khám mới');
    if (slotId === appointment.timeSlotId) throw new HttpError(400, 'Hãy chọn ca khám khác.');
    const oldSlot = await this.get('CA_KHAM', appointment.timeSlotId);
    const peopleCount = boundedNumber(appointment.peopleCount ?? 1, 'Số người', 1, 100, true);
    const target = await this.destination(slotId, peopleCount);
    if (target.slot.doctorId !== appointment.doctorId || target.doctor.specialtyId !== appointment.specialtyId) {
      throw new HttpError(409, 'Ca khám mới phải thuộc cùng bác sĩ và chuyên khoa.');
    }
    const others = await this.rows('LICH_HEN', 'timeSlotId', appointment.timeSlotId);
    const oldReservations = exactReservationCounts(oldSlot, others);
    if (oldReservations[id] !== peopleCount) {
      throw new HttpError(409, 'Dữ liệu giữ chỗ cũ không nhất quán; không thể đổi lịch.');
    }
    const newReservations = exactReservationCounts(
      target.slot,
      await this.rows('LICH_HEN', 'timeSlotId', slotId),
    );
    if (Object.hasOwn(newReservations, id)) throw new HttpError(409, 'Ca khám mới có dữ liệu giữ chỗ trùng mã lịch.');
    delete oldReservations[id];
    newReservations[id] = peopleCount;
    const pointer = others.find((item) => item.id !== id && heldStatus(item.data.status));
    this.tx.update(`CA_KHAM/${appointment.timeSlotId}`, {
      ...capacityChange(oldSlot, -peopleCount), appointmentId: pointer?.id ?? deleteField(),
      reservationCounts: oldReservations, updatedAt: serverTimestamp(),
    });
    this.tx.update(`CA_KHAM/${slotId}`, {
      ...target.counts, appointmentId: id, reservationCounts: newReservations,
      updatedAt: serverTimestamp(),
    });
    this.tx.update(`LICH_HEN/${id}`, {
      workScheduleId: target.slot.workScheduleId, timeSlotId: slotId,
      appointmentDate: target.schedule.workDate, startTime: target.slot.startTime,
      endTime: target.slot.endTime, status: 'PENDING', queueNumber: deleteField(),
      checkInTime: deleteField(), updatedAt: serverTimestamp(),
    });
    this.notification('patient-reschedule', patient, appointment.patientId,
      'Lịch khám đã thay đổi', `Mã lịch ${id}. Ngày ${dayKey(target.schedule.workDate)}, ${target.slot.startTime}.`, id);
    return { id, collection: 'LICH_HEN', message: 'Đã đổi lịch hẹn và cập nhật giữ chỗ.' };
  }

  async appointmentStatus() {
    const id = requiredId(this.command.id);
    const before = await this.get('LICH_HEN', id);
    const next = choice(objectValue(this.command.values).status, ['CONFIRMED', 'CANCELLED', 'NO_SHOW'], 'Trạng thái');
    appointmentTransition(before.status, next);
    this.reason();
    if (next === 'NO_SHOW' && slotEnd(before.appointmentDate, before.endTime || before.startTime) > new Date()) {
      throw new HttpError(409, 'Chỉ đánh dấu vắng mặt sau khi hết giờ khám.');
    }
    const patient = await this.get('BENH_NHAN', before.patientId);
    const slot = next === 'CANCELLED' ? await this.get('CA_KHAM', before.timeSlotId) : null;
    const others = slot ? await this.rows('LICH_HEN', 'timeSlotId', before.timeSlotId) : [];
    const fields = { status: next, ...(next === 'CANCELLED' ? { cancellationReason: this.command.reason } : {}) };
    if (slot) {
      const peopleCount = boundedNumber(before.peopleCount ?? 1, 'Số người', 1, 100, true);
      const reservations = exactReservationCounts(slot, others);
      if (reservations[id] !== peopleCount) {
        throw new HttpError(409, 'Dữ liệu giữ chỗ không nhất quán; không thể hủy lịch.');
      }
      delete reservations[id];
      const pointer = others.find((item) => item.id !== id && heldStatus(item.data.status));
      this.tx.update(`CA_KHAM/${before.timeSlotId}`, {
        ...capacityChange(slot, -peopleCount), appointmentId: pointer?.id ?? deleteField(),
        reservationCounts: reservations, updatedAt: serverTimestamp(),
      });
    }
    this.notification('status', patient, before.patientId,
      next === 'CANCELLED' ? 'Lịch khám đã được hủy' : next === 'CONFIRMED' ? 'Lịch khám đã được xác nhận' : 'Ghi nhận vắng mặt',
      `Mã lịch ${id}. ${this.command.reason}`, id);
    return this.updated('LICH_HEN', id, before, fields);
  }

  async reschedule() {
    const id = requiredId(this.command.id);
    const before = await this.get('LICH_HEN', id);
    if (!['PENDING', 'CONFIRMED'].includes(before.status)) throw new HttpError(409, 'Chỉ đổi lịch chưa kết thúc.');
    const slotId = requiredId(objectValue(this.command.values).timeSlotId);
    if (slotId === before.timeSlotId) throw new HttpError(400, 'Hãy chọn ca khác.');
    const oldSlot = await this.get('CA_KHAM', before.timeSlotId);
    const peopleCount = boundedNumber(before.peopleCount ?? 1, 'Số người', 1, 100, true);
    const target = await this.destination(slotId, peopleCount);
    const patient = await this.get('BENH_NHAN', before.patientId);
    const others = await this.rows('LICH_HEN', 'timeSlotId', before.timeSlotId);
    this.reason();
    const oldReservations = exactReservationCounts(oldSlot, others);
    if (oldReservations[id] !== peopleCount) {
      throw new HttpError(409, 'Dữ liệu giữ chỗ cũ không nhất quán; không thể đổi lịch.');
    }
    const newReservations = exactReservationCounts(
      target.slot,
      await this.rows('LICH_HEN', 'timeSlotId', slotId),
    );
    if (Object.hasOwn(newReservations, id)) throw new HttpError(409, 'Ca khám mới có dữ liệu giữ chỗ trùng mã lịch.');
    delete oldReservations[id];
    newReservations[id] = peopleCount;
    const pointer = others.find((item) => item.id !== id && heldStatus(item.data.status));
    this.tx.update(`CA_KHAM/${before.timeSlotId}`, {
      ...capacityChange(oldSlot, -peopleCount), appointmentId: pointer?.id ?? deleteField(),
      reservationCounts: oldReservations, updatedAt: serverTimestamp(),
    });
    this.tx.update(`CA_KHAM/${slotId}`, {
      ...target.counts, appointmentId: id, reservationCounts: newReservations,
      updatedAt: serverTimestamp(),
    });
    const fields = {
      doctorId: target.slot.doctorId, workScheduleId: target.slot.workScheduleId, timeSlotId: slotId,
      specialtyId: target.doctor.specialtyId, appointmentDate: target.schedule.workDate,
      startTime: target.slot.startTime, endTime: target.slot.endTime, rescheduleReason: this.command.reason,
    };
    this.notification('reschedule', patient, before.patientId, 'Lịch khám đã thay đổi', `Mã lịch ${id}. Ngày ${dayKey(target.schedule.workDate)}, ${target.slot.startTime}. ${this.command.reason}`, id);
    return this.updated('LICH_HEN', id, before, fields);
  }

  async setAvailability() {
    const collection = choice(this.command.collection, ['BAC_SI', 'CHUYEN_KHOA', 'BENH_NHAN', 'LICH_LAM_VIEC', 'CA_KHAM'], 'Danh mục');
    const id = requiredId(this.command.id);
    const before = await this.get(collection, id);
    const enabled = objectValue(this.command.values).enabled;
    if (typeof enabled !== 'boolean') throw new HttpError(400, 'Thiếu trạng thái bật/tắt.');
    this.reason();
    if (collection === 'BAC_SI') return this.updated(collection, id, before, { acceptingBookings: enabled });
    if (collection === 'BENH_NHAN') return this.updated(collection, id, before, { status: enabled ? 'ACTIVE' : 'ARCHIVED', isActive: enabled });
    if (collection === 'CHUYEN_KHOA' && !enabled) {
      const doctors = await this.rows('BAC_SI', 'specialtyId', id);
      if (doctors.some((item) => item.data.isActive !== false && item.data.status !== 'INACTIVE')) {
        throw new HttpError(409, 'Không thể ngừng hoạt động chuyên khoa đang có bác sĩ hoạt động.');
      }
    }
    if (collection === 'CA_KHAM') {
      const counts = capacityChange(before, 0);
      return this.updated(collection, id, before, { status: enabled ? counts.bookedCount >= before.capacity ? 'BOOKED' : 'AVAILABLE' : 'UNAVAILABLE' });
    }
    const affected = collection === 'LICH_LAM_VIEC' ? await this.rows('LICH_HEN', 'workScheduleId', id) : [];
    const result = this.updated(collection, id, before, { status: enabled ? 'ACTIVE' : 'INACTIVE', isActive: enabled });
    return { ...result, affectedCount: affected.filter((item) => ['PENDING', 'CONFIRMED'].includes(item.data.status)).length, message: 'Đã cập nhật. Các lịch hẹn đang có được giữ để xử lý riêng.' };
  }

  async create() {
    const collection = choice(this.command.collection, ['CHUYEN_KHOA', 'BENH_NHAN'], 'Danh mục');
    const values = { ...objectValue(this.command.values) };
    const authUserId = values.authUserId;
    delete values.authUserId;
    const fields = cleanEntityFields(collection, values, true);
    let id = this.command.requestId;
    if (collection === 'BENH_NHAN') {
      const account = await this.get('TAI_KHOAN', requiredId(authUserId, 'Tài khoản bệnh nhân'));
      if (account.role !== 'patient' || account.isActive !== true || !['ACTIVE', 'APPROVED'].includes(account.status)) {
        throw new HttpError(409, 'Chọn tài khoản bệnh nhân đang hoạt động.');
      }
      const normalizedAuthUserId = requiredId(authUserId, 'Tài khoản bệnh nhân');
      if ((await this.rows('BENH_NHAN', 'authUserId', normalizedAuthUserId, 1)).length) {
        throw new HttpError(409, 'Tài khoản này đã có hồ sơ bệnh nhân.');
      }
      // The auth UID is the canonical profile id, matching patient-side
      // creation and removing any ambiguity when loading a profile.
      fields.authUserId = normalizedAuthUserId;
      id = normalizedAuthUserId;
    }
    this.reason();
    fields.status = 'ACTIVE'; fields.isActive = true;
    this.tx.create(`${collection}/${id}`, { ...fields, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    this.audit(collection, id, null, fields);
    return { id, collection, message: 'Đã tạo bản ghi.' };
  }

  async save() {
    const collection = choice(this.command.collection, ['CHUYEN_KHOA', 'BAC_SI', 'BENH_NHAN'], 'Danh mục');
    const id = requiredId(this.command.id);
    const before = await this.get(collection, id);
    const fields = cleanEntityFields(collection, objectValue(this.command.values));
    this.reason();
    if (collection === 'BAC_SI') {
      if (fields.specialtyId) active(await this.get('CHUYEN_KHOA', fields.specialtyId), 'Chuyên khoa');
      if (before.userId && (fields.fullName || Object.hasOwn(fields, 'phone'))) {
        await this.get('TAI_KHOAN', before.userId);
        this.tx.update(`TAI_KHOAN/${before.userId}`, {
          ...(fields.fullName ? { fullName: fields.fullName } : {}),
          ...(Object.hasOwn(fields, 'phone') ? { phone: fields.phone } : {}), updatedAt: serverTimestamp(),
        });
      }
    }
    return this.updated(collection, id, before, fields);
  }

  async remove() {
    const collection = choice(this.command.collection, ['CHUYEN_KHOA', 'BAC_SI', 'LICH_LAM_VIEC', 'CA_KHAM', 'THONG_BAO'], 'Danh mục');
    const id = requiredId(this.command.id);
    const before = await this.get(collection, id);
    this.reason();
    const dependencies = {
      CHUYEN_KHOA: [['BAC_SI', 'specialtyId'], ['LICH_HEN', 'specialtyId']],
      BAC_SI: [['LICH_HEN', 'doctorId'], ['LICH_LAM_VIEC', 'doctorId'], ['HO_SO_SUC_KHOE', 'doctorId'], ['KET_QUA_CLS', 'doctorId']],
      LICH_LAM_VIEC: [['LICH_HEN', 'workScheduleId']], CA_KHAM: [['LICH_HEN', 'timeSlotId']], THONG_BAO: [],
    };
    for (const [related, field] of dependencies[collection]) {
      if ((await this.rows(related, field, id, 1)).length) throw new HttpError(409, 'Đã có dữ liệu liên quan. Hãy ngừng hoạt động / lưu trữ thay vì xóa.');
    }
    const unusedSlots = collection === 'LICH_LAM_VIEC' ? await this.rows('CA_KHAM', 'workScheduleId', id) : [];
    if (unusedSlots.some((slot) => slot.data.bookedCount !== 0)) throw new HttpError(409, 'Lịch còn ca đã giữ chỗ hoặc thiếu bộ đếm. Không thể xóa.');
    if (collection === 'THONG_BAO' && before.status !== 'DRAFT') throw new HttpError(409, 'Chỉ được xóa thông báo nháp.');
    if (collection === 'CA_KHAM' && before.bookedCount !== 0) throw new HttpError(409, 'Ca khám còn chỗ đã giữ hoặc thiếu bộ đếm; không thể xóa.');
    if (collection === 'BAC_SI' && before.userId) {
      await this.get('TAI_KHOAN', before.userId);
      this.tx.update(`TAI_KHOAN/${before.userId}`, { isActive: false, status: 'INACTIVE', updatedAt: serverTimestamp() });
    }
    this.tx.create(`ADMIN_ARCHIVES/${this.command.requestId}`, { collection, id, data: before, actorId: this.uid, createdAt: serverTimestamp() });
    for (const slot of unusedSlots) this.tx.delete(`CA_KHAM/${slot.id}`);
    this.tx.delete(`${collection}/${id}`);
    this.audit(collection, id, before, null);
    return { id, collection, message: collection === 'BAC_SI' ? 'Đã xóa hồ sơ chưa sử dụng và khóa tài khoản liên kết.' : 'Đã xóa bản ghi chưa sử dụng.' };
  }

  async createSchedule() {
    const values = objectValue(this.command.values);
    const doctorId = requiredId(values.doctorId);
    const doctor = await this.get('BAC_SI', doctorId); active(doctor, 'Bác sĩ');
    const period = workPeriod(values.workDate, values.startTime, values.endTime);
    if (slotStart(period.date, values.startTime) <= new Date()) throw new HttpError(409, 'Thời gian khám đã qua.');
    const duration = boundedNumber(values.slotDuration, 'Thời lượng ca', 5, 240, true);
    const capacity = boundedNumber(values.capacity, 'Sức chứa', 1, 100, true);
    const weeks = boundedNumber(values.repeatWeeks ?? 1, 'Số tuần', 1, 8, true);
    const count = Math.ceil((period.end - period.start) / duration);
    if (count * weeks > 240) throw new HttpError(400, 'Tối đa 240 ca mỗi lần.');
    const existing = await this.rows('LICH_LAM_VIEC', 'doctorId', doctorId);
    for (let week = 0; week < weeks; week++) {
      const workDate = addDays(period.date, week * 7);
      for (const item of existing) {
        const schedule = item.data;
        if (schedule.status === 'ACTIVE' && dayKey(schedule.workDate) === dayKey(workDate) && period.start < timeMinutes(schedule.endTime) && period.end > timeMinutes(schedule.startTime)) {
          throw new HttpError(409, 'Lịch làm việc bị trùng giờ với lịch đang hoạt động.');
        }
      }
    }
    this.reason();
    const rootId = this.command.requestId;
    for (let week = 0; week < weeks; week++) {
      const workDate = addDays(period.date, week * 7);
      const scheduleId = week ? `${rootId}_${week}` : rootId;
      this.tx.create(`LICH_LAM_VIEC/${scheduleId}`, {
        doctorId, workDate, startTime: values.startTime, endTime: values.endTime,
        slotDuration: duration, capacity, status: 'ACTIVE', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
      for (let index = 0; index < count; index++) {
        const startTime = minutesText(period.start + index * duration);
        const endTime = minutesText(Math.min(period.end, period.start + (index + 1) * duration));
        this.tx.create(`CA_KHAM/${rootId}_${week}_${index}`, {
          doctorId, workScheduleId: scheduleId, startTime, endTime,
          startsAt: slotStart(workDate, startTime), endsAt: slotEnd(workDate, endTime),
          capacity, bookedCount: 0, status: 'AVAILABLE', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
        });
      }
    }
    this.audit('LICH_LAM_VIEC', rootId, null, { ...values, generatedSlots: count * weeks });
    return { id: rootId, collection: 'LICH_LAM_VIEC', message: `Đã lưu ${weeks} lịch và ${count * weeks} ca khám.` };
  }

  async editSchedule() {
    const id = requiredId(this.command.id);
    const before = await this.get('LICH_LAM_VIEC', id);
    const values = objectValue(this.command.values);
    const doctorId = requiredId(values.doctorId);
    if (doctorId !== before.doctorId) throw new HttpError(409, 'Không đổi bác sĩ của lịch đã tạo; hãy tạo lịch mới.');
    const doctor = await this.get('BAC_SI', doctorId); active(doctor, 'Bác sĩ');
    const period = workPeriod(values.workDate, values.startTime, values.endTime);
    if (slotStart(period.date, values.startTime) <= new Date()) throw new HttpError(409, 'Thời gian khám đã qua.');
    const duration = boundedNumber(values.slotDuration, 'Thời lượng ca', 5, 240, true);
    const capacity = boundedNumber(values.capacity, 'Sức chứa', 1, 100, true);
    const oldSlots = await this.rows('CA_KHAM', 'workScheduleId', id);
    const appointments = await this.rows('LICH_HEN', 'workScheduleId', id);
    if (appointments.length || oldSlots.some((slot) => slot.data.bookedCount !== 0)) {
      throw new HttpError(409, 'Lịch đã có lượt đặt / lịch sử. Hãy ngừng nhận lịch và tạo lịch thay thế.');
    }
    const existing = await this.rows('LICH_LAM_VIEC', 'doctorId', doctorId);
    for (const item of existing) {
      const schedule = item.data;
      if (item.id !== id && schedule.status === 'ACTIVE' && dayKey(schedule.workDate) === dayKey(period.date) &&
          period.start < timeMinutes(schedule.endTime) && period.end > timeMinutes(schedule.startTime)) {
        throw new HttpError(409, 'Lịch làm việc bị trùng giờ với lịch đang hoạt động.');
      }
    }
    const count = Math.ceil((period.end - period.start) / duration);
    this.reason();
    const fields = {
      doctorId, workDate: period.date, startTime: values.startTime, endTime: values.endTime,
      slotDuration: duration, capacity, status: before.status === 'INACTIVE' ? 'INACTIVE' : 'ACTIVE', updatedAt: serverTimestamp(),
    };
    for (const slot of oldSlots) this.tx.delete(`CA_KHAM/${slot.id}`);
    this.tx.update(`LICH_LAM_VIEC/${id}`, fields);
    for (let index = 0; index < count; index++) {
      const startTime = minutesText(period.start + index * duration);
      const endTime = minutesText(Math.min(period.end, period.start + (index + 1) * duration));
      this.tx.create(`CA_KHAM/${this.command.requestId}_0_${index}`, {
        doctorId, workScheduleId: id, startTime, endTime,
        startsAt: slotStart(period.date, startTime), endsAt: slotEnd(period.date, endTime),
        capacity, bookedCount: 0, status: 'AVAILABLE', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
    }
    this.audit('LICH_LAM_VIEC', id, before, { ...values, generatedSlots: count });
    return { id, collection: 'LICH_LAM_VIEC', message: `Đã cập nhật lịch và ${count} ca khám.` };
  }

  async saveSlot() {
    const values = objectValue(this.command.values);
    const id = this.command.id ? requiredId(this.command.id) : this.command.requestId;
    const before = this.command.id ? await this.get('CA_KHAM', id) : null;
    const scheduleId = before?.workScheduleId || requiredId(values.workScheduleId);
    const schedule = await this.get('LICH_LAM_VIEC', scheduleId); active(schedule, 'Lịch làm việc');
    const doctor = await this.get('BAC_SI', schedule.doctorId); active(doctor, 'Bác sĩ');
    const capacity = boundedNumber(values.capacity, 'Sức chứa', 1, 100, true);
    const start = timeMinutes(values.startTime), end = timeMinutes(values.endTime);
    if (start < timeMinutes(schedule.startTime) || end > timeMinutes(schedule.endTime) || start >= end) throw new HttpError(400, 'Ca phải nằm trong giờ làm việc.');
    if (slotStart(schedule.workDate, values.startTime) <= new Date()) throw new HttpError(409, 'Thời gian khám đã qua.');
    const related = await this.rows('CA_KHAM', 'workScheduleId', scheduleId);
    const history = before ? await this.rows('LICH_HEN', 'timeSlotId', id) : [];
    if (history.length && (values.startTime !== before.startTime || values.endTime !== before.endTime)) throw new HttpError(409, 'Ca đã có lịch sử, không đổi giờ khám.');
    if (related.some((item) => item.id !== id && start < timeMinutes(item.data.endTime) && end > timeMinutes(item.data.startTime))) throw new HttpError(409, 'Ca khám bị trùng giờ.');
    const bookedCount = before ? boundedNumber(before.bookedCount, 'Số chỗ', 0, capacity, true) : 0;
    const fields = {
      workScheduleId: scheduleId, doctorId: schedule.doctorId, startTime: values.startTime, endTime: values.endTime,
      startsAt: slotStart(schedule.workDate, values.startTime), endsAt: slotEnd(schedule.workDate, values.endTime),
      capacity, bookedCount, status: ['UNAVAILABLE', 'CANCELLED'].includes(before?.status) ? before.status : bookedCount >= capacity ? 'BOOKED' : 'AVAILABLE',
      updatedAt: serverTimestamp(),
    };
    this.reason();
    this.tx.update(`LICH_LAM_VIEC/${scheduleId}`, { adminVersion: increment(1), updatedAt: serverTimestamp() });
    if (before) this.tx.update(`CA_KHAM/${id}`, fields); else this.tx.create(`CA_KHAM/${id}`, { ...fields, createdAt: serverTimestamp() });
    this.audit('CA_KHAM', id, before, fields);
    return { id, collection: 'CA_KHAM', message: 'Đã lưu ca khám.' };
  }

  async accountAccess() {
    const id = requiredId(this.command.id);
    const before = await this.get('TAI_KHOAN', id);
    const values = objectValue(this.command.values);
    this.reason();
    if (id === this.uid) throw new HttpError(409, 'Không tự khóa hoặc đổi quyền tài khoản đang đăng nhập.');
    const role = choice(values.role ?? before.role, ['patient', 'doctor', 'admin'], 'Vai trò');
    if (typeof values.isActive !== 'boolean') throw new HttpError(400, 'Thiếu trạng thái tài khoản.');
    const doctors = await this.rows('BAC_SI', 'userId', id, 2);
    const patients = await this.rows('BENH_NHAN', 'authUserId', id);
    if (role === 'doctor' && doctors.length !== 1) throw new HttpError(409, 'Tài khoản bác sĩ phải có đúng một hồ sơ bác sĩ liên kết.');
    if (role !== before.role && (doctors.length || patients.length)) throw new HttpError(409, 'Không đổi vai trò tài khoản đã liên kết hồ sơ.');
    const enabled = values.isActive;
    const accountChanges = { role, isActive: enabled, status: enabled ? 'ACTIVE' : 'INACTIVE' };
    this.tx.update(`TAI_KHOAN/${id}`, { ...accountChanges, updatedAt: serverTimestamp() });
    // A user account and its profile are one operational identity. Updating
    // only TAI_KHOAN left BENH_NHAN/BAC_SI looking active in the Admin UI and
    // created a confusing, partially locked state.
    for (const patient of patients) {
      this.tx.update(`BENH_NHAN/${patient.id}`, {
        isActive: enabled, status: enabled ? 'ACTIVE' : 'ARCHIVED', updatedAt: serverTimestamp(),
      });
    }
    for (const doctor of doctors) {
      this.tx.update(`BAC_SI/${doctor.id}`, {
        isActive: enabled, status: enabled ? 'ACTIVE' : 'INACTIVE', acceptingBookings: enabled,
        updatedAt: serverTimestamp(),
      });
    }
    this.audit('TAI_KHOAN', id, before, { ...accountChanges, linkedPatientProfiles: patients.map((item) => item.id), linkedDoctorProfiles: doctors.map((item) => item.id) });
    return {
      id, collection: 'TAI_KHOAN', linkedPatientProfiles: patients.length, linkedDoctorProfiles: doctors.length,
      message: enabled ? 'Đã mở lại tài khoản và hồ sơ liên kết.' : 'Đã khóa tài khoản và hồ sơ liên kết.',
    };
  }

  async accountReview() {
    const id = requiredId(this.command.id);
    const before = await this.get('TAI_KHOAN', id);
    if (before.status !== 'PENDING') throw new HttpError(409, 'Chỉ tài khoản đang chờ mới có thể được duyệt hoặc từ chối.');
    const approved = objectValue(this.command.values).approved;
    if (typeof approved !== 'boolean') throw new HttpError(400, 'Thiếu quyết định duyệt tài khoản.');
    this.reason();
    return this.updated('TAI_KHOAN', id, before, {
      status: approved ? 'APPROVED' : 'REJECTED', isActive: approved,
    });
  }

  async passwordSetup() {
    const id = requiredId(this.command.id);
    const account = await this.get('TAI_KHOAN', id);
    if (account.role !== 'doctor' || account.isActive !== true) throw new HttpError(409, 'Chỉ gửi cho tài khoản bác sĩ đang hoạt động.');
    const user = await this.tx.client.lookupAuthUser(id);
    if (user.disabled || !user.email || user.email.toLowerCase() !== String(account.email || '').toLowerCase()) {
      throw new HttpError(409, 'Email đăng nhập chưa khớp tài khoản xác thực.');
    }
    this.reason();
    this.audit('TAI_KHOAN', id, null, { email: user.email, event: 'PASSWORD_SETUP_REQUESTED' });
    return { id, collection: 'TAI_KHOAN', loginEmail: user.email, message: 'Đã xác minh người nhận.' };
  }

  async internalNote() {
    const id = requiredId(this.command.id);
    await this.get('LICH_HEN', id);
    const internalNote = optionalText(objectValue(this.command.values).internalNote, 2000);
    this.reason();
    this.tx.set(`ADMIN_NOTES/${id}`, { appointmentId: id, internalNote, actorId: this.uid, updatedAt: serverTimestamp() });
    this.audit('ADMIN_NOTES', id, null, { internalNote });
    return { id, collection: 'ADMIN_NOTES', message: 'Đã lưu ghi chú nội bộ, chỉ admin xem được.' };
  }

  async feedback() {
    const id = requiredId(this.command.id);
    const before = await this.get('PHAN_HOI', id);
    const values = objectValue(this.command.values);
    const assigneeId = requiredId(values.assigneeId || this.uid);
    const assignee = await this.get('TAI_KHOAN', assigneeId);
    if (assignee.role !== 'admin' || !assignee.isActive) throw new HttpError(409, 'Người xử lý phải là admin đang hoạt động.');
    const fields = {
      processingStatus: choice(values.processingStatus, ['NEW', 'PROCESSING', 'RESOLVED'], 'Trạng thái'),
      assigneeId, response: optionalText(values.response, 2000),
    };
    const patient = before.patientId ? await this.get('BENH_NHAN', before.patientId) : null;
    this.reason();
    if (patient && fields.response) this.notification('feedback', patient, before.patientId, 'Phản hồi từ HealWay', fields.response);
    return this.updated('PHAN_HOI', id, before, fields);
  }

  async notificationDraft() {
    const values = objectValue(this.command.values);
    const id = this.command.id ? requiredId(this.command.id) : this.command.requestId;
    const before = this.command.id ? await this.get('THONG_BAO', id) : null;
    if (before && before.status !== 'DRAFT') throw new HttpError(409, 'Thông báo đã gửi không được sửa.');
    const patientId = requiredId(values.patientId);
    await this.get('BENH_NHAN', patientId);
    const fields = {
      title: requiredText(values.title, 'Tiêu đề', 160), content: requiredText(values.content, 'Nội dung', 4000),
      patientId, status: 'DRAFT', isRead: false, updatedAt: serverTimestamp(),
    };
    this.reason();
    if (before) return this.updated('THONG_BAO', id, before, fields);
    this.tx.create(`THONG_BAO/${id}`, { ...fields, createdAt: serverTimestamp(), createdBy: this.uid });
    this.audit('THONG_BAO', id, null, fields);
    return { id, collection: 'THONG_BAO', message: 'Đã lưu bản nháp, chưa gửi.' };
  }

  async sendNotification() {
    const id = requiredId(this.command.id);
    const before = await this.get('THONG_BAO', id);
    if (before.status !== 'DRAFT') throw new HttpError(409, 'Chỉ gửi bản nháp; thông báo này đã gửi hoặc thiếu trạng thái.');
    const patient = await this.get('BENH_NHAN', before.patientId);
    this.reason();
    return this.updated('THONG_BAO', id, before, { status: 'SENT', channel: 'in_app', userId: patient.authUserId, sentAt: serverTimestamp() });
  }

  async paymentReview() {
    const id = requiredId(this.command.id);
    const before = await this.get('THANH_TOAN', id);
    const values = objectValue(this.command.values);
    this.reason();
    if (values.refundRequested === true) {
      if (!['PAID', 'SUCCESS'].includes(before.status)) throw new HttpError(409, 'Chỉ yêu cầu hoàn tiền cho giao dịch thành công.');
      if (before.refundRequestId) throw new HttpError(409, 'Giao dịch đã có yêu cầu hoàn tiền.');
      this.tx.create(`YEU_CAU_HOAN_TIEN/${this.command.requestId}`, {
        paymentId: id, amount: before.amount, status: 'REQUESTED', reason: this.command.reason,
        createdAt: serverTimestamp(), actorId: this.uid,
      });
      return this.updated('THANH_TOAN', id, before, { refundRequestId: this.command.requestId, refundStatus: 'REQUESTED' });
    }
    return this.updated('THANH_TOAN', id, before, {
      reviewStatus: choice(values.reviewStatus, ['UNREVIEWED', 'REVIEWED', 'NEEDS_CHECK'], 'Kết quả đối soát'),
      reviewNote: optionalText(values.reviewNote, 2000),
    });
  }

  async saveSettings() {
    const values = objectValue(this.command.values);
    const before = await this.tx.get('CAU_HINH/general');
    const fields = {
      hospitalName: requiredText(values.hospitalName, 'Tên cơ sở', 160),
      supportPhone: requiredText(values.supportPhone, 'Điện thoại', 30),
      supportEmail: validEmail(values.supportEmail), address: optionalText(values.address, 300),
      defaultSlotDuration: boundedNumber(values.defaultSlotDuration, 'Thời lượng ca mặc định', 5, 240, true),
      defaultCapacity: boundedNumber(values.defaultCapacity, 'Sức chứa mặc định', 1, 100, true), updatedAt: serverTimestamp(),
    };
    this.reason();
    this.tx.set('CAU_HINH/general', fields);
    this.audit('CAU_HINH', 'general', before?.data ?? null, fields);
    return { id: 'general', collection: 'CAU_HINH', message: 'Đã lưu thông tin quản trị và giá trị mặc định tạo lịch.' };
  }

  async backfillSlotTimes() {
    const values = objectValue(this.command.values);
    const limit = boundedNumber(values.limit ?? 100, 'Số ca mỗi đợt', 1, 200, true);
    const cursor = values.cursor == null || values.cursor === '' ? null : requiredId(values.cursor, 'Mã tiếp tục');
    const page = await this.tx.query('CA_KHAM', [], limit, { orderByDocumentId: true, startAfterId: cursor });
    const updates = [];
    for (const slot of page) {
      const data = slot.data;
      if (data.startsAt instanceof Date && data.endsAt instanceof Date) continue;
      if (typeof data.workScheduleId !== 'string' || typeof data.startTime !== 'string' || typeof data.endTime !== 'string') {
        throw new HttpError(409, `Ca ${slot.id} thiếu lịch hoặc giờ hợp lệ; hãy sửa dữ liệu này trước khi backfill.`);
      }
      const schedule = await this.get('LICH_LAM_VIEC', data.workScheduleId);
      const startsAt = slotStart(schedule.workDate, data.startTime);
      const endsAt = slotEnd(schedule.workDate, data.endTime);
      if (startsAt >= endsAt) throw new HttpError(409, `Ca ${slot.id} có khoảng giờ không hợp lệ.`);
      updates.push({ id: slot.id, startsAt, endsAt });
    }
    for (const update of updates) {
      this.tx.update(`CA_KHAM/${update.id}`, { startsAt: update.startsAt, endsAt: update.endsAt, updatedAt: serverTimestamp() });
    }
    this.reason();
    const nextCursor = page.length === limit ? page.at(-1).id : null;
    this.audit('CA_KHAM', cursor || 'beginning', null, { scanned: page.length, updated: updates.length, nextCursor });
    return {
      collection: 'CA_KHAM', scanned: page.length, updated: updates.length, nextCursor,
      message: nextCursor == null ? `Đã backfill ${updates.length} ca trong đợt cuối.` : `Đã backfill ${updates.length} ca. Tiếp tục với cursor ${nextCursor}.`,
    };
  }
}

async function requireActiveAdmin(uid, firestore) {
  const account = await firestore.get(`TAI_KHOAN/${uid}`);
  if (!account || account.role !== 'admin' || account.isActive !== true || !['ACTIVE', 'APPROVED'].includes(account.status)) {
    throw new HttpError(403, 'Chỉ quản trị viên đang hoạt động được thực hiện thao tác này.');
  }
}

class FirestoreRest {
  constructor(env) {
    if (!env.FIREBASE_PROJECT_ID) throw new HttpError(503, 'Dịch vụ Admin chưa được cấu hình.');
    this.projectId = env.FIREBASE_PROJECT_ID;
    this.credentials = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON, this.projectId);
    this.webApiKey = env.FIREBASE_WEB_API_KEY || '';
    this.base = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/databases/(default)/documents`;
  }

  async get(path) {
    const response = await fetch(`${this.base}/${path.split('/').map(encodeURIComponent).join('/')}`, {
      headers: { Authorization: `Bearer ${await serviceAccessToken(this.credentials)}` },
    });
    if (response.status === 404) return null;
    if (!response.ok) throw new HttpError(503, 'Không thể kiểm tra dữ liệu quản trị. Vui lòng thử lại.');
    const document = await response.json();
    return decodeFields(document.fields || {});
  }

  async runTransaction(callback) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const token = await serviceAccessToken(this.credentials);
      const started = await fetch(`${this.base}:beginTransaction`, {
        method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: '{}',
      });
      if (!started.ok) throw new HttpError(503, 'Không thể bắt đầu giao dịch quản trị.');
      const { transaction } = await started.json();
      if (typeof transaction !== 'string') throw new HttpError(503, 'Không thể bắt đầu giao dịch quản trị.');
      const tx = new FirestoreTransaction(this, token, transaction);
      try {
        const result = await callback(tx);
        const committed = await fetch(`${this.base}:commit`, {
          method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ transaction, writes: tx.writes }),
        });
        if (committed.ok) return result;
        if (committed.status === 409 || committed.status === 412 || committed.status === 503) continue;
        throw new HttpError(503, 'Không thể lưu thay đổi quản trị. Vui lòng thử lại.');
      } catch (error) {
        if (error instanceof RetryableTransactionError) continue;
        throw error;
      }
    }
    throw new HttpError(409, 'Dữ liệu vừa thay đổi. Vui lòng mở lại và thử lại.');
  }

  // Read-only doctor endpoints still need a consistent authorization/profile
  // snapshot. Roll the transaction back explicitly rather than committing an
  // empty write set.
  async readTransaction(callback) {
    const token = await serviceAccessToken(this.credentials);
    const started = await fetch(`${this.base}:beginTransaction`, {
      method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: '{}',
    });
    if (!started.ok) throw new HttpError(503, 'Không thể bắt đầu phiên đọc dữ liệu bác sĩ.');
    const { transaction } = await started.json();
    if (typeof transaction !== 'string') throw new HttpError(503, 'Không thể bắt đầu phiên đọc dữ liệu bác sĩ.');
    try {
      return await callback(new FirestoreTransaction(this, token, transaction));
    } finally {
      try {
        await fetch(`${this.base}:rollback`, {
          method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ transaction }),
        });
      } catch (_) {
        // The transaction expires server-side; a failed rollback must not
        // replace a successfully assembled read projection.
      }
    }
  }

  async createAuthUser(email, displayName) {
    if (!this.webApiKey) throw new HttpError(503, 'Dịch vụ cấp tài khoản chưa được cấu hình Firebase Web API key.');
    const password = randomPassword();
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/accounts?key=${encodeURIComponent(this.webApiKey)}`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await serviceAccessToken(this.credentials)}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, displayName, returnSecureToken: false }),
    });
    if (response.status === 409 || response.status === 400) {
      const error = await safeJson(response);
      if (String(error?.error?.message || '').includes('EMAIL_EXISTS')) throw new HttpError(409, 'Email đăng nhập đã được sử dụng.');
    }
    if (!response.ok) throw new HttpError(503, 'Không thể tạo tài khoản đăng nhập bác sĩ.');
    const payload = await safeJson(response);
    if (typeof payload?.localId !== 'string' || !payload.localId) throw new HttpError(503, 'Firebase Authentication trả dữ liệu không hợp lệ.');
    return payload.localId;
  }

  async deleteAuthUser(localId) {
    if (!this.webApiKey) return false;
    try {
      const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/accounts:delete?key=${encodeURIComponent(this.webApiKey)}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${await serviceAccessToken(this.credentials)}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ localId }),
      });
      return response.ok;
    } catch (_) { return false; }
  }

  async lookupAuthUser(localId) {
    if (!this.webApiKey) throw new HttpError(503, 'Dịch vụ cấp tài khoản chưa được cấu hình Firebase Web API key.');
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/accounts:lookup?key=${encodeURIComponent(this.webApiKey)}`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await serviceAccessToken(this.credentials)}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ localId: [localId] }),
    });
    if (!response.ok) throw new HttpError(503, 'Không thể kiểm tra tài khoản đăng nhập bác sĩ.');
    const body = await safeJson(response);
    const user = body?.users?.[0];
    if (!user || typeof user.email !== 'string') throw new HttpError(404, 'Không tìm thấy tài khoản đăng nhập bác sĩ.');
    return { email: user.email, disabled: user.disabled === true };
  }
}

class RetryableTransactionError extends Error {}

class FirestoreTransaction {
  constructor(client, token, transaction) {
    Object.assign(this, { client, token, transaction, writes: [] });
  }

  name(path) { return `projects/${this.client.projectId}/databases/(default)/documents/${path.split('/').map(encodeURIComponent).join('/')}`; }

  async get(path) {
    const response = await fetch(`${this.client.base}/${path.split('/').map(encodeURIComponent).join('/')}?transaction=${encodeURIComponent(this.transaction)}`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    if (response.status === 404) return null;
    if (response.status === 409 || response.status === 412) throw new RetryableTransactionError();
    if (!response.ok) throw new HttpError(503, 'Không thể đọc dữ liệu trong giao dịch.');
    const document = await response.json();
    return { id: path.split('/').at(-1), data: decodeFields(document.fields || {}) };
  }

  async query(collection, filters = [], limit = 301, options = {}) {
    const where = filters.length === 0 ? undefined : filters.length === 1 ? fieldFilter(filters[0]) : { compositeFilter: { op: 'AND', filters: filters.map(fieldFilter) } };
    const orderBy = options.orderByDocumentId
      ? [{ field: { fieldPath: '__name__' }, direction: 'ASCENDING' }]
      : undefined;
    const startAt = options.startAfterId
      ? { values: [{ referenceValue: this.name(`${collection}/${options.startAfterId}`) }], before: false }
      : undefined;
    const response = await fetch(`${this.client.base}:runQuery`, {
      method: 'POST', headers: { Authorization: `Bearer ${this.token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ transaction: this.transaction, structuredQuery: {
        from: [{ collectionId: collection }], ...(where ? { where } : {}), ...(orderBy ? { orderBy } : {}), ...(startAt ? { startAt } : {}), limit,
      } }),
    });
    if (response.status === 409 || response.status === 412) throw new RetryableTransactionError();
    if (!response.ok) throw new HttpError(503, 'Không thể đọc dữ liệu liên quan trong giao dịch.');
    const body = await response.text();
    if (!body.trim()) return [];
    // Firestore REST normally returns a JSON array for runQuery.  Some
    // gateways stream individual JSON objects on separate lines instead.
    // Accept both formats; treating an array as a single NDJSON line made
    // every operation that checked related rows fail before its transaction.
    const rows = decodeQueryRows(body);
    const result = [];
    for (const item of rows) {
      if (item.document) {
        const name = item.document.name.split('/').at(-1);
        result.push({ id: name, data: decodeFields(item.document.fields || {}) });
      }
    }
    return result;
  }

  create(path, data) { this.writes.push(writeFor(this.name(path), data, { exists: false })); }
  update(path, data) { this.writes.push(writeFor(this.name(path), data, { exists: true })); }
  set(path, data) { this.writes.push(writeFor(this.name(path), data)); }
  delete(path) { this.writes.push({ delete: this.name(path) }); }
}

function parseServiceAccount(value, expectedProject) {
  if (!value) throw new HttpError(503, 'Dịch vụ Admin chưa được cấu hình Service Account.');
  let credential;
  try { credential = JSON.parse(value); } catch (_) { throw new HttpError(503, 'Service Account của dịch vụ Admin không hợp lệ.'); }
  if (credential?.type !== 'service_account' || credential.project_id !== expectedProject ||
      typeof credential.client_email !== 'string' || typeof credential.private_key !== 'string') {
    throw new HttpError(503, 'Service Account không khớp dự án Firebase.');
  }
  return credential;
}

async function serviceAccessToken(credential) {
  if (serviceTokenCache.expiresAt > Date.now() + 60_000 && serviceTokenCache.value) return serviceTokenCache.value;
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlJson({ alg: 'RS256', typ: 'JWT' });
  const payload = base64UrlJson({ iss: credential.client_email, scope: cloudPlatformScope, aud: googleTokenUrl, iat: now, exp: now + 3600 });
  const signed = `${header}.${payload}`;
  const privateKey = await crypto.subtle.importKey('pkcs8', pemBytes(credential.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, new TextEncoder().encode(signed));
  let response;
  try {
    response = await fetch(googleTokenUrl, {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${signed}.${base64UrlBytes(new Uint8Array(signature))}` }),
    });
  } catch (_) { throw new HttpError(503, 'Không thể xác thực dịch vụ Admin.'); }
  if (!response.ok) throw new HttpError(503, 'Không thể xác thực dịch vụ Admin.');
  const token = await response.json();
  if (typeof token.access_token !== 'string') throw new HttpError(503, 'Không thể xác thực dịch vụ Admin.');
  serviceTokenCache = { value: token.access_token, expiresAt: Date.now() + Number(token.expires_in || 3000) * 1000 };
  return serviceTokenCache.value;
}

async function authenticatedUser(request, projectId) {
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token || !projectId) throw new HttpError(401, 'Bạn cần đăng nhập để dùng chức năng quản trị.');
  const [headerPart, payloadPart, signaturePart] = token.split('.');
  let header, claims;
  try { header = decodeJson(headerPart); claims = decodeJson(payloadPart); } catch (_) { throw new HttpError(401, 'Phiên đăng nhập không hợp lệ.'); }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string' || !signaturePart) throw new HttpError(401, 'Phiên đăng nhập không hợp lệ.');
  const keys = await firebaseSigningKeys();
  const jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk) throw new HttpError(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, base64UrlToBytes(signaturePart), new TextEncoder().encode(`${headerPart}.${payloadPart}`));
  const now = Math.floor(Date.now() / 1000);
  if (!valid || claims.aud !== projectId || claims.iss !== `https://securetoken.google.com/${projectId}` ||
      typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 128 ||
      typeof claims.exp !== 'number' || claims.exp <= now || typeof claims.iat !== 'number' || claims.iat > now + 60) {
    throw new HttpError(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
  }
  return { uid: claims.sub };
}

async function firebaseSigningKeys() {
  if (signingKeyCache.expiresAt > Date.now()) return signingKeyCache.values;
  const response = await fetch(firebaseJwksUrl);
  if (!response.ok) throw new HttpError(503, 'Không thể xác thực phiên đăng nhập.');
  const maxAge = Number(response.headers.get('cache-control')?.match(/max-age=(\d+)/)?.[1] || 300);
  const payload = await response.json();
  if (!Array.isArray(payload.keys)) throw new HttpError(503, 'Không thể xác thực phiên đăng nhập.');
  signingKeyCache = { values: payload.keys, expiresAt: Date.now() + maxAge * 1000 };
  return signingKeyCache.values;
}

function decodeFields(fields) { return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)])); }
function decodeQueryRows(body) {
  try {
    const decoded = JSON.parse(body);
    if (Array.isArray(decoded)) return decoded;
    if (decoded && typeof decoded === 'object') return [decoded];
  } catch (_) {
    try {
      return body.trim().split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
    } catch (_) {
      // Fall through to one consistent, safe client-facing error.
    }
  }
  throw new HttpError(503, 'Firestore trả dữ liệu không hợp lệ.');
}
function decodeValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('mapValue' in value) return decodeFields(value.mapValue.fields || {});
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decodeValue);
  return null;
}

const marker = Symbol('firestore-marker');
const serverTimestamp = () => ({ [marker]: 'serverTimestamp' });
const deleteField = () => ({ [marker]: 'delete' });
const increment = (value) => ({ [marker]: 'increment', value });

function writeFor(name, values, currentDocument) {
  const fields = {};
  const fieldPaths = [];
  const fieldTransforms = [];
  for (const [field, value] of Object.entries(values)) {
    fieldPaths.push(field);
    if (value?.[marker] === 'serverTimestamp') {
      fieldTransforms.push({ fieldPath: field, setToServerValue: 'REQUEST_TIME' });
    } else if (value?.[marker] === 'increment') {
      fieldTransforms.push({ fieldPath: field, increment: encodeValue(value.value) });
    } else if (value?.[marker] !== 'delete') {
      fields[field] = encodeValue(value);
    }
  }
  return {
    update: { name, fields }, updateMask: { fieldPaths }, ...(currentDocument ? { currentDocument } : {}),
    ...(fieldTransforms.length ? { updateTransforms: fieldTransforms } : {}),
  };
}

function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (value && typeof value === 'object') return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encodeValue(item)])) } };
  throw new HttpError(400, 'Dữ liệu cập nhật không hợp lệ.');
}

function fieldFilter(filter) {
  return { fieldFilter: { field: { fieldPath: filter.field }, op: filter.op || 'EQUAL', value: encodeValue(filter.value) } };
}

function objectValue(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value;
}
function optionalText(value, max = 1000) {
  if (value == null) return '';
  if (typeof value !== 'string' || value.trim().length > max) throw new HttpError(400, 'Nội dung không hợp lệ.');
  return value.trim();
}
function boundedNumber(value, label, min, max, integer = false) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max || (integer && !Number.isInteger(value))) {
    throw new HttpError(400, `${label} không hợp lệ.`);
  }
  return value;
}
function choice(value, choices, label) {
  if (!choices.includes(value)) throw new HttpError(400, `${label} không hợp lệ.`);
  return value;
}
function validEmail(value) {
  const email = requiredText(value, 'Email', 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'Email không hợp lệ.');
  return email;
}
function cleanDoctorFields(values, create = true) {
  const result = {};
  if (Object.hasOwn(values, 'fullName')) result.fullName = requiredText(values.fullName, 'Họ tên', 120);
  if (Object.hasOwn(values, 'specialtyId')) result.specialtyId = requiredId(values.specialtyId, 'Chuyên khoa');
  if (Object.hasOwn(values, 'yearsOfExperience')) result.yearsOfExperience = boundedNumber(values.yearsOfExperience, 'Số năm kinh nghiệm', 0, 70, true);
  if (Object.hasOwn(values, 'consultationFee')) result.consultationFee = boundedNumber(values.consultationFee, 'Phí khám', 0, 100000000);
  if (Object.hasOwn(values, 'phone')) {
    result.phone = optionalText(values.phone, 20);
    if (result.phone && !/^\+?[\d ()-]{8,20}$/.test(result.phone)) throw new HttpError(400, 'Số điện thoại không hợp lệ.');
  }
  const avatarUrl = Object.hasOwn(values, 'avatarUrl') ? optionalText(values.avatarUrl, 2048) : '';
  if (avatarUrl && !/^https:\/\//.test(avatarUrl)) throw new HttpError(400, 'Ảnh phải dùng URL HTTPS.');
  const rawDate = optionalText(values.dateOfBirth, 10);
  const dateOfBirth = rawDate ? parseWorkDate(rawDate) : null;
  if (dateOfBirth && dateOfBirth > new Date()) throw new HttpError(400, 'Ngày sinh không được ở tương lai.');
  const gender = optionalText(values.gender, 30);
  if (gender && !['Nam', 'Nữ', 'Khác'].includes(gender)) throw new HttpError(400, 'Giới tính không hợp lệ.');
  Object.assign(result, {
    ...(values.email ? { email: validEmail(values.email) } : {}),
    ...(dateOfBirth ? { dateOfBirth } : {}), ...(gender ? { gender } : {}),
    ...(optionalText(values.address, 300) ? { address: optionalText(values.address, 300) } : {}),
    ...(optionalText(values.qualification, 300) ? { qualification: optionalText(values.qualification, 300) } : {}),
    ...(optionalText(values.biography, 2000) ? { biography: optionalText(values.biography, 2000) } : {}),
    ...(avatarUrl ? { avatarUrl } : {}),
  });
  if (create && (!result.fullName || !result.specialtyId || result.yearsOfExperience == null || result.consultationFee == null)) {
    throw new HttpError(400, 'Thiếu họ tên, chuyên khoa, kinh nghiệm hoặc phí khám.');
  }
  return result;
}
function cleanEntityFields(collection, values, create = false) {
  const allowed = collection === 'CHUYEN_KHOA'
    ? ['name', 'description']
    : collection === 'BAC_SI'
    ? ['fullName', 'email', 'phone', 'dateOfBirth', 'gender', 'address', 'specialtyId', 'qualification', 'yearsOfExperience', 'consultationFee', 'biography', 'avatarUrl']
    : ['fullName', 'phone', 'email', 'dateOfBirth', 'gender', 'address', 'nationalId', 'insuranceNumber'];
  for (const key of Object.keys(values)) {
    if (!allowed.includes(key)) throw new HttpError(400, `Không được sửa trường ${key}.`);
  }
  if (collection === 'BAC_SI') return cleanDoctorFields(values, create);
  if (collection === 'CHUYEN_KHOA') {
    const result = {};
    if (Object.hasOwn(values, 'name')) result.name = requiredText(values.name, 'Tên chuyên khoa', 120);
    if (Object.hasOwn(values, 'description')) result.description = optionalText(values.description, 2000);
    if (create && !result.name) throw new HttpError(400, 'Tên chuyên khoa là bắt buộc.');
    return result;
  }
  const result = {};
  if (Object.hasOwn(values, 'fullName')) result.fullName = requiredText(values.fullName, 'Họ tên', 120);
  if (Object.hasOwn(values, 'phone')) {
    result.phone = optionalText(values.phone, 20);
    if (result.phone && !/^\+?[\d ()-]{8,20}$/.test(result.phone)) throw new HttpError(400, 'Số điện thoại không hợp lệ.');
  }
  if (Object.hasOwn(values, 'email')) result.email = values.email ? validEmail(values.email) : '';
  if (Object.hasOwn(values, 'dateOfBirth')) {
    const date = values.dateOfBirth ? parseWorkDate(values.dateOfBirth) : null;
    if (date && date > new Date()) throw new HttpError(400, 'Ngày sinh không được ở tương lai.');
    result.dateOfBirth = date;
  }
  if (Object.hasOwn(values, 'gender')) {
    result.gender = optionalText(values.gender, 30);
    if (result.gender && !['Nam', 'Nữ', 'Khác'].includes(result.gender)) throw new HttpError(400, 'Giới tính không hợp lệ.');
  }
  for (const [key, max] of [['address', 300], ['nationalId', 50], ['insuranceNumber', 80]]) {
    if (Object.hasOwn(values, key)) result[key] = optionalText(values[key], max);
  }
  if (create && !result.fullName) throw new HttpError(400, 'Họ tên là bắt buộc.');
  return result;
}
function randomPassword() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return base64UrlBytes(bytes) + 'Aa1!';
}
async function safeJson(response) { try { return await response.json(); } catch (_) { return null; } }
function active(data, label) {
  if (data.status !== 'ACTIVE' || data.isActive === false || data.acceptingBookings === false) {
    throw new HttpError(409, `${label} đã ngừng nhận lịch hoặc không hoạt động.`);
  }
}
function heldStatus(status) { return ['PENDING', 'CONFIRMED', 'COMPLETED', 'NO_SHOW'].includes(status); }
function appointmentTransition(before, after) {
  const allowed = { PENDING: ['CONFIRMED', 'CANCELLED'], CONFIRMED: ['CANCELLED', 'NO_SHOW'] };
  if (!allowed[before]?.includes(after)) throw new HttpError(409, 'Trạng thái đã thay đổi hoặc thao tác không được phép.');
}
function capacityChange(slot, delta) {
  const capacity = boundedNumber(slot.capacity, 'Sức chứa', 1, 100, true);
  const before = boundedNumber(slot.bookedCount, 'Số chỗ đã đặt', 0, capacity, true);
  const bookedCount = before + delta;
  if (bookedCount < 0 || bookedCount > capacity) throw new HttpError(409, 'Ca khám không còn đủ chỗ hoặc bộ đếm chưa nhất quán.');
  return { bookedCount, status: ['UNAVAILABLE', 'CANCELLED'].includes(slot.status) ? slot.status : bookedCount >= capacity ? 'BOOKED' : 'AVAILABLE' };
}
// Older records may predate reservationCounts.  Rebuild an absent map only
// when every currently-held appointment accounts for the slot's exact count;
// a partially populated or contradictory map remains a hard failure instead
// of allowing a cancellation to release somebody else's reservation.
function exactReservationCounts(slot, rows) {
  const expected = {};
  let total = 0;
  for (const row of rows) {
    if (!heldStatus(row.data.status)) continue;
    const count = boundedNumber(row.data.peopleCount ?? 1, 'Số người', 1, 100, true);
    expected[row.id] = count;
    total += count;
  }
  if (total !== boundedNumber(slot.bookedCount, 'Số chỗ đã đặt', 0, boundedNumber(slot.capacity, 'Sức chứa', 1, 100, true), true)) {
    throw new HttpError(409, 'Dữ liệu giữ chỗ không nhất quán; cần quản trị viên kiểm tra.');
  }
  const stored = objectValue(slot.reservationCounts);
  const storedKeys = Object.keys(stored);
  if (storedKeys.length === 0) return expected;
  const expectedKeys = Object.keys(expected);
  if (storedKeys.length !== expectedKeys.length || storedKeys.some((id) => stored[id] !== expected[id])) {
    throw new HttpError(409, 'Dữ liệu giữ chỗ không nhất quán; cần quản trị viên kiểm tra.');
  }
  return { ...stored };
}
function timeMinutes(value) {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) throw new HttpError(400, 'Giờ phải theo dạng HH:mm.');
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3));
}
function minutesText(value) { return `${Math.floor(value / 60)}`.padStart(2, '0') + ':' + `${value % 60}`.padStart(2, '0'); }
function parseWorkDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new HttpError(400, 'Ngày phải theo dạng YYYY-MM-DD.');
  const date = new Date(`${value}T00:00:00+07:00`);
  if (!Number.isFinite(date.getTime()) || dayKey(date) !== value) throw new HttpError(400, 'Ngày không hợp lệ.');
  return date;
}
function dayKey(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) throw new HttpError(400, 'Ngày dữ liệu chưa hợp lệ.');
  return new Date(date.getTime() + 7 * 3600000).toISOString().slice(0, 10);
}
function workPeriod(workDate, startTime, endTime) {
  const date = parseWorkDate(workDate), start = timeMinutes(startTime), end = timeMinutes(endTime);
  if (start >= end) throw new HttpError(400, 'Giờ kết thúc phải sau giờ bắt đầu.');
  const weekday = new Date(date.getTime() + 7 * 3600000).getUTCDay();
  if (weekday === 0 || (weekday === 6 && end > 720)) throw new HttpError(400, 'Chủ nhật không có lịch; thứ bảy chỉ khám trước 12:00.');
  return { date, start, end };
}
function slotStart(workDate, startTime) {
  const day = workDate instanceof Date ? parseWorkDate(dayKey(workDate)) : parseWorkDate(workDate);
  return new Date(day.getTime() + timeMinutes(startTime) * 60000);
}
function slotEnd(workDate, endTime) { return slotStart(workDate, endTime); }
function addDays(date, count) { return new Date(date.getTime() + count * 86400000); }

async function commandDigest(value) {
  const bytes = new TextEncoder().encode(JSON.stringify(canonical(value)));
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(hash)].map((value) => value.toString(16).padStart(2, '0')).join('');
}
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  return value;
}

function requiredText(value, label, max) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw new HttpError(400, `${label} không hợp lệ.`);
  return value.trim();
}
function requiredId(value, label) {
  const id = requiredText(value, label, 128);
  if (id.includes('/') || id === '.' || id === '..') throw new HttpError(400, `${label} không hợp lệ.`);
  return id;
}
function decodeJson(value) { return JSON.parse(new TextDecoder().decode(base64UrlToBytes(value))); }
function base64UrlJson(value) { return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value))); }
function base64UrlBytes(value) { return btoa(String.fromCharCode(...value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); }
function base64UrlToBytes(value) { const padded = value.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(value.length / 4) * 4, '='); return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0)); }
function pemBytes(value) { return base64UrlToBytes(value.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '').replace(/\+/g, '-').replace(/\//g, '_')); }
function corsHeaders(request, env) {
  const headers = new Headers({ 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Authorization, Content-Type', 'Content-Type': 'application/json; charset=UTF-8', Vary: 'Origin' });
  const origin = request.headers.get('Origin');
  const allowed = String(env.ALLOWED_ORIGINS || '').split(',').map((value) => value.trim()).filter(Boolean);
  if (origin && allowed.includes(origin)) headers.set('Access-Control-Allow-Origin', origin);
  return headers;
}
function json(value, status, headers) { return new Response(JSON.stringify(value), { status, headers }); }
