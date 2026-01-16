# HomeHarvest - Home-Cooked Meal Delivery App

A complete Flutter mobile application for ordering home-cooked meals with role-based authentication (Customer, Home Cook, Delivery Partner). Built with Firebase, Google Maps, and real-time order tracking.

## Features

- **Role-Based Authentication**: Separate login flows for Customers, Cooks, and Riders
- **Cook Verification System**: Document upload and admin approval for home cooks
- **Real-Time Order Tracking**: Live location updates using Google Maps
- **Home-to-Office Tiffin Mode**: Dedicated mode for scheduled meal delivery
- **Geo-Based Search**: Find nearby home cooks using Geoflutterfire
- **Push Notifications**: Firebase Cloud Messaging for order updates
- **Swiggy/Zomato Style UI**: Modern orange theme with smooth animations

## Tech Stack

- **Flutter SDK**: 3.10.3+
- **State Management**: Provider (ChangeNotifier)
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Messaging)
- **Maps**: Google Maps Flutter + Directions API
- **Geolocation**: Geolocator, Geocoding, Geoflutterfire Plus
- **Animations**: Lottie
- **Image Handling**: Image Picker, Cached Network Image

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme.dart                # App theme and colors
├── app_router.dart           # Named routes
├── models/                   # Data models
│   ├── user_model.dart
│   ├── dish_model.dart
│   ├── order_model.dart
│   ├── delivery_model.dart
│   └── verification_model.dart
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   ├── notification_service.dart
│   ├── location_service.dart
│   └── maps_service.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── dishes_provider.dart
│   ├── orders_provider.dart
│   └── rider_provider.dart
├── screens/                  # UI screens
│   ├── splash.dart
│   ├── role_select.dart
│   ├── auth/
│   │   ├── login.dart
│   │   └── signup.dart
│   ├── customer/
│   │   ├── home.dart
│   │   ├── dish_detail.dart
│   │   ├── cart.dart
│   │   └── order_tracking.dart
│   ├── cook/
│   │   ├── dashboard.dart
│   │   ├── add_dish.dart
│   │   └── verification_status.dart
│   ├── rider/
│   │   └── home.dart
│   └── common/
│       └── profile.dart
└── widgets/                  # Reusable components
    ├── dish_card.dart
    ├── cook_card.dart
    ├── map_widget.dart
    └── lottie_loader.dart
```

## Setup Instructions

### 1. Firebase Setup

#### a) Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project" and follow the setup wizard
3. Enable Google Analytics (optional)

#### b) Add Android App
1. In Firebase Console, click "Add App" > Android
2. Register app with package name: `com.example.home_harvest_app`
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`

#### c) Add iOS App
1. In Firebase Console, click "Add App" > iOS
2. Register app with bundle ID: `com.example.homeHarvestApp`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`

#### d) Enable Firebase Services
1. **Authentication**: Enable Email/Password sign-in method
2. **Firestore Database**: Create database in production mode
3. **Cloud Messaging**: Enable FCM (no extra config needed)

**Note**: We use **Cloudinary** for image storage (FREE, no credit card) instead of Firebase Storage. See `CLOUDINARY_SETUP.md` for setup.

### 2. Firestore Security Rules

Replace Firestore rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Dishes collection - only verified cooks can add
    match /dishes/{dishId} {
      allow read: if true;
      allow create: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'cook' &&
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.verified == true;
      allow update, delete: if request.auth.uid == resource.data.cookId;
    }
    
    // Orders collection
    match /orders/{orderId} {
      allow read: if request.auth.uid == resource.data.customerId || 
                     request.auth.uid == resource.data.cookId ||
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'rider';
      allow create: if request.auth.uid == request.resource.data.customerId;
      allow update: if request.auth.uid == resource.data.cookId ||
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'rider';
    }
    
    // Deliveries collection
    match /deliveries/{deliveryId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'rider';
    }
    
    // Cook verifications - admin only write
    match /cook_verifications/{verificationId} {
      allow read: if request.auth.uid == resource.data.cookId;
      allow create: if request.auth.uid == request.resource.data.cookId;
      // Admin updates only (implement custom claims)
    }
  }
}
```

### 3. Cloudinary Setup (Image Storage)

We use **Cloudinary** instead of Firebase Storage because it's **100% FREE** (no credit card needed).

