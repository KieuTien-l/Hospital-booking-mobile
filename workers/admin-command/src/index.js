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
    const url = new URL(request.url);
    // These two pages are deliberately informational only.  A redirect back
    // from a payment provider is never proof of payment; only its signed
    // webhook below is allowed to mark a Firestore transaction PAID.
    if (request.method === 'GET' && ['/payments/return', '/payments/cancel'].includes(url.pathname)) {
      return paymentReturnPage(url.pathname === '/payments/return', headers);
    }
    if (url.pathname === '/payments/payos-webhook' && request.method === 'POST') {
      try {
        return json(await payosWebhook(request, env), 200, headers);
      } catch (error) {
        const status = error instanceof HttpError ? error.status : 500;
        if (!(error instanceof HttpError)) console.error('payOS webhook failed');
        return json({ error: { message: error instanceof HttpError ? error.message : 'Không thể xử lý thông báo thanh toán.' } }, status, headers);
      }
    }
    if (url.pathname.startsWith('/payments/')) {
      try {
        const session = await authenticatedUser(request, env.FIREBASE_PROJECT_ID);
        const firestore = new FirestoreRest(env);
        return json(await patientPaymentRequest(request, url, session.uid, firestore, env), 200, headers);
      } catch (error) {
        const status = error instanceof HttpError ? error.status : 500;
        if (!(error instanceof HttpError)) console.error('patient payment worker failed');
        return json({ error: { message: error instanceof HttpError ? error.message : 'Không thể hoàn tất yêu cầu thanh toán.' } }, status, headers);
      }
    }
    if (request.method === 'GET' && new URL(request.url).pathname === '/health') {
      try {
        const credentials = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON, env.FIREBASE_PROJECT_ID);
        await serviceAccessToken(credentials);
        return json({ service: 'healway-admin-command', configured: true }, 200, headers);
      } catch (_) {
        return json({ service: 'healway-admin-command', configured: false }, 503, headers);
      }
    }
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
export async function executeCommand(command, uid, firestore) {
  if (command.operation === 'createDoctor') return provisionDoctor(command, uid, firestore);
  const fingerprint = await commandDigest(command);
  return firestore.runTransaction(async (tx) => {
    const receiptPath = `ADMIN_COMMANDS/${uid}_${command.requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã yêu cầu đã được dùng cho nội dung khác.');
      return receipt.data.result;
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
 * Payment is intentionally a separate HTTP surface from /adminCommand:
 * patients may initiate and inspect only their own payment links, while an
 * administrator never receives a generic ability to write payment states.
 */
async function patientPaymentRequest(request, url, uid, firestore, env) {
  if (url.pathname === '/payments/create' && request.method === 'POST') {
    return createPayOSPayment(await paymentInput(request), uid, firestore, env, url.origin);
  }
  const match = url.pathname.match(/^\/payments\/([^/]+)(?:\/(cancel))?$/);
  if (!match) throw new HttpError(404, 'Không tìm thấy dịch vụ thanh toán.');
  const paymentId = requiredId(match[1], 'Mã giao dịch');
  if (!match[2] && request.method === 'GET') {
    return paymentForPatient(paymentId, uid, firestore, env);
  }
  if (match[2] === 'cancel' && request.method === 'POST') {
    return cancelPayOSPayment(paymentId, await paymentInput(request), uid, firestore, env);
  }
  throw new HttpError(405, 'Phương thức thanh toán không được hỗ trợ.');
}

async function paymentInput(request) {
  const length = Number(request.headers.get('content-length') || 0);
  if (length > maxBodyBytes) throw new HttpError(400, 'Yêu cầu thanh toán quá lớn.');
  let body;
  try { body = await request.json(); } catch (_) { throw new HttpError(400, 'Dữ liệu thanh toán không hợp lệ.'); }
  if (!body || typeof body !== 'object' || Array.isArray(body) || JSON.stringify(body).length > maxBodyBytes) {
    throw new HttpError(400, 'Dữ liệu thanh toán không hợp lệ.');
  }
  return body;
}

export async function activePatientForPayment(tx, uid, patientId) {
  const account = await tx.get(`TAI_KHOAN/${uid}`);
  if (!account || account.data.role !== 'patient' || account.data.isActive !== true ||
      !['ACTIVE', 'APPROVED'].includes(account.data.status)) {
    throw new HttpError(403, 'Tài khoản bệnh nhân không còn hoạt động.');
  }
  // An account may manage several profiles. Authorize the exact patient tied
  // to the appointment/payment rather than requiring a single profile whose
  // authUserId happens to equal the account UID.
  const patient = await tx.get(`BENH_NHAN/${requiredId(patientId, 'Mã hồ sơ')}`);
  const ownerId = textOrEmpty(patient?.data?.ownerUserId) || textOrEmpty(patient?.data?.authUserId);
  if (!patient || ownerId !== uid || patient.data.isActive === false || patient.data.status === 'ARCHIVED') {
    throw new HttpError(403, 'Không tìm thấy hồ sơ bệnh nhân đang hoạt động.');
  }
  return { id: patient.id, ...patient.data };
}

function payableAmount(appointment, doctor) {
  const fee = Number.isFinite(appointment.consultationFeeSnapshot)
    ? appointment.consultationFeeSnapshot
    : doctor.consultationFee;
  const perPerson = boundedNumber(fee, 'Phí khám', 1000, 100000000, true);
  const people = boundedNumber(appointment.peopleCount ?? 1, 'Số người', 1, 100, true);
  const amount = perPerson * people;
  if (!Number.isSafeInteger(amount) || amount > 100000000) {
    throw new HttpError(409, 'Số tiền thanh toán không hợp lệ.');
  }
  return amount;
}

function paymentJson(id, data) {
  return {
    id,
    appointmentId: textOrEmpty(data.appointmentId),
    amount: numberOrZero(data.amount),
    status: textOrEmpty(data.status) || 'PENDING',
    paymentMethod: textOrEmpty(data.paymentMethod) || 'PAYOS',
    orderCode: typeof data.orderCode === 'number' ? data.orderCode : null,
    checkoutUrl: textOrEmpty(data.checkoutUrl) || null,
    qrCode: textOrEmpty(data.qrCode) || null,
    paymentLinkId: textOrEmpty(data.paymentLinkId) || null,
    transactionCode: textOrEmpty(data.transactionCode) || null,
    expiresAt: data.expiresAt instanceof Date ? data.expiresAt.toISOString() : null,
    paidAt: data.paidAt instanceof Date ? data.paidAt.toISOString() : null,
  };
}

async function paymentForPatient(paymentId, uid, firestore, env) {
  const snapshot = await firestore.readTransaction(async (tx) => {
    const payment = await tx.get(`THANH_TOAN/${paymentId}`);
    if (!payment) throw new HttpError(404, 'Không tìm thấy giao dịch thanh toán.');
    const patient = await activePatientForPayment(tx, uid, payment.data.patientId);
    if (payment.data.patientId !== patient.id) throw new HttpError(404, 'Không tìm thấy giao dịch thanh toán.');
    return { patientId: patient.id, payment: payment.data };
  });
  // Webhooks are the primary confirmation channel. This provider lookup is a
  // signed, user-initiated reconciliation fallback for when a mobile user
  // returns before PayOS has delivered/retried its webhook.
  if (!['CREATING', 'PENDING'].includes(snapshot.payment.status) || !snapshot.payment.orderCode) {
    return paymentJson(paymentId, snapshot.payment);
  }
  const provider = await getPayOSPaymentLink(payosConfig(env), snapshot.payment.orderCode);
  if (provider.orderCode !== snapshot.payment.orderCode || provider.amount !== snapshot.payment.amount) {
    throw new HttpError(409, 'Thông tin đối soát PayOS không khớp giao dịch.');
  }
  if (!['PAID', 'CANCELLED', 'EXPIRED'].includes(provider.status)) {
    return paymentJson(paymentId, snapshot.payment);
  }
  return firestore.runTransaction(async (tx) => {
    const current = await tx.get(`THANH_TOAN/${paymentId}`);
    if (!current || current.data.patientId !== snapshot.patientId) throw new HttpError(404, 'Không tìm thấy giao dịch thanh toán.');
    if (current.data.status === 'PAID') return paymentJson(paymentId, current.data);
    const status = provider.status === 'PAID' ? 'PAID' : provider.status === 'CANCELLED' ? 'CANCELLED' : 'FAILED';
    const changes = status === 'PAID'
      ? { status, paymentLinkId: provider.paymentLinkId || current.data.paymentLinkId || '', transactionCode: provider.reference || '', paidAt: serverTimestamp(), updatedAt: serverTimestamp() }
      : { status, providerCode: provider.status, providerDescription: 'PayOS đối soát: liên kết không còn hiệu lực.', updatedAt: serverTimestamp() };
    tx.update(`THANH_TOAN/${paymentId}`, changes);
    tx.create(`NHAT_KY_ADMIN/payment_reconcile_${paymentId}`, {
      actorId: 'payos-status-check', action: status === 'PAID' ? 'paymentPaid' : 'paymentFailed', targetCollection: 'THANH_TOAN', targetId: paymentId,
      reason: 'Đối soát trạng thái trực tiếp với PayOS.', before: { status: current.data.status }, after: changes, createdAt: serverTimestamp(),
    });
    if (status === 'PAID') await confirmPaidAppointment(tx, paymentId, current.data, 'payos-status-check');
    else await releasePendingAppointment(tx, current.data, 'Thanh toán PayOS không hoàn tất.');
    return paymentJson(paymentId, { ...current.data, ...changes });
  });
}

async function createPayOSPayment(body, uid, firestore, env, requestOrigin) {
  const appointmentId = requiredId(body.appointmentId, 'Mã lịch hẹn');
  const requestId = requiredId(body.requestId, 'Mã yêu cầu');
  const paymentId = `pay_${requestId}`;
  const prepared = await firestore.runTransaction(async (tx) => {
    const appointment = await tx.get(`LICH_HEN/${appointmentId}`);
    if (!appointment) throw new HttpError(404, 'Không tìm thấy lịch hẹn cần thanh toán.');
    const patient = await activePatientForPayment(tx, uid, appointment.data.patientId);
    if (appointment.data.patientId !== patient.id) throw new HttpError(404, 'Không tìm thấy lịch hẹn cần thanh toán.');
    if (appointment.data.status !== 'PENDING') {
      throw new HttpError(409, 'Chỉ tạo thanh toán cho lịch hẹn đang chờ thanh toán.');
    }
    const alreadyPaid = await tx.query('THANH_TOAN', [{ field: 'appointmentId', op: 'EQUAL', value: appointmentId }], 20);
    if (alreadyPaid.some((row) => row.data.status === 'PAID')) {
      throw new HttpError(409, 'Lịch hẹn này đã được thanh toán.');
    }
    const existing = await tx.get(`THANH_TOAN/${paymentId}`);
    if (existing) {
      if (existing.data.patientId !== patient.id || existing.data.appointmentId !== appointmentId) {
        throw new HttpError(409, 'Mã yêu cầu đã được dùng cho giao dịch khác.');
      }
      return { payment: paymentJson(paymentId, existing.data), patient };
    }
    const activePending = alreadyPaid.find((row) => ['CREATING', 'PENDING'].includes(row.data.status));
    if (activePending) return { payment: paymentJson(activePending.id, activePending.data), patient };
    const doctor = await tx.get(`BAC_SI/${requiredId(appointment.data.doctorId, 'Bác sĩ')}`);
    if (!doctor) throw new HttpError(409, 'Không tìm thấy bác sĩ của lịch hẹn.');
    const amount = payableAmount(appointment.data, doctor.data);
    const orderCode = nextPayOSOrderCode();
    // Randomness makes a collision extremely unlikely, but it is not a
    // business guarantee. Refuse the transaction before it is persisted so a
    // client retry gets a fresh order code rather than two Firestore payments
    // pointing at one PayOS order.
    const sameOrder = await tx.query('THANH_TOAN', [
      { field: 'orderCode', op: 'EQUAL', value: orderCode },
    ], 1);
    if (sameOrder.length) {
      throw new HttpError(503, 'Đang tạo mã thanh toán mới. Vui lòng thử lại.');
    }
    const record = {
      patientId: patient.id, appointmentId, amount, paymentMethod: 'PAYOS', status: 'CREATING',
      orderCode, requestId, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    tx.create(`THANH_TOAN/${paymentId}`, record);
    tx.create(`NHAT_KY_ADMIN/payment_create_${paymentId}`, {
      actorId: uid, action: 'paymentCreate', targetCollection: 'THANH_TOAN', targetId: paymentId,
      reason: 'Bệnh nhân tạo yêu cầu thanh toán PayOS.', before: null, after: { appointmentId, amount, orderCode }, createdAt: serverTimestamp(),
    });
    return { payment: paymentJson(paymentId, { ...record, id: paymentId }), patient };
  });
  if (prepared.payment.checkoutUrl) return prepared.payment;
  if (prepared.payment.status === 'PENDING') return prepared.payment;
  const config = payosConfig(env, requestOrigin);
  let link;
  try {
    link = await createPayOSLink(config, prepared.payment);
  } catch (error) {
    await firestore.runTransaction(async (tx) => {
      const current = await tx.get(`THANH_TOAN/${prepared.payment.id}`);
      if (current && current.data.status === 'CREATING') {
        tx.update(`THANH_TOAN/${prepared.payment.id}`, { status: 'CREATE_FAILED', updatedAt: serverTimestamp() });
      }
    });
    throw error;
  }
  return firestore.runTransaction(async (tx) => {
    const current = await tx.get(`THANH_TOAN/${prepared.payment.id}`);
    if (!current) throw new HttpError(409, 'Yêu cầu thanh toán không còn tồn tại.');
    if (current.data.patientId !== prepared.patient.id) throw new HttpError(403, 'Không thể xác nhận giao dịch của hồ sơ khác.');
    if (current.data.status === 'PAID') return paymentJson(prepared.payment.id, current.data);
    const expiresAt = new Date(link.expiresAt * 1000);
    const changes = {
      status: 'PENDING', paymentLinkId: link.paymentLinkId, checkoutUrl: link.checkoutUrl,
      qrCode: link.qrCode || '', expiresAt, updatedAt: serverTimestamp(),
    };
    tx.update(`THANH_TOAN/${prepared.payment.id}`, changes);
    return paymentJson(prepared.payment.id, { ...current.data, ...changes });
  });
}

async function cancelPayOSPayment(paymentId, body, uid, firestore, env) {
  const reason = optionalText(body.reason, 250) || 'Bệnh nhân hủy thanh toán.';
  const current = await firestore.readTransaction(async (tx) => {
    const payment = await tx.get(`THANH_TOAN/${paymentId}`);
    if (!payment) throw new HttpError(404, 'Không tìm thấy giao dịch thanh toán.');
    const patient = await activePatientForPayment(tx, uid, payment.data.patientId);
    if (payment.data.patientId !== patient.id) throw new HttpError(404, 'Không tìm thấy giao dịch thanh toán.');
    if (!['CREATING', 'PENDING', 'CREATE_FAILED'].includes(payment.data.status)) {
      throw new HttpError(409, 'Giao dịch này không thể hủy.');
    }
    return payment.data;
  });
  if (current.paymentLinkId) await cancelPayOSLink(payosConfig(env), current.orderCode, reason);
  return firestore.runTransaction(async (tx) => {
    const latest = await tx.get(`THANH_TOAN/${paymentId}`);
    if (!latest || latest.data.patientId !== current.patientId) throw new HttpError(404, 'Không tìm thấy giao dịch thanh toán.');
    if (latest.data.status === 'PAID') throw new HttpError(409, 'Giao dịch đã thanh toán, không thể hủy link.');
    const changes = { status: 'CANCELLED', cancellationReason: reason, cancelledAt: serverTimestamp(), updatedAt: serverTimestamp() };
    tx.update(`THANH_TOAN/${paymentId}`, changes);
    await releasePendingAppointment(tx, latest.data, reason);
    return paymentJson(paymentId, { ...latest.data, ...changes });
  });
}

/// A pending appointment is a short-lived, paid-only reservation. It becomes
/// visible as a confirmed appointment only after PayOS has been independently
/// verified, never merely because the user returned from a checkout URL.
async function confirmPaidAppointment(tx, paymentId, payment, actor) {
  const appointmentId = requiredId(payment.appointmentId, 'Mã lịch hẹn');
  const appointment = await tx.get(`LICH_HEN/${appointmentId}`);
  if (!appointment || appointment.data.patientId !== payment.patientId) {
    throw new HttpError(409, 'Lịch hẹn của giao dịch thanh toán không hợp lệ.');
  }
  if (appointment.data.status === 'CONFIRMED') return;
  if (appointment.data.status !== 'PENDING') {
    throw new HttpError(409, 'Lịch hẹn không còn chờ thanh toán.');
  }
  tx.update(`LICH_HEN/${appointmentId}`, {
    status: 'CONFIRMED', updatedAt: serverTimestamp(),
  });
  tx.create(`THONG_BAO/booking_paid_${paymentId}`, {
    title: 'Đặt lịch thành công',
    content: `Thanh toán PayOS đã được xác nhận. Lịch khám ngày ${dayKey(appointment.data.appointmentDate)}, lúc ${textOrEmpty(appointment.data.startTime)} đã được ghi nhận.`,
    patientId: payment.patientId, appointmentId, status: 'SENT', channel: 'in_app',
    isRead: false, createdAt: serverTimestamp(), createdBy: actor,
  });
}

/// A cancelled, expired, or failed payment must return its temporary slot so
/// another patient can book it. Confirmed appointments are deliberately left
/// untouched to make this idempotent against late provider callbacks.
async function releasePendingAppointment(tx, payment, reason) {
  const appointmentId = requiredId(payment.appointmentId, 'Mã lịch hẹn');
  const appointment = await tx.get(`LICH_HEN/${appointmentId}`);
  if (!appointment || appointment.data.patientId !== payment.patientId) {
    throw new HttpError(409, 'Lịch hẹn của giao dịch thanh toán không hợp lệ.');
  }
  if (appointment.data.status !== 'PENDING') return;
  const slotId = requiredId(appointment.data.timeSlotId, 'Ca khám');
  const slot = await tx.get(`CA_KHAM/${slotId}`);
  if (!slot) throw new HttpError(409, 'Ca khám giữ chỗ không còn tồn tại.');
  const peopleCount = boundedNumber(appointment.data.peopleCount ?? 1, 'Số người', 1, 100, true);
  const appointments = await tx.query('LICH_HEN', [{ field: 'timeSlotId', op: 'EQUAL', value: slotId }], 301);
  const reservations = exactReservationCounts(slot.data, appointments);
  if (reservations[appointmentId] !== peopleCount) {
    throw new HttpError(409, 'Dữ liệu giữ chỗ không nhất quán; không thể hoàn chỗ.');
  }
  delete reservations[appointmentId];
  const pointer = appointments.find((row) => row.id !== appointmentId && heldStatus(row.data.status));
  tx.update(`LICH_HEN/${appointmentId}`, {
    status: 'CANCELLED', cancellationReason: reason, updatedAt: serverTimestamp(),
  });
  tx.update(`CA_KHAM/${slotId}`, {
    ...capacityChange(slot.data, -peopleCount), appointmentId: pointer?.id ?? deleteField(),
    reservationCounts: reservations, updatedAt: serverTimestamp(),
  });
}

function nextPayOSOrderCode() {
  // The value remains within JavaScript's safe integer range and has a
  // one-million-value random suffix per second, avoiding a client-controlled
  // order number or accidental reuse after a retry.
  return Math.floor(Date.now() / 1000) * 1_000_000 + crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
}

function payosConfig(env, origin = null) {
  const clientId = requiredText(env.PAYOS_CLIENT_ID, 'PayOS Client ID', 300);
  const apiKey = requiredText(env.PAYOS_API_KEY, 'PayOS API Key', 500);
  const checksumKey = requiredText(env.PAYOS_CHECKSUM_KEY, 'PayOS Checksum Key', 500);
  const base = origin || 'https://healway-admin-command.healway-hospital.workers.dev';
  const returnUrl = validExternalUrl(env.PAYOS_RETURN_URL || `${base}/payments/return`, 'PayOS return URL');
  const cancelUrl = validExternalUrl(env.PAYOS_CANCEL_URL || `${base}/payments/cancel`, 'PayOS cancel URL');
  return { clientId, apiKey, checksumKey, returnUrl, cancelUrl };
}

function validExternalUrl(value, label) {
  let uri;
  try { uri = new URL(value); } catch (_) { throw new HttpError(503, `${label} không hợp lệ.`); }
  if (uri.protocol !== 'https:' || uri.username || uri.password || uri.search || uri.hash) {
    throw new HttpError(503, `${label} phải là URL HTTPS hợp lệ.`);
  }
  return uri.toString();
}

async function createPayOSLink(config, payment) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    orderCode: payment.orderCode, amount: payment.amount, description: `KHAM ${payment.orderCode}`,
    cancelUrl: config.cancelUrl, returnUrl: config.returnUrl, expiredAt: now + 15 * 60,
    items: [{ name: 'Phí khám', quantity: 1, price: payment.amount }],
  };
  payload.signature = await payosSignature({
    amount: payload.amount, cancelUrl: payload.cancelUrl, description: payload.description,
    orderCode: payload.orderCode, returnUrl: payload.returnUrl,
  }, config.checksumKey);
  let response;
  try {
    response = await fetch('https://api-merchant.payos.vn/v2/payment-requests', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'x-client-id': config.clientId, 'x-api-key': config.apiKey }, body: JSON.stringify(payload),
    });
  } catch (_) { throw new HttpError(503, 'Không thể kết nối cổng thanh toán PayOS.'); }
  const body = await safeJson(response);
  if (!response.ok || body?.code !== '00' || !body?.data?.checkoutUrl || !body?.data?.paymentLinkId) {
    throw new HttpError(503, 'PayOS chưa tạo được liên kết thanh toán. Vui lòng thử lại.');
  }
  return { paymentLinkId: body.data.paymentLinkId, checkoutUrl: body.data.checkoutUrl, qrCode: body.data.qrCode, expiresAt: Number(body.data.expiredAt || payload.expiredAt) };
}

async function cancelPayOSLink(config, orderCode, reason) {
  const response = await fetch(`https://api-merchant.payos.vn/v2/payment-requests/${encodeURIComponent(String(orderCode))}/cancel`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'x-client-id': config.clientId, 'x-api-key': config.apiKey }, body: JSON.stringify({ cancellationReason: reason }),
  });
  const body = await safeJson(response);
  if (!response.ok || body?.code !== '00') throw new HttpError(503, 'PayOS chưa hủy được liên kết thanh toán.');
}

