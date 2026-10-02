# Firestore migration

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

Some Firebase Auth users may not have matching `TAI_KHOAN` and `BENH_NHAN`
documents. This tool creates only the missing documents, using the Auth UID as
the document ID and the `patient` role. Existing documents are never changed.

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
