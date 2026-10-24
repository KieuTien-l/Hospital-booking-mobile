// Exercise the real workerd + SQLite Durable Object runtime, with all outbound
// Firebase/OpenAI requests replaced by local synthetic responses.
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';

const keys = await webcrypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
const jwk = { ...await webcrypto.subtle.exportKey('jwk', keys.publicKey), kid: 'runtime-test' };
const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const unsigned = `${b64({ alg: 'RS256', kid: jwk.kid })}.${b64({ sub: 'runtime-patient', aud: 'demo-healway-qa', iss: 'https://securetoken.google.com/demo-healway-qa', iat: now, exp: now + 600 })}`;
const token = `${unsigned}.${Buffer.from(await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5', keys.privateKey, new TextEncoder().encode(unsigned))).toString('base64url')}`;
let providerCalls = 0;
const mf = new Miniflare(convertV4MiniflareOptions({
  name: 'healway-chatbot',
  modules: true, scriptPath: fileURLToPath(new URL('../src/index.js', import.meta.url)), compatibilityDate: '2025-10-24',
  bindings: { FIREBASE_PROJECT_ID: 'demo-healway-qa', OPENAI_API_KEY: 'synthetic-test-key' },
  durableObjects: { CHAT_LIMITER: { className: 'ChatRateLimiter', useSQLite: true } },
  outboundService(request) {
    if (request.url.includes('service_accounts')) return Response.json({ keys: [jwk] });
    if (request.url.includes('firestore.googleapis.com')) return Response.json({ fields: { role: { stringValue: 'patient' }, isActive: { booleanValue: true } } });
    if (request.url.includes('api.openai.com')) { providerCalls++; return Response.json({ output_text: 'Bạn nên trao đổi với bác sĩ nếu triệu chứng kéo dài.' }); }
    throw new Error('Unexpected outbound request');
  },
}));
try {
  const message = 'Tôi đau họng ba ngày, nên khám chuyên khoa nào?';
  const responses = await Promise.all(Array.from({ length: 12 }, () => mf.dispatchFetch('https://worker.example/chat', {
    method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, history: [{ role: 'user', text: message }] }),
  })));
  const actual = responses.map((r) => r.status);
  assert.equal(actual.filter((s) => s === 200).length, 1, JSON.stringify(actual));
  assert.equal(actual.filter((s) => s === 429).length, 11, JSON.stringify(actual));
  assert.equal(providerCalls, 1);
  console.log('PASS workerd/SQLite: 12 concurrent requests, 1 accepted, 11 rate-limited, 1 synthetic provider call.');
} finally { await mf.dispose(); }
