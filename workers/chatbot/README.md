# HealWay chatbot Worker

This Worker accepts a Firebase ID token from the signed-in Flutter app, verifies
it against Firebase's public signing keys, calls the OpenAI Responses
API, and returns only the reply. The OpenAI key stays in Cloudflare; it is never
included in Flutter or Firestore.

## Deploy without Firebase Blaze

1. Install and authenticate the Cloudflare CLI:

   ```powershell
   npm.cmd install
   npx.cmd wrangler login
   ```

2. From `workers/chatbot`, store the new OpenAI key as a Worker secret. Do not
   put it in `wrangler.toml`.

   ```powershell
   npx.cmd wrangler secret put OPENAI_API_KEY
   npx.cmd wrangler deploy
   ```

3. Copy the deployed `https://...workers.dev` address. Build/run Flutter with:

   ```powershell
   flutter run --dart-define=CHATBOT_WORKER_URL=https://your-worker.workers.dev
   ```

The Worker requires a Firebase user ID token, applies a two-second cooldown and
10-request-per-minute limit, and times out OpenAI after 22 seconds. For a
distributed rate limit across Worker instances, add a KV binding named
`CHAT_RATE_LIMIT`; without it, a per-instance fallback still protects normal
client use. To add the binding, run `wrangler kv namespace create
CHAT_RATE_LIMIT`, then add the returned namespace ID to a `[[kv_namespaces]]`
entry in `wrangler.toml`.

Chat history is stored by Flutter in `LS_CHAT_AI`; Firebase Rules limit each
user to their own records. Deploy the rules using the Firebase Console or your
normal rules deployment workflow (this does not require Cloud Functions).

## Scope and medical safety

The Worker immediately declines clear non-health requests such as programming,
finance, politics, entertainment and sports without calling OpenAI. The model
instructions additionally restrict it to HealWay use, appointment support and
general health education. It must not diagnose, prescribe or provide dosing;
urgent symptoms receive an emergency-care recommendation instead.
