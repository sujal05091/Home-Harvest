# Google Sign-In Setup Guide

## Error: ApiException: 10

If you're seeing `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10)`, it means Google Sign-In is not configured properly in Firebase.

---

## Solution: Add SHA-1 Fingerprint to Firebase

### Step 1: Get SHA-1 Fingerprint

**On Windows (PowerShell):**
```powershell
cd android
./gradlew signingReport
```

**On Mac/Linux:**
```bash
cd android
./gradlew signingReport
```

Look for output like:
```
Variant: debug
Config: debug
Store: C:\Users\YourName\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:...
SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD
SHA-256: ...
```

**Copy the SHA-1 fingerprint** (the long string with colons)

---

### Step 2: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **home-harvest-app**
3. Click the **Settings gear icon** → **Project Settings**
4. Scroll down to **Your apps** section
5. Select your Android app: `com.example.home_harvest_app`
6. Click **Add fingerprint**
7. Paste your **SHA-1** fingerprint
8. Click **Save**

---

### Step 3: Download Updated google-services.json

1. After adding SHA-1, click **Download google-services.json**
2. Replace the old file in your project:
   ```
   android/app/google-services.json
   ```
3. **Important:** Restart your app completely (stop and re-run)

---

### Step 4: Enable Google Sign-In in Firebase

1. In Firebase Console, go to **Authentication**
2. Click **Sign-in method** tab
3. Find **Google** in the providers list
4. Click **Enable**
5. Set project support email
6. Click **Save**

---

### Step 5: Verify Setup

Run the app again:
```bash
flutter clean
flutter pub get
flutter run
```

Try Google Sign-In - it should work now! ✅

---

## Still Having Issues?

### Check Package Name
Make sure your package name matches in:
- `android/app/build.gradle.kts` → `applicationId`
- Firebase Console → Android app registration
- Should be: `com.example.home_harvest_app`

### Debug Keystore Location
If gradle can't find keystore, check:
- Windows: `C:\Users\YourName\.android\debug.keystore`
- Mac/Linux: `~/.android/debug.keystore`

### Release Build
For production release, you'll need **SHA-1 for release keystore** as well!

---

## Alternative: Use Email/Password Sign-In

If Google Sign-In is too complex to set up now, users can use:
- ✅ **Email/Password login** (already working)
- ✅ **Phone OTP** (can be implemented)

Google Sign-In is optional but enhances user experience! 🚀
