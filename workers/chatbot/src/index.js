const maxMessageLength = 2000;
const maxHistoryItems = 12;
const maxReplyLength = 4000;
const requestWindowMs = 60 * 1000;
const maxRequestsPerMinute = 10;
const minRequestIntervalMs = 2000;
const firebaseJwksUrl = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const localLimits = new Map();
let signingKeyCache = { expiresAt: 0, values: [] };

const instructions = 'Bạn là Trợ lý HealWay bằng tiếng Việt. Hỗ trợ sử dụng ứng dụng, đặt lịch và thông tin sức khỏe phổ thông. Không chẩn đoán, kê đơn hoặc khẳng định tình trạng bệnh. Khi có triệu chứng khẩn cấp hoặc đe dọa tính mạng, hãy khuyên người dùng liên hệ cơ sở y tế khẩn cấp tại địa phương. Không yêu cầu hoặc tiết lộ mật khẩu, mã xác thực hay dữ liệu hồ sơ nhạy cảm. Trả lời ngắn gọn, rõ ràng và đồng cảm.';

export default {
  async fetch(request, env) {
    const headers = corsHeaders(request, env);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
    if (request.method !== 'POST' || new URL(request.url).pathname !== '/chat') {
      return json({ error: 'Không tìm thấy dịch vụ.' }, 404, headers);
    }
    try {
      const uid = await authenticatedUser(request, env.FIREBASE_PROJECT_ID);
      const input = await validatedInput(request);
      await enforceRateLimit(uid, env);
      const reply = await askOpenAi(input.history, env.OPENAI_API_KEY);
      return json({ reply }, 200, headers);
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      // Never log prompts, Firebase tokens, or the OpenAI key.
      if (!(error instanceof HttpError)) console.error('chatbot worker failed');
      return json({ error: error instanceof HttpError ? error.message : 'Không thể gửi tin nhắn lúc này.' }, status, headers);
    }
  },
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function authenticatedUser(request, projectId) {
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token || !projectId) throw new HttpError(401, 'Bạn cần đăng nhập để dùng trợ lý HealWay.');
  const [headerPart, payloadPart, signaturePart] = token.split('.');
  if (!headerPart || !payloadPart || !signaturePart) throw new HttpError(401, 'Phiên đăng nhập không hợp lệ.');
  let header;
  let claims;
  try {
    header = decodeJson(headerPart);
    claims = decodeJson(payloadPart);
  } catch (_) {
    throw new HttpError(401, 'Phiên đăng nhập không hợp lệ.');
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') {
    throw new HttpError(401, 'Phiên đăng nhập không hợp lệ.');
  }
  const signingKeys = await firebaseSigningKeys();
  const signingKey = signingKeys.find((key) => key.kid === header.kid);
  if (!signingKey) throw new HttpError(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
  const key = await crypto.subtle.importKey(
    'jwk',
    signingKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlBytes(signaturePart),
    new TextEncoder().encode(`${headerPart}.${payloadPart}`),
  );
  const now = Math.floor(Date.now() / 1000);
  if (!valid || claims.aud !== projectId || claims.iss !== `https://securetoken.google.com/${projectId}` ||
      typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 128 ||
      typeof claims.exp !== 'number' || claims.exp <= now ||
      typeof claims.iat !== 'number' || claims.iat > now + 60) {
    throw new HttpError(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
  }
  return claims.sub;
}

async function firebaseSigningKeys() {
  if (signingKeyCache.expiresAt > Date.now()) return signingKeyCache.values;
  const response = await fetch(firebaseJwksUrl);
  if (!response.ok) throw new HttpError(503, 'Không thể xác thực phiên đăng nhập. Vui lòng thử lại.');
  const maxAge = Number(response.headers.get('cache-control')?.match(/max-age=(\d+)/)?.[1] ?? 300);
  const payload = await response.json();
  if (!Array.isArray(payload.keys)) throw new HttpError(503, 'Không thể xác thực phiên đăng nhập. Vui lòng thử lại.');
  signingKeyCache = { values: payload.keys, expiresAt: Date.now() + maxAge * 1000 };
  return signingKeyCache.values;
}

async function validatedInput(request) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    throw new HttpError(400, 'Tin nhắn không hợp lệ.');
  }
  const message = cleanText(body?.message);
  if (!Array.isArray(body?.history) || !body.history.length || body.history.length > maxHistoryItems) {
    throw new HttpError(400, 'Lịch sử trò chuyện không hợp lệ.');
  }
  const history = body.history.map((item) => {
    if (!item || !['user', 'assistant'].includes(item.role)) throw new HttpError(400, 'Lịch sử trò chuyện không hợp lệ.');
    return { role: item.role, text: cleanText(item.text) };
  });
  if (history.at(-1).role !== 'user' || history.at(-1).text !== message) {
    throw new HttpError(400, 'Nội dung trò chuyện không nhất quán.');
  }
  return { history };
}

