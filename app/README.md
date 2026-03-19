# Bobatier

A Flutter app to explore, rank, and share boba shops with friends.

## Stack

- **Frontend:** Flutter/Dart · Riverpod · GoRouter · Google Maps
- **Backend:** Firebase (Auth, Firestore, Storage, Crashlytics, Cloud Messaging, App Check)
- **Cloud Functions:** TypeScript (`functions/src/index.ts`)

---

## Setup: Required Files After Cloning

The following files are **not** tracked in git. You must create them manually before building.

---

### 1. `app/android/app/google-services.json`

Download from the [Firebase Console](https://console.firebase.google.com) → your project → Project Settings → Android app.

Place it at:
```
app/android/app/google-services.json
```

---

### 2. `app/android/key.properties`

Contains the Android release signing credentials. Create it at:
```
app/android/key.properties
```

Use the template at `app/android/key.properties.example` and fill in your values:
```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=../upload-keystore.jks
```

---

### 3. `app/android/upload-keystore.jks`

The release signing keystore file. Place it at:
```
app/android/upload-keystore.jks
```

To generate a new keystore (first-time only):
```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

> **Note:** If publishing to Google Play, use the keystore registered with the Play Console. Do **not** regenerate — you cannot re-upload under a different key.

---

### 4. `MAPS_MAP_ID` (Google Maps Map ID)

This is injected at **compile time** via `--dart-define`. It is not stored in a file. Pass it on every build:

```bash
flutter build apk --release \
  --dart-define=MAPS_MAP_ID=<your-map-id>

# or for local development:
flutter run --dart-define=MAPS_MAP_ID=<your-map-id>
```

Get the Map ID from [Google Cloud Console](https://console.cloud.google.com) → Maps Platform → Map Management.

---

### 5. `PLACES_API_KEY` (Cloud Functions Secret)

The Google Places API key is stored as a **Firebase Secret**, not in any file. Set it via the Firebase CLI:

```bash
firebase functions:secrets:set PLACES_API_KEY
# (prompts for value)
```

This only needs to be set once per Firebase project. After setting, secrets are injected automatically at runtime by Cloud Functions.

---

## Building for Release

```bash
cd app
flutter build apk --release --dart-define=MAPS_MAP_ID=<your-map-id>
# or for Android App Bundle (Play Store):
flutter build appbundle --release --dart-define=MAPS_MAP_ID=<your-map-id>
```

## Running Locally

```bash
cd app
flutter run --dart-define=MAPS_MAP_ID=<your-map-id>
```

## Deploying Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```
