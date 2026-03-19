# Bobatier

A Flutter/Android app to explore, rank, and share boba shops with friends.

**Platform:** Android only
**Stack:** Flutter · Riverpod · GoRouter · Firebase · Google Maps / Places API

---

## Project Structure

```
app/                      # Flutter Android application
  lib/                    # Dart source (features/, core/, shared/)
  android/                # Android platform code & Gradle config
  pubspec.yaml            # Dart dependencies
functions/                # Firebase Cloud Functions (TypeScript)
  src/index.ts            # All function handlers
firestore.rules           # Firestore security rules
firestore.indexes.json    # Firestore composite indexes
storage.rules             # Firebase Storage security rules
firebase.json             # Firebase project config
.github/workflows/        # CI/CD (GitHub Actions)
```

---

## ⚠️ Files NOT in This Repo (Must Be Created After Cloning)

The following files are **gitignored** because they contain secrets or project-specific config. Create them before building.

### 1. `app/android/app/google-services.json`

Firebase config for the Android app.

**Source:** [Firebase Console](https://console.firebase.google.com) → Project Settings → Android app → Download `google-services.json`

```
Place at: app/android/app/google-services.json
```

---

### 2. `app/android/key.properties`

Android release signing credentials. A template is at `app/android/key.properties.example`.

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=../upload-keystore.jks
```

---

### 3. `app/android/upload-keystore.jks`

Release signing keystore for APK/AAB.

```
Place at: app/android/upload-keystore.jks
```

> ⚠️ If publishing on Google Play, use the **original** keystore. A new one cannot update the same listing.

---

### 4. `app/config.json`

Contains compile-time keys passed to the app via `--dart-define-from-file`:

```json
{
  "MAPS_API_KEY": "<your-google-maps-android-api-key>",
  "MAPS_MAP_ID": "<your-google-maps-map-id>"
}
```

**Source:** [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials (Maps SDK for Android key) and Maps Platform → Map Management (Map ID).

---

### 5. `.firebaserc`

Firebase project alias binding. Create at project root:

```json
{
  "projects": {
    "default": "<your-firebase-project-id>"
  }
}
```

---

### 6. `PLACES_API_KEY` — Cloud Functions Secret

The Google Places API key used by Cloud Functions. Stored as a **Firebase Secret** (never in any file).

```bash
firebase functions:secrets:set PLACES_API_KEY
```

---

## Building & Running

### Prerequisites
- Flutter SDK (>= 3.2.0)
- Android SDK / Android Studio
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js 20+

### Run Locally
```bash
cd app
flutter pub get
flutter run --dart-define-from-file=config.json
```

### Release Build
```bash
cd app
flutter build appbundle --release --dart-define-from-file=config.json
```

Output: `app/build/app/outputs/bundle/release/app-release.aab`

### Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### Deploy Rules & Indexes
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```