function cleanText(value) {
  if (typeof value !== 'string') throw new HttpError(400, 'Tin nhắn không hợp lệ.');
  const text = value.trim();
  if (!text || text.length > maxMessageLength) throw new HttpError(400, `Tin nhắn phải có từ 1 đến ${maxMessageLength} ký tự.`);
  return text;
}

async function enforceRateLimit(uid, env) {
  const now = Date.now();
  const key = `chat:${uid}`;
  const state = env.CHAT_RATE_LIMIT
    ? JSON.parse((await env.CHAT_RATE_LIMIT.get(key)) ?? '{}')
    : localLimits.get(key) ?? {};
  if (now - Number(state.lastRequestAt ?? 0) < minRequestIntervalMs) {
    throw new HttpError(429, 'Bạn gửi tin nhắn quá nhanh. Vui lòng chờ một lát rồi thử lại.');
  }
  const inNewWindow = now - Number(state.windowStartedAt ?? now) >= requestWindowMs;
  const count = inNewWindow ? 0 : Number(state.count ?? 0);
  if (count >= maxRequestsPerMinute) throw new HttpError(429, 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau một phút.');
  const next = { windowStartedAt: inNewWindow ? now : Number(state.windowStartedAt ?? now), lastRequestAt: now, count: count + 1 };
  if (env.CHAT_RATE_LIMIT) await env.CHAT_RATE_LIMIT.put(key, JSON.stringify(next), { expirationTtl: 120 });
  else localLimits.set(key, next);
}

async function askOpenAi(history, apiKey) {
  if (!apiKey) throw new HttpError(503, 'Dịch vụ trợ lý chưa được cấu hình.');
  let response;
  try {
    response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        instructions,
        input: history.map((item) => ({ role: item.role, content: item.text })),
        max_output_tokens: 500,
      }),
      signal: AbortSignal.timeout(22000),
    });
  } catch (_) {
    throw new HttpError(504, 'Trợ lý đang phản hồi chậm. Vui lòng thử lại sau ít phút.');
  }
  if (!response.ok) {
    if (response.status === 429) throw new HttpError(429, 'Dịch vụ đang bận. Vui lòng thử lại sau.');
    if (response.status === 401 || response.status === 403) throw new HttpError(503, 'Dịch vụ trợ lý chưa sẵn sàng.');
    throw new HttpError(503, 'Dịch vụ trợ lý tạm thời không khả dụng. Vui lòng thử lại sau.');
  }
  let payload;
  try {
    payload = await response.json();
  } catch (_) {
    throw new HttpError(502, 'Trợ lý trả về dữ liệu không hợp lệ.');
  }
  // `output_text` is available in some SDK helpers, while the raw Responses
  // API commonly returns text inside output[].content[]. Read both forms.
  const reply = responseText(payload).slice(0, maxReplyLength);
  if (!reply) throw new HttpError(502, 'Trợ lý không trả về nội dung hợp lệ.');
  return reply;
}

function responseText(payload) {
  if (typeof payload?.output_text === 'string') return payload.output_text.trim();
  if (!Array.isArray(payload?.output)) return '';
  return payload.output
    .flatMap((item) => Array.isArray(item?.content) ? item.content : [])
    .filter((item) => item?.type === 'output_text' && typeof item.text === 'string')
    .map((item) => item.text.trim())
    .filter(Boolean)
    .join('\n')
    .trim();
}

function corsHeaders(request, env) {
  const headers = new Headers({
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Content-Type': 'application/json; charset=UTF-8',
    'Vary': 'Origin',
  });
  const origin = request.headers.get('Origin');
  if (origin && env.ALLOWED_ORIGIN && origin === env.ALLOWED_ORIGIN) {
    headers.set('Access-Control-Allow-Origin', origin);
  }
  return headers;
}

function json(value, status, headers) {
  return new Response(JSON.stringify(value), { status, headers });
}

function decodeJson(value) {
  return JSON.parse(new TextDecoder().decode(base64UrlBytes(value)));
}

function base64UrlBytes(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(value.length / 4) * 4, '=');
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

