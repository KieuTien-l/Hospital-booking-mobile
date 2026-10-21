# Firestore migration

## Reset and create the coherent DEMO_V2 dataset

`reset-and-seed-demo-v2.mjs` preserves the sole administrator account, removes
all other root Firestore collections and Firebase Authentication users, then
creates the consistent demonstration data set: 12 specialties, 60 doctors,
60 patients, accounts, schedules, time slots, past completed appointments and
future appointments through 2026-10-25. It is destructive when `--apply` is
present; run the dry run first.

```powershell
$env:FIREBASE_SERVICE_ACCOUNT_PATH = 'C:\secure\bookinghospitalapp-admin.json'
$env:DEMO_ACCOUNT_PASSWORD = 'Password123@'
npm run demo-v2:dry-run --prefix scripts
npm run demo-v2:apply --prefix scripts
```

If an interrupted reset leaves the dataset incomplete, restore the full seed
without deleting any additional data:

```powershell
npm run demo-v2:repair --prefix scripts
```

If a calendar date needs to be moved by one day without recreating any records,
run the date-only migration after its dry run:

```powershell
npm run demo-v2:shift-dates:dry-run --prefix scripts
npm run demo-v2:shift-dates:apply --prefix scripts
```

Doctor login emails follow `bs00001@hospital.test`; patient login emails follow
`bn00001@hospital.test`. All seed records are marked `source: DEMO_V2`.

This tool replaces Vietnamese Firestore field names with the canonical English
schema. It first adds the English fields without changing document IDs or
overwriting an existing canonical field; cleanup then removes the Vietnamese
fields only after their English replacement is populated.

## Before running

1. Export or back up Firestore from Google Cloud Console.
2. In Firebase Console, open **Project settings** > **Service accounts** and
   create a private key for project `bookinghospitalapp`.
3. Store that JSON file outside this repository. Never commit or share it.

## Run a dry run

```powershell
npm install --prefix scripts
$env:FIREBASE_SERVICE_ACCOUNT_PATH = 'C:\secure\bookinghospitalapp-admin.json'
npm run migrate:dry-run --prefix scripts
```

The dry run prints only per-collection counts. It does not print patient data
and does not write to Firestore.

## Apply the migration

After reviewing the dry-run counts:

```powershell
npm run migrate:apply --prefix scripts
```

Then verify the ten migrated collections in Firestore Console. Only after
that verification should the stricter Firestore Rules be deployed.

## Remove mapped legacy fields

After the application is verified against the English schema, cleanup can
delete a legacy Vietnamese field only when its canonical replacement is
already populated. It never touches unmapped fields or the legacy collection
whose name begins with a space.

```powershell
npm run cleanup:dry-run --prefix scripts
npm run cleanup:apply --prefix scripts
```

## Repair Auth users missing Firestore profiles

Some patient Firebase Auth users may not have matching `TAI_KHOAN` and
`BENH_NHAN` documents. This tool creates a missing account and profile using
the Auth UID only when an Auth user has no account; when an account already
exists, it processes only `role: patient` and skips doctor/admin accounts. For
a single existing profile, it fills only empty identity fields from Firebase
Auth; populated data is never overwritten and duplicate profiles are reported
without modification.

```powershell
npm run repair-auth:dry-run --prefix scripts
npm run repair-auth:apply --prefix scripts
```

## Create booking sample data

This tool gives each active doctor a work schedule on the next Vietnam date,
with eight 30-minute slots from 08:00 to 12:00 and capacity five. Existing
documents are preserved. Use `--date=YYYY-MM-DD` to seed a specific date.

```powershell
npm run seed-booking:dry-run --prefix scripts
npm run seed-booking:apply --prefix scripts
```

To seed a single doctor only, pass that Firestore doctor document ID:

```powershell
npm run seed-booking:apply --prefix scripts -- --date=2026-10-20 --doctor-id=DOCTOR_DOCUMENT_ID
```

## Add the Cardiology booking sample

This adds three clearly labelled sample doctors (including Phạm Ngọc Mai),
their work schedules, and twelve available slots. It uses the existing
Cardiology specialty document and defaults to `2027-09-16` in Vietnam time.
It only upserts document IDs beginning with `sample_`.

```powershell
npm run seed-cardiology:dry-run --prefix scripts -- --date=2027-09-16
npm run seed-cardiology:apply --prefix scripts -- --date=2027-09-16
```

## Seed booking data for multiple specialties

This seeds every active non-sample doctor belonging to an active specialty.
For each selected day it creates an active work schedule and eight available
30-minute slots from 08:00 to 12:00. Existing schedules and slots are never
overwritten.

```powershell
npm run seed-multispecialty:dry-run --prefix scripts -- --start-date=2026-10-20 --days=7
npm run seed-multispecialty:apply --prefix scripts -- --start-date=2026-10-20 --days=7
```

## Audit booking data

This is read-only. It checks document relationships and capacity/status
consistency, patient-account/profile integrity, payment ownership and payment
states, then reports the number of doctors with available slots in every active
specialty for each selected date.

```powershell
npm run audit-booking --prefix scripts -- --start-date=2026-10-20 --days=7
```

For CI or acceptance testing, add `--strict`. The audit remains read-only and
returns exit code 2 if any finding is detected:

```powershell
npm run audit-backend:strict --prefix scripts -- --start-date=2026-10-20 --days=7
```

## Repair Patient data

`repair-auth-profiles` now covers both failure modes: a Firebase Auth user
without `TAI_KHOAN`, and an existing patient account without a matching
`BENH_NHAN.authUserId`. Existing doctor and admin accounts are explicitly
skipped. It also fills only empty patient identity fields (`fullName`, `email`,
`phone`, `isActive`, `status`) from Firebase Auth; it does not overwrite
populated profile data or alter duplicate profiles. Review the duplicate count
from the dry run manually before applying.

## Add Health Record samples

This resolves the patient profile from its account email, then writes an
idempotent set of sample documents in `HO_SO_SUC_KHOE`. It never creates a patient or
doctor profile. The records cover outpatient, inpatient and checkup tabs, are
labelled `TEST_HEALTH_RECORD`, and can be run again without duplicating records.

```powershell
npm run seed-health-record:dry-run --prefix scripts -- --email=patient@example.com
npm run seed-health-record:apply --prefix scripts -- --email=patient@example.com
```
