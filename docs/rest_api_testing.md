# REST API testing

## API in scope

The application reads the signed-in user's profile with this Firestore REST
endpoint:

```text
GET https://firestore.googleapis.com/v1/projects/bookinghospitalapp/databases/(default)/documents/TAI_KHOAN/{uid}
Authorization: Bearer <Firebase ID token>
Accept: application/json
```

The login flow is:

```text
Login UI -> AuthRepository -> Firebase Auth -> REST GET profile
-> Firestore JSON -> UserModel -> AuthProvider -> home screen
```

`AuthFirestoreRestDatasource` uses a 10-second timeout and converts HTTP,
network, timeout, and malformed-response failures into `ApiException`.
`AuthFirebaseDatasource` converts that error into `AuthException`, which the
existing provider displays in the login UI.

## Automated tests

Install packages, then run the full test suite from the project root:

```powershell
flutter pub get
flutter test
```

The REST test file is
`test/features/auth/data/datasources/auth_firestore_rest_datasource_test.dart`.
It verifies:

- The request is `GET` and uses the expected Firestore URL and bearer token.
- A `200` JSON response becomes a `UserModel`.
- A `404` response is an HTTP error with its status code preserved.
- Malformed JSON is an invalid-response error.
- A client exception is a network error.
- A request exceeding the configured timeout is a timeout error.

Run static analysis before submitting:

```powershell
dart analyze
```

## Manual test with the app

1. Start an Android emulator or connect a phone, then run `flutter run`.
2. Register a new account in the app. Registration creates both its
   `TAI_KHOAN/{uid}` account and `BENH_NHAN/{uid}` patient profile.
3. Sign in using that account.
4. A successful `200` REST response is deserialized into `UserModel`; the app
   navigates to the home screen for the stored role.
5. Turn off Wi-Fi and mobile data, return to the login screen, and sign in
   again. The login screen remains usable and shows a connection error instead
   of crashing.

## Manual endpoint check with Postman

1. Send a `POST` request to
   `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=<web-api-key>`.
   Use the value of `DefaultFirebaseOptions.web.apiKey` in
   `lib/firebase_options.dart` for `<web-api-key>`.
2. Set the JSON body to:

```json
{
  "email": "your-test-account@example.com",
  "password": "your-password",
  "returnSecureToken": true
}
```

3. Copy `localId` and `idToken` from the successful response.
4. Send the Firestore `GET` request from the API section, replace `{uid}` with
   `localId`, and set `Authorization` to `Bearer <idToken>`.
5. A `200` response containing `fields.email`, `fields.role`, and related
   Firestore values proves the live endpoint is available. Save Postman
   screenshots together with `flutter test` output as acceptance evidence.
