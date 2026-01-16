# 📱 FCM Setup Guide - Android & iOS Configuration

## 🚀 **CURRENT STATUS**
✅ **CODE IS READY** - All Flutter code is implemented and working  
⚠️ **SETUP REQUIRED** - Platform configuration needed to receive notifications

---

## 📋 **Prerequisites**

1. Firebase Project created at [Firebase Console](https://console.firebase.google.com/)
2. `google-services.json` (Android) already added to `android/app/`
3. `GoogleService-Info.plist` (iOS) - need to add to `ios/Runner/`

---

## 🤖 **ANDROID CONFIGURATION**

### 1. Update `android/app/build.gradle`

Add this inside `android` block:

```gradle
android {
    // ... existing config ...
    
    defaultConfig {
        // ... existing config ...
        minSdkVersion 21  // FCM requires minimum SDK 21
    }
}
```

### 2. Update `android/build.gradle`

Add Google services plugin:

```gradle
buildscript {
    dependencies {
        // ... existing dependencies ...
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

### 3. Update `android/app/build.gradle` (bottom)

Add at the **very bottom** of the file:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 4. Create Notification Channel

File already exists: `android/app/src/main/kotlin/com/example/home_harvest_app/MainActivity.kt`

Add this code:

```kotlin
package com.example.home_harvest_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create notification channel for delivery requests
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "delivery_requests",
                "Delivery Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new delivery requests"
                enableVibration(true)
                setShowBadge(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
```

### 5. Update `AndroidManifest.xml`

Add these permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- FCM Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    
    <application
        android:label="HomeHarvest"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- ... existing activity ... -->
        
        <!-- FCM Service -->
        <service
            android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
    </application>
</manifest>
```

---

## 🍎 **iOS CONFIGURATION**

### 1. Add `GoogleService-Info.plist`

1. Download from [Firebase Console](https://console.firebase.google.com/)
2. Drag into `ios/Runner/` folder in Xcode
3. Make sure "Copy items if needed" is checked
4. Select `Runner` target

### 2. Enable Push Notifications Capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select project → Target "Runner"
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" → Check "Remote notifications"

### 3. Update `AppDelegate.swift`

File: `ios/Runner/AppDelegate.swift`

```swift
import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase initialization
    FirebaseApp.configure()
    
    // FCM configuration
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle FCM token refresh
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }
}
```

### 4. Update `Podfile`

Add to `ios/Podfile`:

```ruby
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Firebase pods
  pod 'Firebase/Messaging'
end
```

Then run:
```bash
cd ios
pod install
cd ..
```

---

## 🔥 **FIREBASE CLOUD FUNCTIONS SETUP**

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 2. Initialize Functions

```bash
firebase init functions
```

Select:
- Use existing project (select your HomeHarvest project)
- Language: JavaScript
- Install dependencies: Yes

### 3. Deploy Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

**Functions will be deployed:**
- `notifyNearbyRiders` - Sends notifications to riders
- `retryRiderNotification` - Retry logic after 30 seconds
- `onRiderAcceptance` - Confirms to customer when rider accepts

---

## 🧪 **TESTING THE SYSTEM**

### Test 1: Foreground Notification

1. Open rider app
2. Keep it in foreground
3. Place order from customer app
4. **Expected:** 
   - Banner notification shows at top
   - Can tap to open delivery request dialog

### Test 2: Background Notification

1. Open rider app
2. Press home button (app in background)
3. Place order from customer app
4. **Expected:**
   - System notification appears
   - Tap opens app → shows delivery request dialog

### Test 3: Terminated State

1. Force close rider app (swipe from recent apps)
2. Place order from customer app
3. **Expected:**
   - System notification appears
   - Tap opens app → shows delivery request dialog

### Test 4: Accept Flow

1. Rider receives notification
2. Tap notification
3. Delivery request dialog opens
4. Tap "Accept"
5. **Expected:**
   - Order status → RIDER_ACCEPTED
   - Customer sees "Rider found!" message
   - Customer redirects to live tracking screen
   - Rider sees navigation screen

---

## 🐛 **TROUBLESHOOTING**

### No notifications received?

**Check:**
1. Firebase project is correct
2. `google-services.json` is in `android/app/`
3. Cloud Functions are deployed
4. Rider's `isOnline` is `true` in Firestore
5. Rider has `fcmToken` saved in Firestore

**Debug:**
```bash
# Check FCM token
flutter run
# In app, print FCMService token
```

### Android notifications not showing?

1. Check notification channel is created (see MainActivity.kt above)
2. Check app has notification permission
3. Battery optimization → Allow background activity

### iOS notifications not showing?

1. Check Push Notifications capability is enabled
2. Check `GoogleService-Info.plist` is added
3. Run on real device (simulator doesn't support push)

---

## ✅ **VERIFICATION CHECKLIST**

- [ ] `google-services.json` added to `android/app/`
- [ ] `GoogleService-Info.plist` added to `ios/Runner/`
- [ ] Android: Notification channel created in `MainActivity.kt`
- [ ] Android: Permissions added to `AndroidManifest.xml`
- [ ] iOS: Push Notifications capability enabled
- [ ] iOS: Background Modes enabled
- [ ] Cloud Functions deployed: `firebase deploy --only functions`
- [ ] Test: Foreground notification works
- [ ] Test: Background notification works
- [ ] Test: Terminated state notification works
- [ ] Test: Accept flow works end-to-end

---

## 🎉 **YOU'RE DONE!**

Once all checkboxes are complete:
1. Customer places order
2. Rider gets INSTANT popup notification
3. Rider accepts
4. Customer sees live tracking
5. Swiggy/Zomato-style real-time delivery! 🚀

---

## 📞 **NEED HELP?**

Check logs:
```bash
# Flutter logs
flutter run --verbose

# Cloud Functions logs
firebase functions:log

# Firestore data
# Check in Firebase Console → Firestore Database
```
