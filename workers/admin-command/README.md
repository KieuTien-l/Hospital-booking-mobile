# HealWay Admin Command Worker

This Worker is the trusted boundary for administrator writes. Flutter sends an
Admin's Firebase ID token and one business command; the Worker independently
checks the token, `TAI_KHOAN.role`, and `TAI_KHOAN.isActive` before it can use
its service account to access Firestore.

## Configure the secret

From this directory, with an authenticated Cloudflare Wrangler session:

```powershell
Get-Content -Raw 'C:\Users\viet0\Downloads\bookinghospitalapp-firebase-adminsdk-fbsvc-92d43ae38b.json' |
  npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
```

The command sends the JSON directly to Cloudflare's encrypted secret store. Do
not copy it into a source file, `.env`, terminal transcript, or Git.

Deploy only after the command set needed by the UI is implemented and tested:

```powershell
npx wrangler deploy
```

## PayOS payment setup

PayOS is optional until the following three encrypted Worker secrets are set.
They must never be placed in Flutter, `wrangler.toml`, or Git:

```powershell
npx wrangler secret put PAYOS_CLIENT_ID
npx wrangler secret put PAYOS_API_KEY
npx wrangler secret put PAYOS_CHECKSUM_KEY
```

After deployment, register this Worker endpoint as the PayOS webhook URL:

```text
https://healway-admin-command.<account>.workers.dev/payments/payos-webhook
```

The Worker creates `THANH_TOAN` with `CREATING`/`PENDING`, creates a PayOS QR
link, and accepts `PAID` only after verifying the webhook HMAC using the
Checksum Key. Returning to the app from a PayOS browser page never marks a
payment as successful by itself. PayOS cancellation only cancels an unpaid
link; it does not perform a money refund.

Optional return/cancel pages default to the deployed Worker. Override them
only with public HTTPS URLs (no query string) if a hosted Flutter-web return
screen is available:

```powershell
npx wrangler secret put PAYOS_RETURN_URL
npx wrangler secret put PAYOS_CANCEL_URL
```

Then build the Flutter app with:

```powershell
flutter build apk --release --dart-define=ADMIN_COMMAND_BASE_URL=https://healway-admin-command.<account>.workers.dev/adminCommand
```

`ADMIN_COMMAND_BASE_URL` also enables the patient PayOS UI. Alternatively,
build with `--dart-define=PAYMENT_WORKER_BASE_URL=https://...workers.dev`.

The Worker is intentionally default-deny. It never falls back to a client-side
Firestore write when a command is unsupported or misconfigured.

## Command status

The currently deployed transaction layer supports the appointment and slot
commands below:

- `book`
- `appointmentStatus` (`CONFIRMED`, `CANCELLED`, `NO_SHOW`)
- `reschedule`
- `createSchedule`
- `saveSlot`
- `setAvailability` for `CA_KHAM`
- `accountAccess`
- `internalNote`
- `feedback`
- `notificationDraft` and `sendNotification`
- `paymentReview`
- `saveSettings`
- `createDoctor` (Firebase Auth account plus `TAI_KHOAN` and `BAC_SI`; initial
  password: `Password123@`)
- `passwordSetup` (server-side account/email validation before the app sends
  the Firebase password-reset email)
- `create`, `save`, `delete` for the permitted admin catalog records
- `setAvailability` for doctors, specialties, patients, schedules and slots
- `editSchedule` for schedules that have no booking/history
- `backfillSlotTimes` in resumable batches of at most 200 slots

Doctor-scoped endpoints also support:

- `POST /doctor/appointments/{appointmentId}/complete` — only the assigned,
  active doctor can transition an already-started `CONFIRMED` appointment to
  `COMPLETED`. It stores `completedAt`, writes `NHAT_KY_Y_TE`, and notifies
  the patient. Terminal appointments cannot be reopened by this endpoint.
- `GET /doctor/patients/{patientId}/history` — only after the Worker verifies
  the logged-in doctor has a confirmed/completed visit with that patient. It
  returns that doctor's own earlier visits and clinical records; it is not an
  unrestricted patient-search endpoint.
- `GET/POST /doctor/health-records` and `GET/POST /doctor/test-results` —
  the Worker verifies the doctor's appointment relationship, assigns the
  server timestamp and writes an audit entry.

Patient reservation commands are sent to `/adminCommand` with the patient's
Firebase ID token:

- `patientBook`, `patientCancel`, `patientReschedule` — update the appointment,
  slot count, `reservationCounts`, status and notification inside one trusted
  transaction. Release builds reject these actions when
  `ADMIN_COMMAND_BASE_URL` is absent; they never silently fall back to direct
  Firestore writes.

## Rules, indexes and local verification

Deploy both Rules and indexes after changing the source. The feedback history
feed requires the `PHAN_HOI(patientId, createdAt)` index in this repository.

```powershell
firebase.cmd deploy --only firestore:rules,firestore:indexes --project bookinghospitalapp
```

For emulator verification, run this from the repository root (the command
starts and stops the Firestore emulator itself):

```powershell
npm run test:firestore-rules
```

The rules test covers locked accounts, canonical patient profiles, scoped
doctor data, and rejecting a cancellation after a slot's `startsAt` time.

All other operations deliberately return `501` instead of writing partial or
unvalidated data. Do not point a production Admin app at this Worker until the
remaining UI operations have been migrated and tested with real Admin, Doctor,
and Patient accounts.
