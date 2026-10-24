# HealWay chatbot Worker

This Worker verifies Firebase ID token signatures/expiry/audience/issuer and
checks the current `TAI_KHOAN` document through Firestore REST using that user's
token. Only active patient/doctor/admin accounts can proceed. The OpenAI key
stays in Cloudflare; it is never included in Flutter or Firestore.

## Deploy without Firebase Blaze

1. Install and authenticate the Cloudflare CLI:

   ```powershell
   npm.cmd ci
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

The `CHAT_LIMITER` SQLite Durable Object is required; the checked-in Wrangler
binding and migration create it on deployment. A transaction per UID enforces
a two-second cooldown and ten requests/minute across concurrent requests and
Worker instances. There is no unlimited/per-instance/KV fallback. Missing or
unavailable quota storage fails closed (503). OpenAI times out after 22 seconds;
messages/replies are bounded to 2000 characters, context to 12 turns, and the
request stream to 110000 bytes. Only configured web origins receive CORS access.

Flutter stores successful, bounded transcripts in `LS_CHAT_AI`; Rules restrict
users to their own records, prohibit modification/deletion and validate schema
and server timestamps. Admin may read for support. Account changes clear the
in-memory conversation and discard old pending replies. Both client and Worker
check sensitive content in the complete history before transmission; this is a
heuristic filter, not a guarantee that all possible personal data is detected.
Failed/private submissions are not saved. Do not enter private medical records.
Deploy the rules using the Firebase Console or your normal rules deployment
workflow. Admin mutations additionally require the `adminCommand` Function.

`store: false` disables Responses application-state storage. It does not promise
zero retention by the API provider: see the official
[OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).

## Scope and medical safety

The Worker immediately declines clear non-health requests such as programming,
finance, politics, entertainment and sports without calling OpenAI. The model
instructions additionally restrict it to HealWay use, appointment support and
general health education. It must not diagnose, prescribe or provide dosing;
urgent symptoms receive an emergency-care recommendation instead.

Common application-navigation questions have verified local answers, without a
model call. Requests for actual prices/availability are directed to the app;
no patient record or hospital database is sent to OpenAI. Other general-health
answers use the model and require separate live quality evaluation.

## Reproduce QA

```powershell
npm.cmd test
npm.cmd run test:runtime
npx.cmd wrangler deploy --dry-run
node ../../scripts/run-sprint6-question-qa.mjs
```

The runtime smoke test uses real workerd + SQLite objects with synthetic JWTs
and local Firebase/OpenAI responses. It makes no production/model calls.
Full cases, actual results, limitations and handoff steps are in
`../../docs/qa/sprint6/report.md`.