async function getPayOSPaymentLink(config, orderCode) {
  let response;
  try {
    response = await fetch(`https://api-merchant.payos.vn/v2/payment-requests/${encodeURIComponent(String(orderCode))}`, {
      headers: { 'x-client-id': config.clientId, 'x-api-key': config.apiKey },
    });
  } catch (_) { throw new HttpError(503, 'Không thể đối soát trạng thái với PayOS.'); }
  const body = await safeJson(response);
  if (!response.ok || body?.code !== '00' || !body?.data || typeof body.signature !== 'string') {
    throw new HttpError(503, 'PayOS chưa trả được trạng thái giao dịch.');
  }
  const expected = await payosSignature(body.data, config.checksumKey);
  if (!secureEqual(body.signature, expected)) throw new HttpError(502, 'Phản hồi PayOS có chữ ký không hợp lệ.');
  const data = objectValue(body.data);
  return {
    orderCode: boundedNumber(data.orderCode, 'Mã đơn PayOS', 1, Number.MAX_SAFE_INTEGER, true),
    amount: boundedNumber(data.amount, 'Số tiền PayOS', 1, 100000000, true),
    status: requiredText(data.status, 'Trạng thái PayOS', 30).toUpperCase(),
    paymentLinkId: textOrEmpty(data.id) || textOrEmpty(data.paymentLinkId),
    reference: textOrEmpty(data.reference),
  };
}

