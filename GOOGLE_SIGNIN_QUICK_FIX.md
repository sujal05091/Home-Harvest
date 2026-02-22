# Quick Fix for Google Sign-In Error

## The Problem
**Error Code:** `ApiException: 10` - Developer Error
**Cause:** SHA-1 fingerprint not added to Firebase Console

---

## The Solution (5 Minutes)

### 1️⃣ Get SHA-1 Fingerprint

Open terminal in your project folder and run:

```bash
cd android
gradlew signingReport
```

**Look for this output:**
```
SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD
```

**Copy the entire SHA-1 string** (with colons)

---

### 2️⃣ Add to Firebase Console

1. Open: https://console.firebase.google.com/
2. Select your project
3. ⚙️ **Settings** → **Project Settings**
4. Scroll to **Your apps**
5. Click your Android app
6. Click **"Add fingerprint"**
7. Paste the SHA-1
8. Click **Save**

---

### 3️⃣ Enable Google Sign-In

1. Go to **Authentication** → **Sign-in method**
2. Enable **Google** provider
3. Add support email
4. Save

---

### 4️⃣ Download Updated Config

1. In Firebase, download **google-services.json**
2. Replace file at: `android/app/google-services.json`

---

### 5️⃣ Restart App

```bash
flutter clean
flutter pub get
flutter run
```

---

## ✅ Done!

Try Google Sign-In again - it should work now!

---

## Alternative: Use Email Login

While you fix this, users can still login with:
- ✅ Email & Password (already working)
- ⏳ Google Sign-In (will work after setup)

Google Sign-In is **optional** but enhances UX! 🎉
