import assert from 'node:assert/strict';
import test from 'node:test';

import worker, {
  appointmentHasStarted,
  canDoctorComplete,
  doctorJson,
  executeCommand,
  linkedAccountState,
  payosSignature,
} from '../src/index.js';

async function commandFingerprint(command) {
  const canonical = Object.fromEntries(
    Object.keys(command).sort().map((key) => [key, command[key]]),
  );
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(JSON.stringify(canonical)),
  );
  return [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('');
}

test('a repeated admin command returns the receipt result instead of rerunning', async () => {
  const command = {
    requestId: 'retry-1',
    operation: 'saveSettings',
    reason: 'Kiểm thử gửi lại',
  };
  const result = { id: 'settings', message: 'Đã lưu.' };
  const firestore = {
    runTransaction: async (callback) =>
      callback({
        get: async () => ({
          id: 'admin_retry-1',
          data: {fingerprint: await commandFingerprint(command), result},
        }),
      }),
  };

  assert.deepEqual(await executeCommand(command, 'admin', firestore), result);
});

test('locking an account also archives the linked patient profile and disables the doctor profile', () => {
  assert.deepEqual(linkedAccountState(false), {
    account: { isActive: false, status: 'INACTIVE' },
    patient: { isActive: false, status: 'ARCHIVED' },
    doctor: { isActive: false, status: 'INACTIVE', acceptingBookings: false },
  });
});

test('unlocking an account restores all linked operational profiles', () => {
  assert.deepEqual(linkedAccountState(true), {
    account: { isActive: true, status: 'ACTIVE' },
    patient: { isActive: true, status: 'ACTIVE' },
    doctor: { isActive: true, status: 'ACTIVE', acceptingBookings: true },
  });
});

test('patients cannot cancel or reschedule an appointment once its start time has passed', () => {
  const now = new Date('2026-10-28T03:00:00.000Z');
  assert.equal(appointmentHasStarted({
    appointmentDate: new Date('2026-10-28T00:00:00.000Z'),
    startTime: '09:00',
  }, now), true);
  assert.equal(appointmentHasStarted({
    appointmentDate: new Date('2026-10-28T00:00:00.000Z'),
    startTime: '11:00',
  }, now), false);
});

test('only an already-started confirmed appointment can be completed by its doctor', () => {
  const now = new Date('2026-10-28T03:00:00.000Z');
  assert.equal(canDoctorComplete({
    status: 'CONFIRMED', appointmentDate: new Date('2026-10-28T00:00:00.000Z'), startTime: '09:00',
  }, now), true);
  assert.equal(canDoctorComplete({
    status: 'PENDING', appointmentDate: new Date('2026-10-28T00:00:00.000Z'), startTime: '09:00',
  }, now), false);
  assert.equal(canDoctorComplete({
    status: 'CONFIRMED', appointmentDate: new Date('2026-10-28T00:00:00.000Z'), startTime: '11:00',
  }, now), false);
});

test('doctor workspace projection includes the verified date of birth', () => {
  assert.equal(
    doctorJson({
      id: 'doctor-1',
      userId: 'account-1',
      dateOfBirth: new Date('1988-03-12T00:00:00.000Z'),
    }).dateOfBirth,
    '1988-03-12',
  );
});

test('doctor endpoints allow browser GET and idempotent POST preflight headers', async () => {
  const response = await worker.fetch(new Request('https://worker.test/doctor/day', {
    method: 'OPTIONS',
    headers: {
      Origin: 'https://bookinghospitalapp.web.app',
      'Access-Control-Request-Method': 'GET',
      'Access-Control-Request-Headers': 'authorization,content-type,idempotency-key',
    },
  }), {
    ALLOWED_ORIGINS: 'https://bookinghospitalapp.web.app',
  });
  assert.equal(response.status, 204);
  assert.match(response.headers.get('Access-Control-Allow-Methods'), /GET/);
  assert.match(response.headers.get('Access-Control-Allow-Headers'), /Idempotency-Key/i);
});

test('PayOS signatures are stable regardless of input key ordering', async () => {
  const key = 'demo-checksum-key';
  const signature = await payosSignature({
    amount: 200000,
    returnUrl: 'https://worker.test/payments/return',
    orderCode: 123456,
    description: 'KHAM 123456',
    cancelUrl: 'https://worker.test/payments/cancel',
  }, key);
  const reordered = await payosSignature({
    description: 'KHAM 123456',
    cancelUrl: 'https://worker.test/payments/cancel',
    orderCode: 123456,
    amount: 200000,
    returnUrl: 'https://worker.test/payments/return',
  }, key);
  assert.equal(signature, reordered);
  assert.match(signature, /^[a-f0-9]{64}$/);
});

test('PayOS payment-request signature matches its official webhook example', async () => {
  const signature = await payosSignature({
    orderCode: 123,
    amount: 3000,
    description: 'VQRIO123',
    accountNumber: '12345678',
    reference: 'TF230204212323',
    transactionDateTime: '2023-02-04 18:25:00',
    currency: 'VND',
    paymentLinkId: '124c33293c43417ab7879e14c8d9eb18',
    code: '00',
    desc: 'Thành công',
    counterAccountBankId: '',
    counterAccountBankName: '',
    counterAccountName: '',
    counterAccountNumber: '',
    virtualAccountName: '',
    virtualAccountNumber: '',
  }, '1a54716c8f0efb2744fb28b6e38b25da7f67a925d98bc1c18bd8faaecadd7675');
  assert.equal(signature, '412e915d2871504ed31be63c8f62a149a4410d34c4c42affc9006ef9917eaa03');
});