async function payosWebhook(request, env) {
  const body = await paymentInput(request);
  const signature = requiredText(body.signature, 'Chữ ký PayOS', 200);
  const data = objectValue(body.data);
  const expected = await payosSignature(data, requiredText(env.PAYOS_CHECKSUM_KEY, 'PayOS Checksum Key', 500));
  if (!secureEqual(signature, expected)) throw new HttpError(401, 'Webhook PayOS có chữ ký không hợp lệ.');
  const orderCode = boundedNumber(data.orderCode, 'Mã đơn PayOS', 1, Number.MAX_SAFE_INTEGER, true);
  const firestore = new FirestoreRest(env);
  return firestore.runTransaction(async (tx) => {
    const rows = await tx.query('THANH_TOAN', [{ field: 'orderCode', op: 'EQUAL', value: orderCode }], 2);
    // PayOS sends a signed sample when a webhook URL is registered. Acknowledge
    // an unknown order without ever creating a transaction from it.
    if (rows.length === 0) return { acknowledged: true, sample: true };
    if (rows.length !== 1) throw new HttpError(409, 'Mã đơn PayOS không duy nhất.');
    const payment = rows[0];
    if (payment.data.paymentLinkId && payment.data.paymentLinkId !== data.paymentLinkId) {
      throw new HttpError(409, 'Liên kết PayOS không khớp giao dịch.');
    }
    const amount = boundedNumber(data.amount, 'Số tiền PayOS', 1, 100000000, true);
    if (amount !== payment.data.amount) throw new HttpError(409, 'Số tiền PayOS không khớp giao dịch.');
    if (payment.data.status === 'PAID') return { acknowledged: true, paymentId: payment.id, status: 'PAID', duplicate: true };
    const paid = body.success === true && data.code === '00';
    const changes = paid
      ? { status: 'PAID', paymentLinkId: data.paymentLinkId, transactionCode: textOrEmpty(data.reference), paidAt: serverTimestamp(), updatedAt: serverTimestamp() }
      : { status: 'FAILED', paymentLinkId: data.paymentLinkId, providerCode: textOrEmpty(data.code), providerDescription: textOrEmpty(data.desc), updatedAt: serverTimestamp() };
    tx.update(`THANH_TOAN/${payment.id}`, changes);
    tx.create(`NHAT_KY_ADMIN/payment_webhook_${payment.id}`, {
      actorId: 'payos-webhook', action: paid ? 'paymentPaid' : 'paymentFailed', targetCollection: 'THANH_TOAN', targetId: payment.id,
      reason: paid ? 'PayOS xác nhận thanh toán.' : 'PayOS báo giao dịch không thành công.', before: { status: payment.data.status }, after: changes, createdAt: serverTimestamp(),
    });
    if (paid) await confirmPaidAppointment(tx, payment.id, payment.data, 'payos-webhook');
    else await releasePendingAppointment(tx, payment.data, 'Thanh toán PayOS thất bại.');
    return { acknowledged: true, paymentId: payment.id, status: changes.status };
  });
}

