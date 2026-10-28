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

Then build the Flutter app with:

```powershell
flutter build apk --release --dart-define=ADMIN_COMMAND_BASE_URL=https://healway-admin-command.<account>.workers.dev/adminCommand
```

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
- `createDoctor` (Firebase Auth account plus `TAI_KHOAN` and `BAC_SI`)
- `passwordSetup` (server-side account/email validation before the app sends
  the Firebase password-reset email)
- `create`, `save`, `delete` for the permitted admin catalog records
- `setAvailability` for doctors, specialties, patients, schedules and slots
- `editSchedule` for schedules that have no booking/history
- `backfillSlotTimes` in resumable batches of at most 200 slots

All other operations deliberately return `501` instead of writing partial or
unvalidated data. Do not point a production Admin app at this Worker until the
remaining UI operations have been migrated and tested with real Admin, Doctor,
and Patient accounts.
