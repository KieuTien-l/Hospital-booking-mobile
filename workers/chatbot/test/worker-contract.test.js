import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import test, { after, beforeEach } from 'node:test';

import worker from '../src/index.js';

const originalFetch = globalThis.fetch;
const encoder = new TextEncoder();
const keyPair = await webcrypto.subtle.generateKey(
  { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
  true,
  ['sign', 'verify'],
);
const signingJwk = await webcrypto.subtle.exportKey('jwk', keyPair.publicKey);
signingJwk.kid = 'contract-test-key';
const calls = [];
let accountState = 'active';

beforeEach(() => {
  calls.length = 0;
  accountState = 'active';
  globalThis.fetch = async (url, options) => {
    const address = String(url);
    calls.push({ address, options });
    if (address.includes('googleapis.com/service_accounts')) {
      return new Response(JSON.stringify({ keys: [signingJwk] }), {
        headers: { 'cache-control': 'max-age=300', 'content-type': 'application/json' },
      });
    }
    if (address.includes('firestore.googleapis.com/v1/projects/')) {
      if (accountState === 'inactive') {
        return new Response(JSON.stringify({
          fields: {
            isActive: { booleanValue: false },
            role: { stringValue: 'patient' },
            status: { stringValue: 'REJECTED' },
          },
        }), { headers: { 'content-type': 'application/json' } });
      }
      return new Response(JSON.stringify({
        fields: {
          isActive: { booleanValue: true },
          role: { stringValue: 'patient' },
          status: { stringValue: 'APPROVED' },
        },
      }), { headers: { 'content-type': 'application/json' } });
    }
    if (address === 'https://api.openai.com/v1/responses') {
      return new Response(JSON.stringify({
        output: [{ content: [{ type: 'output_text', text: 'Bạn có thể vào mục Đặt khám để chọn chuyên khoa.' }] }],
      }), { headers: { 'content-type': 'application/json' } });
    }
    throw new Error(`Unexpected fetch: ${address}`);
  };
});

after(() => {
  globalThis.fetch = originalFetch;
});

test('accepts a valid chatbot request and returns the response contract', async () => {
  const response = await worker.fetch(await chatRequest({
    uid: 'contract-user-success',
    message: 'Hướng dẫn tôi đặt lịch khám',
  }), env());

  assert.equal(response.status, 200);
  assert.match((await response.json()).reply, /chọn Đặt khám/i);
  const openAiCall = calls.find((call) => call.address === 'https://api.openai.com/v1/responses');
  assert.equal(openAiCall, undefined);
});

test('returns a safe local reply for out-of-scope requests without calling AI', async () => {
  const response = await worker.fetch(await chatRequest({
    uid: 'contract-user-scope',
    message: 'Beat It là bài j?',
  }), env());

  assert.equal(response.status, 200);
  assert.match((await response.json()).reply, /chỉ hỗ trợ sử dụng HealWay/i);
  assert.equal(calls.some((call) => call.address === 'https://api.openai.com/v1/responses'), false);
});

test('rejects sensitive input so clients do not persist it as chat history', async () => {
  const response = await worker.fetch(await chatRequest({
    uid: 'contract-user-sensitive',
    message: 'Mã OTP của tôi là 123456',
  }), env());

  assert.equal(response.status, 422);
  const body = await response.json();
  assert.match(body.error, /không nên gửi mật khẩu, mã OTP/i);
  assert.equal(calls.some((call) => call.address === 'https://api.openai.com/v1/responses'), false);
});

test('rejects malformed requests with an error contract', async () => {
  const response = await worker.fetch(new Request('https://worker.example/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${await tokenFor('contract-user-invalid')}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: 'Tôi bị sốt' }),
  }), env());

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'Lịch sử trò chuyện không hợp lệ.' });
});

test('rejects an otherwise valid token after its HealWay account is disabled', async () => {
  accountState = 'inactive';
  const response = await worker.fetch(await chatRequest({
    uid: 'contract-user-disabled',
    message: 'Hướng dẫn tôi đặt lịch khám',
  }), env());

  assert.equal(response.status, 403);
  assert.match((await response.json()).error, /chưa được phê duyệt|ngừng hoạt động/i);
  assert.equal(calls.some((call) => call.address === 'https://api.openai.com/v1/responses'), false);
});

function env() {
  return { FIREBASE_PROJECT_ID: 'bookinghospitalapp', OPENAI_API_KEY: 'test-key' };
}

async function chatRequest({ uid, message }) {
  return new Request('https://worker.example/chat', {
    method: 'POST',
    headers: { Authorization: `Bearer ${await tokenFor(uid)}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, history: [{ role: 'user', text: message }] }),
  });
}

async function tokenFor(uid) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url({ alg: 'RS256', kid: signingJwk.kid });
  const payload = base64Url({
    aud: 'bookinghospitalapp',
    iss: 'https://securetoken.google.com/bookinghospitalapp',
    sub: uid,
    iat: now,
    exp: now + 600,
  });
  const signature = await webcrypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    keyPair.privateKey,
    encoder.encode(`${header}.${payload}`),
  );
  return `${header}.${payload}.${Buffer.from(signature).toString('base64url')}`;
}

function base64Url(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}