export async function payosSignature(data, checksumKey) {
  // Keep this aligned with PayOS' payment-request JavaScript sample. In
  // particular, a plain object such as `transactions: {}` is coerced by its
  // template literal to "[object Object]"; JSON-stringifying it instead
  // produces a different HMAC and rejects a genuine status response.
  const values = Object.entries(objectValue(data))
    .filter(([, value]) => value !== undefined)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, source]) => {
      let value = source;
      if (Array.isArray(value)) {
        value = JSON.stringify(value.map((item) =>
          item && typeof item === 'object' && !Array.isArray(item)
            ? Object.fromEntries(Object.keys(item).sort().map((nestedKey) => [nestedKey, item[nestedKey]]))
            : item,
        ));
      }
      if ([null, undefined, 'undefined', 'null'].includes(value)) value = '';
      return `${key}=${String(value)}`;
    })
    .join('&');
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(checksumKey), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(values));
  return [...new Uint8Array(signature)].map((value) => value.toString(16).padStart(2, '0')).join('');
}

function secureEqual(left, right) {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return mismatch === 0;
}

function paymentReturnPage(success, headers) {
  const pageHeaders = new Headers(headers);
  pageHeaders.set('Content-Type', 'text/html; charset=UTF-8');
  pageHeaders.set('Cache-Control', 'no-store');
  const title = success ? 'Đã quay lại từ PayOS' : 'Đã hủy thanh toán';
  const content = success
    ? 'Yêu cầu thanh toán đã được gửi. Hãy quay lại ứng dụng và bấm “Kiểm tra trạng thái”. Chỉ webhook PayOS đã xác thực mới xác nhận giao dịch.'
    : 'Bạn đã hủy trên trang PayOS. Hãy quay lại ứng dụng để hủy hoặc tạo lại liên kết khi cần.';
  return new Response(`<!doctype html><html lang="vi"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><body style="font-family:system-ui;max-width:560px;margin:48px auto;padding:0 20px"><h1>${title}</h1><p>${content}</p></body></html>`, { status: 200, headers: pageHeaders });
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
  if (url.pathname === '/doctor/profile' && request.method === 'POST') {
    return firestore.runTransaction(async (tx) => updateDoctorPersonalProfile(request, uid, tx));
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
  const completion = url.pathname.match(/^\/doctor\/appointments\/([^/]+)\/complete$/);
  if (completion && request.method === 'POST') {
    return completeDoctorAppointment(request, uid, firestore, requiredId(decodeURIComponent(completion[1]), 'Mã lịch hẹn'));
  }
  if (url.pathname === '/doctor/examinations' && request.method === 'POST') {
    return startDoctorExamination(request, uid, firestore);
  }
  const awaitingResults = url.pathname.match(/^\/doctor\/examinations\/([^/]+)\/awaiting-results$/);
  if (awaitingResults && request.method === 'POST') {
    return markDoctorExaminationAwaitingResults(
      request,
      uid,
      firestore,
      requiredId(decodeURIComponent(awaitingResults[1]), 'Mã lịch hẹn'),
    );
  }
  const patientHistory = url.pathname.match(/^\/doctor\/patients\/([^/]+)\/history$/);
  if (patientHistory && request.method === 'GET') {
    return doctorPatientHistory(
      uid,
      firestore,
      requiredId(decodeURIComponent(patientHistory[1]), 'Mã bệnh nhân'),
    );
  }
  if (url.pathname === '/doctor/health-records' && request.method === 'POST') {
    return saveClinicalRecord(request, uid, firestore, 'health');
  }
  if (url.pathname === '/doctor/health-records' && request.method === 'GET') {
    return clinicalRecordsForAppointment(url, uid, firestore, 'health');
  }
  if (url.pathname === '/doctor/clinical-orders' && request.method === 'POST') {
    return saveClinicalOrder(request, uid, firestore);
  }
  if (url.pathname === '/doctor/clinical-orders' && request.method === 'GET') {
    return clinicalOrdersForAppointment(url, uid, firestore);
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
  const specialty = doctor.specialtyId
    ? await tx.get(`CHUYEN_KHOA/${doctor.specialtyId}`)
    : null;
  const doctorProfile = {
    ...doctor,
    specialtyName: textOrEmpty(doctor.specialtyName) || textOrEmpty(specialty?.data?.name),
  };
  // Query the selected day on Firestore instead of reading an arbitrary first
  // 301 historical records and filtering in memory. A busy doctor must still
  // see today's work after accumulating a long schedule history.
  const scheduleRows = await tx.query('LICH_LAM_VIEC', [
    { field: 'doctorId', op: 'EQUAL', value: doctor.id },
    { field: 'workDate', op: 'EQUAL', value: date },
  ], 301);
  const schedules = scheduleRows.map((row) => scheduleJson(row.id, row.data));
  const scheduleIds = new Set(schedules.map((row) => row.id));
  const slotPages = await Promise.all(
    schedules.map((schedule) => tx.query('CA_KHAM', [
      { field: 'workScheduleId', op: 'EQUAL', value: schedule.id },
    ], 301)),
  );
  const slots = slotPages.flat().map((row) => slotJson(row.id, row.data));
  const appointmentRows = await tx.query('LICH_HEN', [
    { field: 'doctorId', op: 'EQUAL', value: doctor.id },
    { field: 'appointmentDate', op: 'EQUAL', value: date },
  ], 301);
  const appointments = appointmentRows.filter((row) => scheduleIds.has(row.data.workScheduleId));
  const examinations = new Map();
  for (const row of appointments) {
    examinations.set(row.id, await tx.get(`PHIEU_KHAM/${row.id}`));
  }
  const patients = new Map();
  for (const row of appointments) {
    const patientId = requiredId(row.data.patientId, 'Hồ sơ bệnh nhân');
    if (!patients.has(patientId)) patients.set(patientId, await tx.get(`BENH_NHAN/${patientId}`));
  }
  const bookings = appointments.map((row) => {
    const patient = patients.get(row.data.patientId)?.data || {};
    return {
      appointment: appointmentJson(row.id, row.data, examinations.get(row.id)?.data),
      patientName: typeof patient.fullName === 'string' && patient.fullName.trim() ? patient.fullName.trim() : 'Bệnh nhân',
      ...(birthYear(patient.dateOfBirth) == null ? {} : { birthYear: birthYear(patient.dateOfBirth) }),
      ...(typeof patient.gender === 'string' && patient.gender.trim() ? { gender: patient.gender.trim() } : {}),
    };
  });
  return { doctor: doctorJson(doctorProfile), schedules, slots, bookings };
}

async function updateDoctorPersonalProfile(request, uid, tx) {
  let body;
  try { body = await request.json(); } catch (_) { throw new HttpError(400, 'Thông tin hồ sơ không hợp lệ.'); }
  const doctor = await activeDoctor(tx, uid);
  const fullName = requiredText(body?.fullName, 'Họ và tên', 120);
  const email = requiredText(body?.email, 'Email liên hệ', 160);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new HttpError(400, 'Email liên hệ không hợp lệ.');
  const phone = requiredText(body?.phone, 'Số điện thoại', 16);
  if (!/^0\d{9,10}$/.test(phone)) throw new HttpError(400, 'Số điện thoại không hợp lệ.');
  const dateOfBirth = parseWorkDate(body?.dateOfBirth);
  if (dateOfBirth >= new Date()) throw new HttpError(400, 'Ngày sinh không hợp lệ.');
  tx.update(`BAC_SI/${doctor.id}`, { fullName, email, phone, dateOfBirth, updatedAt: serverTimestamp() });
  return { doctor: doctorJson({ ...doctor, fullName, email, phone, dateOfBirth }) };
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

/** A doctor may complete only their own, already-started confirmed visit.
 * Counts remain held for the historical slot; completing a visit never
 * reopens capacity or allows a terminal status to be reversed. */
async function completeDoctorAppointment(request, uid, firestore, appointmentId) {
  const body = await doctorJsonBody(request);
  // Reject unexpected fields now, so this endpoint cannot become a disguised
  // generic appointment-update API in a future app version.
  if (Object.keys(body).length !== 0) throw new HttpError(400, 'Nội dung hoàn tất khám không hợp lệ.');
  const requestId = requiredId(request.headers.get('Idempotency-Key'), 'Mã chống trùng');
  const fingerprint = await commandDigest({ action: 'completeAppointment', appointmentId });
  return firestore.runTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const receiptPath = `DOCTOR_APPOINTMENT_COMMANDS/${doctor.id}_${requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã chống trùng đã được dùng cho thao tác khác.');
      return receipt.data.result;
    }
    const appointment = await tx.get(`LICH_HEN/${appointmentId}`);
    if (!appointment || appointment.data.doctorId !== doctor.id || typeof appointment.data.patientId !== 'string') {
      throw new HttpError(403, 'Lịch hẹn không thuộc bác sĩ đang đăng nhập.');
    }
    if (!canDoctorComplete(appointment.data)) {
      throw new HttpError(409, 'Chỉ hoàn tất được lịch đã xác nhận sau khi giờ khám bắt đầu.');
    }
    const examination = await tx.get(`PHIEU_KHAM/${appointmentId}`);
    if (!examination || examination.data.doctorId !== doctor.id || examination.data.patientId !== appointment.data.patientId) {
      throw new HttpError(409, 'Hãy mở và ghi phiếu khám trước khi hoàn thành khám.');
    }
    if (examination.data.status !== 'IN_PROGRESS') {
      throw new HttpError(409, 'Phiếu khám đang chờ kết quả CLS. Hãy xem kết quả và kết luận trước khi hoàn thành.');
    }
    const healthRecords = await tx.query('HO_SO_SUC_KHOE', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
    if (!healthRecords.some((row) => row.data.appointmentId === appointmentId && row.data.patientId === appointment.data.patientId)) {
      throw new HttpError(409, 'Hãy ghi chẩn đoán hoặc kết luận trên phiếu khám trước khi hoàn thành.');
    }
    const changes = { status: 'COMPLETED', completedAt: serverTimestamp(), updatedAt: serverTimestamp() };
    const result = { id: appointmentId, status: 'COMPLETED', message: 'Đã hoàn tất khám và lưu lịch sử.' };
    tx.update(`LICH_HEN/${appointmentId}`, changes);
    tx.update(`PHIEU_KHAM/${appointmentId}`, {
      status: 'COMPLETED', completedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    tx.create(`NHAT_KY_Y_TE/${doctor.id}_complete_${requestId}`, {
      actorId: uid, doctorId: doctor.id, action: 'complete_appointment', collection: 'LICH_HEN',
      targetId: appointmentId, appointmentId, patientId: appointment.data.patientId,
      before: { status: appointment.data.status }, after: { status: 'COMPLETED' }, createdAt: serverTimestamp(),
    });
    tx.create(`THONG_BAO/doctor_complete_${appointmentId}`, {
      title: 'Lịch khám đã hoàn tất',
      content: `Lịch hẹn ${appointmentId} đã được bác sĩ hoàn tất. Bạn có thể xem lại lịch sử khám và hồ sơ liên quan.`,
      patientId: appointment.data.patientId, appointmentId, status: 'SENT', channel: 'in_app', isRead: false,
      createdAt: serverTimestamp(), createdBy: uid,
    });
    return result;
  });
}

// The initial clinical note and the laboratory/imaging work are different
// stages. Keeping this transition server-side prevents an APK from marking a
// visit as waiting for tests without a real examination sheet.
async function markDoctorExaminationAwaitingResults(request, uid, firestore, appointmentId) {
  const body = await doctorJsonBody(request);
  if (Object.keys(body).length !== 0) throw new HttpError(400, 'Nội dung chuyển chờ kết quả không hợp lệ.');
  const requestId = requiredId(request.headers.get('Idempotency-Key'), 'Mã chống trùng');
  const fingerprint = await commandDigest({ action: 'awaitingResults', appointmentId });
  return firestore.runTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const receiptPath = `DOCTOR_EXAMINATION_COMMANDS/${doctor.id}_${requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã chống trùng đã được dùng cho thao tác khác.');
      return receipt.data.result;
    }
    const appointment = await doctorAppointment(tx, doctor.id, appointmentId);
    const examination = await tx.get(`PHIEU_KHAM/${appointmentId}`);
    if (!examination || examination.data.doctorId !== doctor.id || examination.data.patientId !== appointment.patientId || examination.data.status !== 'IN_PROGRESS') {
      throw new HttpError(409, 'Phiếu khám phải đang được bác sĩ xử lý trước khi chờ kết quả CLS.');
    }
    const orders = await tx.query('CHI_DINH_CLS', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
    if (!orders.some((row) => row.data.appointmentId === appointmentId && row.data.patientId === appointment.patientId)) {
      throw new HttpError(409, 'Hãy lưu khám ban đầu và chỉ định CLS trước.');
    }
    const result = { id: appointmentId, status: 'WAITING_RESULTS', message: 'Đã chuyển phiếu khám sang chờ kết quả CLS.' };
    tx.update(`PHIEU_KHAM/${appointmentId}`, { status: result.status, updatedAt: serverTimestamp() });
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    tx.create(`NHAT_KY_Y_TE/${doctor.id}_awaiting_results_${requestId}`, {
      actorId: uid, doctorId: doctor.id, action: 'awaiting_clinical_results', collection: 'PHIEU_KHAM',
      targetId: appointmentId, appointmentId, patientId: appointment.patientId, createdAt: serverTimestamp(),
    });
    return result;
  });
}

// A single appointment owns one examination sheet. Using appointmentId as the
// document id makes this relationship immutable and idempotent.
async function startDoctorExamination(request, uid, firestore) {
  const body = await doctorJsonBody(request);
  if (Object.keys(body).length !== 1 || typeof body.appointmentId !== 'string') {
    throw new HttpError(400, 'Nội dung bắt đầu khám không hợp lệ.');
  }
  const appointmentId = requiredId(body.appointmentId, 'Mã lịch hẹn');
  const requestId = requiredId(request.headers.get('Idempotency-Key'), 'Mã chống trùng');
  const fingerprint = await commandDigest({ action: 'startExamination', appointmentId });
  return firestore.runTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const receiptPath = `DOCTOR_EXAMINATION_COMMANDS/${doctor.id}_${requestId}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã chống trùng đã được dùng cho thao tác khác.');
      return receipt.data.result;
    }
    const appointment = await doctorAppointment(tx, doctor.id, appointmentId);
    const patient = await tx.get(`BENH_NHAN/${appointment.patientId}`);
    if (!patient) throw new HttpError(409, 'Không tìm thấy hồ sơ bệnh nhân.');
    const path = `PHIEU_KHAM/${appointmentId}`;
    const existing = await tx.get(path);
    if (existing && (existing.data.doctorId !== doctor.id || existing.data.patientId !== appointment.patientId)) {
      throw new HttpError(403, 'Phiếu khám không thuộc lịch khám này.');
    }
    const patientCode = textOrEmpty(patient.data.patientCode) || textOrEmpty(appointment.patientCode);
    const fields = {
      patientId: appointment.patientId, patientCode, appointmentId, visitCode: `LK-${appointmentId}`,
      doctorId: doctor.id, specialtyId: textOrEmpty(appointment.specialtyId),
      status: 'IN_PROGRESS', reasonForVisit: textOrEmpty(appointment.reason),
      createdByDoctorId: doctor.id, updatedAt: serverTimestamp(),
    };
    if (existing) tx.update(path, fields);
    else tx.create(path, { ...fields, createdAt: serverTimestamp() });
    const result = { id: appointmentId, status: 'IN_PROGRESS', message: existing ? 'Đã mở lại phiếu khám.' : 'Đã tạo phiếu khám.' };
    tx.create(receiptPath, { fingerprint, result, createdAt: serverTimestamp() });
    tx.create(`NHAT_KY_Y_TE/${doctor.id}_start_${requestId}`, {
      actorId: uid, doctorId: doctor.id, action: existing ? 'resume_examination' : 'create_examination',
      collection: 'PHIEU_KHAM', targetId: appointmentId, appointmentId, patientId: appointment.patientId,
      createdAt: serverTimestamp(),
    });
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
  const orderId = kind === 'result' ? requiredId(body.orderId, 'Chỉ định CLS') : null;
  const prescription = kind === 'health' ? optionalText(body.prescription, 4000) : '';
  const shouldIssuePrescription = kind === 'health' && hasActualPrescription(prescription);
  const values = kind === 'health' ? {
    diagnosis: requiredText(body.diagnosis, 'Chẩn đoán', 1000),
    notes: optionalText(body.notes, 4000), prescription,
    recordType: choice(body.recordType || 'OUTPATIENT', ['OUTPATIENT', 'INPATIENT', 'CHECKUP'], 'Loại hồ sơ'),
    // A prescription must always be discoverable in the patient's
    // “Đơn thuốc” tab.  The document category therefore follows the actual
    // saved prescription instead of relying on the client to send a flag.
    documentCategory: shouldIssuePrescription ? 'PRESCRIPTION' : null,
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
    const order = orderId ? await tx.get(`CHI_DINH_CLS/${orderId}`) : null;
    if (orderId && (!order || order.data.doctorId !== doctor.id || order.data.appointmentId !== appointmentId || order.data.patientId !== appointment.patientId)) {
      throw new HttpError(403, 'Chỉ định CLS không thuộc phiếu khám này.');
    }
    const patient = await tx.get(`BENH_NHAN/${appointment.patientId}`);
    if (!patient) throw new HttpError(409, 'Không tìm thấy hồ sơ bệnh nhân.');
    const examination = await tx.get(`PHIEU_KHAM/${appointmentId}`);
    if (!examination) {
      // Saving clinical content is a safe fallback for an older client which
      // does not yet expose the explicit “Bắt đầu khám” action.
      tx.create(`PHIEU_KHAM/${appointmentId}`, {
        patientId: appointment.patientId,
        patientCode: textOrEmpty(patient.data.patientCode) || textOrEmpty(appointment.patientCode),
        appointmentId, visitCode: `LK-${appointmentId}`, doctorId: doctor.id,
        specialtyId: textOrEmpty(appointment.specialtyId), status: 'IN_PROGRESS',
        reasonForVisit: textOrEmpty(appointment.reason), createdByDoctorId: doctor.id,
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
    } else if (examination.data.doctorId !== doctor.id || examination.data.patientId !== appointment.patientId) {
      throw new HttpError(403, 'Phiếu khám không thuộc lịch khám này.');
    }
    const collection = kind === 'health' ? 'HO_SO_SUC_KHOE' : 'KET_QUA_CLS';
    let documentId = id || `${doctor.id}_${requestId}`;
    let path = `${collection}/${documentId}`;
    let existing = await tx.get(path);
    if (kind === 'health' && !id) {
      const priorRecords = await tx.query(
        'HO_SO_SUC_KHOE',
        [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }],
        301,
      );
      const matches = priorRecords
        .filter((row) => row.data.appointmentId === appointmentId)
        .sort((left, right) => right.id.localeCompare(left.id));
      if (matches.length > 0) {
        documentId = matches[0].id;
        path = `${collection}/${documentId}`;
        existing = matches[0];
        for (const duplicate of matches.slice(1)) tx.delete(`${collection}/${duplicate.id}`);
      }
    }
    if (kind === 'result' && !id) {
      const priorResults = await tx.query(
        'KET_QUA_CLS',
        [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }],
        301,
      );
      const matches = priorResults
        .filter((row) => row.data.orderId === orderId)
        .sort((left, right) => right.id.localeCompare(left.id));
      if (matches.length > 0) {
        // Saving again means correcting the same clinical result, not making
        // a second result. Keep the newest document and remove legacy twins.
        documentId = matches[0].id;
        path = `${collection}/${documentId}`;
        existing = matches[0];
        for (const duplicate of matches.slice(1)) tx.delete(`${collection}/${duplicate.id}`);
      }
    }
    if (existing && (existing.data.doctorId !== doctor.id || existing.data.patientId !== appointment.patientId || existing.data.appointmentId !== appointmentId)) {
      throw new HttpError(403, 'Không được sửa hồ sơ của lịch khám khác.');
    }
    const fields = {
      patientId: appointment.patientId,
      patientCode: textOrEmpty(patient.data.patientCode) || textOrEmpty(appointment.patientCode),
      doctorId: doctor.id, appointmentId, examinationId: appointmentId,
      ...(orderId ? { orderId } : {}),
      ...values,
      ...(kind === 'health'
        ? (existing ? {} : { recordDate: serverTimestamp() })
        : { ...(existing ? {} : { testDate: serverTimestamp() }), doctorName: textOrEmpty(doctor.fullName) }),
      updatedAt: serverTimestamp(),
    };
    if (existing) tx.update(path, fields);
    else tx.create(path, { ...fields, createdAt: serverTimestamp() });
    if (kind === 'health') {
      // A prescription is its own clinical document.  Keeping it separate
      // from the health-record narrative lets the patient open the
      // “Đơn thuốc” tab without relying on a note field, while this stable
      // per-appointment id makes subsequent corrections an update.
      const prescriptionPath = `DON_THUOC/DT_${appointmentId}`;
      if (shouldIssuePrescription) {
        const prescriptionFields = {
          patientId: appointment.patientId,
          patientCode: textOrEmpty(patient.data.patientCode) || textOrEmpty(appointment.patientCode),
          appointmentId,
          examinationId: appointmentId,
          healthRecordId: documentId,
          doctorId: doctor.id,
          specialtyId: textOrEmpty(appointment.specialtyId),
          diagnosis: values.diagnosis,
          instructions: prescription,
          status: 'ISSUED',
          issuedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        };
        const existingPrescription = await tx.get(prescriptionPath);
        if (existingPrescription) tx.update(prescriptionPath, prescriptionFields);
        else tx.create(prescriptionPath, { ...prescriptionFields, createdAt: serverTimestamp() });
      } else {
        const existingPrescription = await tx.get(prescriptionPath);
        if (existingPrescription && existingPrescription.data.status === 'ISSUED') {
          tx.update(prescriptionPath, { status: 'CANCELLED', updatedAt: serverTimestamp() });
        }
      }
    }
    if (kind === 'result') {
      // A result returned for this appointment brings the sheet back to the
      // doctor for a second clinical review. The doctor must explicitly
      // resume the sheet before they can complete the visit.
      tx.update(`PHIEU_KHAM/${appointmentId}`, {
        status: 'RESULTS_READY', updatedAt: serverTimestamp(),
      });
      tx.update(`CHI_DINH_CLS/${orderId}`, { status: 'RESULT_READY', resultId: documentId, updatedAt: serverTimestamp() });
    }
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

async function saveClinicalOrder(request, uid, firestore) {
  const body = await doctorJsonBody(request);
  const requestId = requiredId(request.headers.get('Idempotency-Key'), 'Mã chống trùng');
  const appointmentId = requiredId(body.appointmentId, 'Mã lịch hẹn');
  const testName = requiredText(body.testName, 'Tên chỉ định CLS', 300);
  const resultType = optionalText(body.resultType, 120) || 'Xét nghiệm';
  const notes = optionalText(body.notes, 1000);
  return firestore.runTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const appointment = await doctorAppointment(tx, doctor.id, appointmentId);
    const patient = await tx.get(`BENH_NHAN/${appointment.patientId}`);
    if (!patient) throw new HttpError(409, 'Không tìm thấy hồ sơ bệnh nhân.');
    const id = `${doctor.id}_${requestId}`;
    const result = { id, appointmentId, message: 'Đã thêm chỉ định CLS.' };
    tx.create(`CHI_DINH_CLS/${id}`, { patientId: appointment.patientId, doctorId: doctor.id, appointmentId,
      examinationId: appointmentId, testName, resultType, notes, status: 'PENDING', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    tx.create(`NHAT_KY_Y_TE/${doctor.id}_order_${requestId}`, { actorId: uid, doctorId: doctor.id, action: 'create_clinical_order', collection: 'CHI_DINH_CLS', targetId: id, appointmentId, patientId: appointment.patientId, createdAt: serverTimestamp() });
    return result;
  });
}

async function clinicalOrdersForAppointment(url, uid, firestore) {
  const appointmentId = requiredId(url.searchParams.get('appointmentId'), 'Mã lịch hẹn');
  return firestore.readTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    await doctorAppointment(tx, doctor.id, appointmentId, { allowCompleted: true });
    const rows = await tx.query('CHI_DINH_CLS', [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
    return { orders: rows.filter((row) => row.data.appointmentId === appointmentId).map((row) => ({ id: row.id, testName: textOrEmpty(row.data.testName), resultType: textOrEmpty(row.data.resultType) || 'Xét nghiệm', status: textOrEmpty(row.data.status) || 'PENDING', notes: textOrEmpty(row.data.notes) })) };
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

async function doctorAppointment(tx, doctorId, appointmentId, { allowCompleted = false } = {}) {
  const appointment = await tx.get(`LICH_HEN/${appointmentId}`);
  if (!appointment || appointment.data.doctorId !== doctorId ||
      !(allowCompleted ? ['CONFIRMED', 'COMPLETED'] : ['CONFIRMED']).includes(appointment.data.status) ||
      typeof appointment.data.patientId !== 'string') {
    throw new HttpError(403, 'Chỉ được ghi phiếu cho lịch khám đã xác nhận của chính bác sĩ.');
  }
  return appointment.data;
}

async function clinicalRecordsForAppointment(url, uid, firestore, kind) {
  const appointmentId = requiredId(url.searchParams.get('appointmentId'), 'Mã lịch hẹn');
  return firestore.readTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    await doctorAppointment(tx, doctor.id, appointmentId, { allowCompleted: true });
    const collection = kind === 'health' ? 'HO_SO_SUC_KHOE' : 'KET_QUA_CLS';
    const rows = await tx.query(collection, [{ field: 'doctorId', op: 'EQUAL', value: doctor.id }], 301);
    const appointmentRows = rows
      .filter((row) => row.data.appointmentId === appointmentId)
      .sort((left, right) => right.id.localeCompare(left.id));
    // One appointment has one clinical note. Legacy duplicates are retained
    // in storage until migration, but the doctor sees only the newest note.
    const sourceRows = kind === 'health' ? appointmentRows.slice(0, 1) : appointmentRows;
    const records = sourceRows
      .map((row) => kind === 'health'
        ? { id: row.id, diagnosis: textOrEmpty(row.data.diagnosis), notes: textOrEmpty(row.data.notes), prescription: textOrEmpty(row.data.prescription), recordType: textOrEmpty(row.data.recordType) || 'OUTPATIENT' }
        : { id: row.id, testName: textOrEmpty(row.data.testName), resultDescription: textOrEmpty(row.data.resultDescription), resultType: textOrEmpty(row.data.resultType) || 'Khác', conclusion: textOrEmpty(row.data.conclusion), referenceRange: textOrEmpty(row.data.referenceRange), orderId: textOrEmpty(row.data.orderId) || null })
      .sort((left, right) => left.id.localeCompare(right.id));
    return { records };
  });
}

/**
 * A doctor cannot search arbitrary patient charts. History becomes visible
 * only after this doctor has a confirmed or completed appointment with the
 * patient, and returns only records authored by that same doctor.
 */
async function doctorPatientHistory(uid, firestore, patientId) {
  return firestore.readTransaction(async (tx) => {
    const doctor = await activeDoctor(tx, uid);
    const visits = (await tx.query('LICH_HEN', [
      { field: 'doctorId', op: 'EQUAL', value: doctor.id },
    ], 301))
      .filter((row) => row.data.patientId === patientId && ['CONFIRMED', 'COMPLETED'].includes(row.data.status))
      .map((row) => ({ id: row.id, date: dayKey(row.data.appointmentDate), status: textOrEmpty(row.data.status) }))
      .filter((visit) => visit.date)
      .sort((left, right) => right.date.localeCompare(left.date) || right.id.localeCompare(left.id));
    if (!visits.length) {
      throw new HttpError(403, 'Bác sĩ chỉ xem lịch sử của bệnh nhân có lịch khám hợp lệ.');
    }
    const visitIds = new Set(visits.map((visit) => visit.id));
    const healthRows = (await tx.query('HO_SO_SUC_KHOE', [
      { field: 'doctorId', op: 'EQUAL', value: doctor.id },
    ], 301))
      .filter((row) => row.data.patientId === patientId && visitIds.has(row.data.appointmentId))
      .sort((left, right) => right.id.localeCompare(left.id));
    const seenHealthAppointments = new Set();
    const healthRecords = healthRows
      .filter((row) => {
        if (seenHealthAppointments.has(row.data.appointmentId)) return false;
        seenHealthAppointments.add(row.data.appointmentId);
        return true;
      })
      .map((row) => ({
        id: row.id, diagnosis: textOrEmpty(row.data.diagnosis), notes: textOrEmpty(row.data.notes),
        prescription: textOrEmpty(row.data.prescription), recordType: textOrEmpty(row.data.recordType) || 'OUTPATIENT',
      }));
    const testResults = (await tx.query('KET_QUA_CLS', [
      { field: 'doctorId', op: 'EQUAL', value: doctor.id },
    ], 301))
      .filter((row) => row.data.patientId === patientId && visitIds.has(row.data.appointmentId))
      .map((row) => ({
        id: row.id, testName: textOrEmpty(row.data.testName), resultDescription: textOrEmpty(row.data.resultDescription),
        resultType: textOrEmpty(row.data.resultType) || 'Khác', conclusion: textOrEmpty(row.data.conclusion),
        referenceRange: textOrEmpty(row.data.referenceRange),
      }));
    return { patientId, visits, healthRecords, testResults };
  });
}

export function doctorJson(data) {
  return {
    id: data.id, userId: data.userId, fullName: textOrEmpty(data.fullName), email: textOrEmpty(data.email), phone: textOrEmpty(data.phone),
    specialtyId: textOrEmpty(data.specialtyId), specialtyName: textOrEmpty(data.specialtyName), qualification: textOrEmpty(data.qualification),
    yearsOfExperience: numberOrZero(data.yearsOfExperience), consultationFee: numberOrZero(data.consultationFee),
    ...(data.dateOfBirth ? { dateOfBirth: dayKey(data.dateOfBirth) } : {}),
    isActive: data.isActive !== false, status: textOrEmpty(data.status) || 'ACTIVE', avatarUrl: textOrEmpty(data.avatarUrl),
  };
}
function scheduleJson(id, data) { return { id, doctorId: textOrEmpty(data.doctorId), workDate: dayKey(data.workDate), startTime: textOrEmpty(data.startTime), endTime: textOrEmpty(data.endTime), status: textOrEmpty(data.status) || 'ACTIVE' }; }
function slotJson(id, data) { return { id, workScheduleId: textOrEmpty(data.workScheduleId), doctorId: textOrEmpty(data.doctorId), startTime: textOrEmpty(data.startTime), endTime: textOrEmpty(data.endTime), status: textOrEmpty(data.status), capacity: numberOrZero(data.capacity), bookedCount: numberOrZero(data.bookedCount) }; }
function appointmentJson(id, data, examination = null) { return { id, patientId: textOrEmpty(data.patientId), doctorId: textOrEmpty(data.doctorId), workScheduleId: textOrEmpty(data.workScheduleId), timeSlotId: textOrEmpty(data.timeSlotId), specialtyId: textOrEmpty(data.specialtyId), appointmentDate: dayKey(data.appointmentDate), startTime: textOrEmpty(data.startTime), endTime: textOrEmpty(data.endTime), status: textOrEmpty(data.status), ...(textOrEmpty(examination?.status) ? { clinicalStatus: textOrEmpty(examination.status) } : {}), peopleCount: numberOrZero(data.peopleCount) || 1, ...(typeof data.queueNumber === 'number' ? { queueNumber: data.queueNumber } : {}), ...(typeof data.reason === 'string' ? { reason: data.reason } : {}) }; }
function doctorReportJson(id, data) { return { id, type: textOrEmpty(data.type), date: dayKey(data.date), reason: textOrEmpty(data.reason), status: textOrEmpty(data.status) || 'PENDING', adminResponse: typeof data.adminResponse === 'string' ? data.adminResponse : null }; }
function textOrEmpty(value) { return typeof value === 'string' ? value : ''; }

function hasActualPrescription(value) {
  const normalized = textOrEmpty(value)
    .trim()
    .toLocaleLowerCase('vi-VN')
    .replaceAll('đ', 'd')
    .replace(/\s+/g, ' ');
  return normalized.length > 0 &&
      !/^(k|hk|khong|ko|chua) co don thuoc[.!]?$/.test(normalized);
}
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
      const result = {
        id: authUserId,
        collection: 'BAC_SI',
        loginEmail,
        message:
            'Đã tạo hồ sơ và tài khoản bác sĩ. Mật khẩu đăng nhập ban đầu là Password123@.',
      };
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
    const existingPatientAppointments = await this.rows('LICH_HEN', 'patientId', patientId);
    if (hasActiveAppointmentForSpecialtyOnDay(existingPatientAppointments, target.schedule.workDate, target.doctor.specialtyId)) {
      throw new HttpError(409, `Bạn đã đặt lịch khoa này cho ngày ${dayKey(target.schedule.workDate)}. Mỗi hồ sơ chỉ được đặt một ca cho mỗi khoa trong ngày.`);
    }
    const id = this.command.requestId;
    const reason = optionalText(values.reason, 1000);
    const fields = {
      patientId,
      ...(textOrEmpty(patient.patientCode) ? { patientCode: textOrEmpty(patient.patientCode) } : {}),
      doctorId: target.slot.doctorId, workScheduleId: target.slot.workScheduleId,
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
    this.audit('LICH_HEN', id, null, fields);
    return { id, collection: 'LICH_HEN', message: 'Đã giữ chỗ, chờ thanh toán PayOS.' };
  }

  async assertOwnActivePatient(patient, patientId) {
    const account = await this.get('TAI_KHOAN', this.uid);
    if (account.role !== 'patient' || account.isActive !== true ||
        !['ACTIVE', 'APPROVED'].includes(account.status)) {
      throw new HttpError(403, 'Tài khoản bệnh nhân không còn hoạt động.');
    }
    const ownerUserId = textOrEmpty(patient.ownerUserId) || textOrEmpty(patient.authUserId);
    if (ownerUserId !== this.uid || patientId !== requiredId(patientId, 'Hồ sơ bệnh nhân')) {
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
    if (appointmentHasStarted(appointment)) {
      throw new HttpError(409, 'Không thể hủy lịch sau khi giờ khám đã bắt đầu.');
    }
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
    if (appointmentHasStarted(appointment)) {
      throw new HttpError(409, 'Không thể đổi lịch sau khi giờ khám đã bắt đầu.');
    }
    const peopleCount = boundedNumber(appointment.peopleCount ?? 1, 'Số người', 1, 100, true);
    const target = await this.destination(slotId, peopleCount);
    const patientAppointments = await this.rows('LICH_HEN', 'patientId', appointment.patientId);
    if (hasActiveAppointmentForSpecialtyOnDay(patientAppointments, target.schedule.workDate, target.doctor.specialtyId, id)) {
      throw new HttpError(409, `Bạn đã đặt lịch khoa này cho ngày ${dayKey(target.schedule.workDate)}. Mỗi hồ sơ chỉ được đặt một ca cho mỗi khoa trong ngày.`);
    }
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
    const patientAppointments = await this.rows('LICH_HEN', 'patientId', before.patientId);
    if (hasActiveAppointmentForSpecialtyOnDay(patientAppointments, target.schedule.workDate, target.doctor.specialtyId, id)) {
      throw new HttpError(409, `Hồ sơ đã có lịch hẹn khoa này ngày ${dayKey(target.schedule.workDate)}. Mỗi hồ sơ chỉ được đặt một ca cho mỗi khoa trong ngày.`);
    }
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
      startTime: target.slot.startTime, endTime: target.slot.endTime,
      // A new slot requires a new confirmation/check-in cycle. Queue and
      // check-in values belong to the old slot and must never be carried over.
      status: 'PENDING', queueNumber: deleteField(), checkInTime: deleteField(),
      rescheduleReason: this.command.reason,
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
    const linkedState = linkedAccountState(enabled);
    const accountChanges = { role, ...linkedState.account };
    this.tx.update(`TAI_KHOAN/${id}`, { ...accountChanges, updatedAt: serverTimestamp() });
    // A user account and its profile are one operational identity. Updating
    // only TAI_KHOAN left BENH_NHAN/BAC_SI looking active in the Admin UI and
    // created a confusing, partially locked state.
    for (const patient of patients) {
      this.tx.update(`BENH_NHAN/${patient.id}`, {
        ...linkedState.patient, updatedAt: serverTimestamp(),
      });
    }
    for (const doctor of doctors) {
      this.tx.update(`BAC_SI/${doctor.id}`, {
        ...linkedState.doctor,
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

// Keep the three documents that form one operational identity in sync. This
// is deliberately pure so the lock/unlock invariant has a fast unit test in
// addition to the transaction that applies it.
export function linkedAccountState(enabled) {
  return {
    account: { isActive: enabled, status: enabled ? 'ACTIVE' : 'INACTIVE' },
    patient: { isActive: enabled, status: enabled ? 'ACTIVE' : 'ARCHIVED' },
    doctor: {
      isActive: enabled,
      status: enabled ? 'ACTIVE' : 'INACTIVE',
      acceptingBookings: enabled,
    },
  };
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
    const password = INITIAL_DOCTOR_PASSWORD;
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
// Requested initial credential for a newly provisioned doctor account. It is
// sent only to Firebase Authentication; it is never stored in Firestore logs.
const INITIAL_DOCTOR_PASSWORD = 'Password123@';
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
export function hasActiveAppointmentForSpecialtyOnDay(rows, workDate, specialtyId, exceptId = null) {
  const targetDay = dayKey(workDate);
  return rows.some((row) =>
    row.id !== exceptId &&
    ['PENDING', 'CONFIRMED'].includes(row.data.status) &&
    row.data.appointmentDate &&
    row.data.specialtyId === specialtyId &&
    dayKey(row.data.appointmentDate) === targetDay,
  );
}
function workPeriod(workDate, startTime, endTime) {
  const date = parseWorkDate(workDate), start = timeMinutes(startTime), end = timeMinutes(endTime);
  if (start >= end) throw new HttpError(400, 'Giờ kết thúc phải sau giờ bắt đầu.');
  return { date, start, end };
}
function slotStart(workDate, startTime) {
  const day = workDate instanceof Date ? parseWorkDate(dayKey(workDate)) : parseWorkDate(workDate);
  return new Date(day.getTime() + timeMinutes(startTime) * 60000);
}
function slotEnd(workDate, endTime) { return slotStart(workDate, endTime); }
export function appointmentHasStarted(appointment, now = new Date()) {
  return slotStart(appointment.appointmentDate, appointment.startTime) <= now;
}
export function canDoctorComplete(appointment, now = new Date()) {
  return appointment?.status === 'CONFIRMED' && appointmentHasStarted(appointment, now);
}
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
  const headers = new Headers({ 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Access-Control-Allow-Headers': 'Authorization, Content-Type, Idempotency-Key', 'Content-Type': 'application/json; charset=UTF-8', Vary: 'Origin' });
  const origin = request.headers.get('Origin');
  const allowed = String(env.ALLOWED_ORIGINS || '').split(',').map((value) => value.trim()).filter(Boolean);
  if (origin && allowed.includes(origin)) headers.set('Access-Control-Allow-Origin', origin);
  return headers;
}
function json(value, status, headers) { return new Response(JSON.stringify(value), { status, headers }); }
