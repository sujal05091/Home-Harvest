# HomeHarvest - Quick Start Guide

## 🚀 Get Running in 10 Minutes

### Prerequisites
- Flutter SDK 3.10.3 or higher
- Android Studio / Xcode
- Firebase account (free tier works)
- Google Cloud account (for Maps API)

---

## Step 1: Clone & Install Dependencies (2 min)

```bash
cd home_harvest_app
flutter pub get
```

---

## Step 2: Firebase Setup (5 min)

### A. Create Firebase Project
1. Go to https://console.firebase.google.com/
2. Click **"Add Project"** → Enter name → Create

### B. Add Android App
1. Click **Android icon** → Register app
2. Package name: `com.example.home_harvest_app`
3. Download `google-services.json`
4. Move to: `android/app/google-services.json`

### C. Add iOS App (Mac only)
1. Click **iOS icon** → Register app
2. Bundle ID: `com.example.homeHarvestApp`
3. Download `GoogleService-Info.plist`
4. Move to: `ios/Runner/GoogleService-Info.plist`

### D. Enable Services (in Firebase Console)
- **Authentication** → Email/Password → Enable
- **Firestore Database** → Create database → Production mode
- **Storage** → Get Started → Default rules

---

## Step 3: Google Maps API (2 min)

### Get API Key
1. Go to https://console.cloud.google.com/
2. APIs & Services → Credentials → Create API Key
3. Restrict to: Maps SDK for Android, Maps SDK for iOS, Directions API

### Add to Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY_HERE"/>
</application>
```

### Add to iOS (Mac)
Edit `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

---

## Step 4: Run the App (1 min)

```bash
flutter run
```

**That's it!** 🎉

---

## Test User Flows

### 1. Customer Flow
- Sign up → Select "Customer" role
- Browse dishes → Add to cart → Place order
- Track order status in real-time

### 2. Cook Flow
- Sign up → Select "Home Cook" role
- Submit verification (skip for testing - manually set `verified: true` in Firestore)
- Add dishes with photos and prices
- Accept incoming orders

### 3. Rider Flow
- Sign up → Select "Delivery Partner" role
- Toggle availability → Accept deliveries
- Update delivery status

---

## Manual Firestore Setup (Optional for Quick Testing)

### 1. Create Test Cook (Verified)
```
Collection: users
Document ID: <any-uid>
Fields:
  - uid: "test_cook_001"
  - email: "cook@test.com"
  - name: "Test Cook"
  - phone: "+919999999999"
  - role: "cook"
  - verified: true
  - location: GeoPoint(28.7041, 77.1025)
  - address: "New Delhi"
```

### 2. Add Test Dish
```
Collection: dishes
Document ID: <auto-generate>
Fields:
  - cookId: "test_cook_001"
  - title: "Paneer Butter Masala"
  - description: "Delicious homemade curry"
  - price: 180
  - availableSlots: 10
  - imageUrl: "https://via.placeholder.com/300"
  - location: GeoPoint(28.7041, 77.1025)
```

---

## Troubleshooting

### Firebase not connecting?
```bash
# Check google-services.json location
ls android/app/google-services.json

# Rebuild app
flutter clean
flutter pub get
flutter run
```

### Google Maps blank screen?
1. Check API key in AndroidManifest.xml
2. Enable billing in Google Cloud Console
3. Wait 5 minutes for API key activation

### Build errors?
```bash
# Clear build cache
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

---

## Next Steps

1. **Firestore Rules**: Copy from `README.md` → Deploy in Firebase Console
2. **Storage Rules**: Copy from `README.md` → Deploy
3. **Seed Data**: Import `seed_data.json` for test data
4. **Lottie Animations**: Download from LottieFiles and add to `assets/lottie/`
5. **Testing**: Create test accounts for all roles

---

## Production Deployment

### Android
```bash
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### iOS (Mac only)
```bash
flutter build ios --release
# Open in Xcode: ios/Runner.xcworkspace
```

---

## Need Help?

- 📖 Full setup guide: `README.md`
- 🗂️ Database schema: `firestore_structure.json`
- 🌱 Test data: `seed_data.json`
- 🐛 Issues: Check Troubleshooting section in README

---

**Built with Flutter & Firebase** 🔥