**Quick Setup** (5 minutes):
1. Sign up at https://cloudinary.com/users/register_free
2. Get your `cloud_name` from Dashboard
3. Create upload preset: **Settings** → **Upload** → **Add preset** → Name: `home_harvest_preset`, Mode: **Unsigned**
4. Update `lib/services/storage_service.dart`:
   ```dart
   static const String CLOUDINARY_CLOUD_NAME = 'your_cloud_name_here';
   static const String CLOUDINARY_UPLOAD_PRESET = 'home_harvest_preset';
   ```

**Full instructions**: See `CLOUDINARY_SETUP.md`

### 4. Google Maps Setup

#### Get API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Directions API
   - Geocoding API
4. Create API key
5. **IMPORTANT: Restrict your API key** (click on API key):
   - **Application restrictions**: 
     - Android: Set to "Android apps" → Add package name `com.example.home_harvest_app` and SHA-1 certificate fingerprint
     - iOS: Set to "iOS apps" → Add bundle ID `com.example.homeHarvestApp`
   - **API restrictions**: Select "Restrict key" → Choose:
     - Maps SDK for Android
     - Maps SDK for iOS
     - Directions API
     - Geocoding API
   - Click **Save**

**Get SHA-1 fingerprint** (for Android restriction):
```bash
# Debug certificate
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release certificate (before production)
keytool -list -v -keystore your-release-key.keystore -alias your-key-alias
```

#### Add to Android
Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
    </application>
</manifest>
```

#### Add to iOS
Edit `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 5. Lottie Animations

Create `assets/lottie/` directory and download animations:

1. **loading.json** - [Download from LottieFiles](https://lottiefiles.com/animations/loading)
2. **success.json** - Success animation
3. **cooking.json** - Cooking animation
4. **delivery.json** - Delivery animation

Update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/lottie/
```

### 6. Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to find nearby cooks</string>
<key>NSCameraUsageDescription</key>
<string>We need camera access to upload dish photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to upload images</string>
```

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd home_harvest_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase** (follow Setup Instructions above)

4. **Run the app**
   ```bash
   flutter run
   ```

## Usage

### Customer Flow
1. Sign up with role "customer"
2. Browse available home-cooked dishes
3. Add items to cart
4. Place order with pickup/delivery address
5. Track order in real-time

### Cook Flow
1. Sign up with role "cook"
2. Submit verification documents (kitchen photos, ID)
3. Wait for admin approval
4. Once verified, add dishes with photos and prices
5. Accept/reject incoming orders

### Rider Flow
1. Sign up with role "rider"
2. Toggle availability status
3. View assigned deliveries
4. Accept delivery and navigate to pickup location
5. Update delivery status (Picked Up → On the Way → Delivered)

## Environment Variables

Create `.env` file (optional):
```
GOOGLE_MAPS_API_KEY=your_api_key_here
```

## Testing

### Test Users (Create in Firebase Console)
- **Customer**: customer@test.com / password123
- **Cook**: cook@test.com / password123 (set verified: true)
- **Rider**: rider@test.com / password123

### Seed Data
Import `seed_data.json` using Firebase CLI or manually add via console.

## Troubleshooting

### Issue: Firebase not initializing
**Solution**: Ensure `google-services.json` and `GoogleService-Info.plist` are in correct locations

### Issue: Google Maps blank screen
**Solution**: 
1. Check API key is correct
2. Verify Maps SDK is enabled in Google Cloud Console
3. Enable billing on Google Cloud project

### Issue: Location permissions denied
**Solution**: Add location permission descriptions in `Info.plist` (iOS) and `AndroidManifest.xml`

### Issue: Push notifications not working
**Solution**: 
1. Ensure FCM is enabled in Firebase Console
2. Check notification permissions are granted
3. Test with Firebase Console "Cloud Messaging" test message

## Production Checklist

- [ ] Update Firebase Security Rules for production
- [ ] **Restrict Google Maps API key** to app package name and SHA-1 fingerprint
- [ ] Add API restrictions to limit which APIs can be called
- [ ] Set up billing alerts in Google Cloud Console
- [ ] Enable ProGuard for Android release build
- [ ] Add app icons (`flutter pub run flutter_launcher_icons`)
- [ ] Update app name and package identifier
- [ ] Test on physical devices (not just emulator)
- [ ] Implement Razorpay/payment gateway integration
- [ ] Add analytics and crash reporting
- [ ] Set up CI/CD pipeline
- [ ] Submit to app stores

## License

MIT License

## Support

For issues or questions, please open an issue on GitHub or contact support@homeharvest.com

---

**Built with ❤️ using Flutter & Firebase**
#   H o m e - H a r v e s t  
 