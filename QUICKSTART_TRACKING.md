# 🚀 QUICK START - Test Real-Time Tracking NOW

## ⚡ 5-Minute Setup for Testing

### Step 1: Update Dependencies (30 seconds)

Open `pubspec.yaml` and ensure these dependencies exist:
```yaml
dependencies:
  firebase_messaging: ^14.7.9
  flutter_local_notifications: ^16.3.0
  http: ^1.1.0
```

Run:
```bash
flutter pub get
```

---

### Step 2: Initialize FCM in main.dart (1 minute)

Open `lib/main.dart` and add:

```dart
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize FCM service
  await FCMService().initialize();
  await FCMService().saveFCMToken();
  
  runApp(const MyApp());
}
```

---

### Step 3: Enable FCM Notifications in cart.dart (30 seconds)

Open `lib/screens/customer/cart.dart` around line 327.

**Find this commented code**:
```dart
// TODO: Enable FCM notifications
```

**Uncomment the FCM block**:
```dart
try {
  await FCMService().notifyNearbyRiders(
    orderId: orderId,
    pickupLat: _firstDish!.location.latitude,
    pickupLng: _firstDish!.location.longitude,
    radiusKm: 5.0,
  );
} catch (e) {
  print('⚠️ FCM notification failed: $e');
}
```

Also add import at top:
```dart
import '../../services/fcm_service.dart';
```

---

### Step 4: Setup Test Rider in Firestore (2 minutes)

1. Go to **Firebase Console** → **Firestore**
2. Open `users` collection
3. Find or create a Rider user document
4. Update these fields:

```javascript
{
  userId: "rider_uid_here",
  name: "Test Rider",
  role: "rider",
  isAvailable: true,  // ← IMPORTANT
  fcmToken: "will_be_set_automatically",
  location: GeoPoint(12.9716, 77.5946),  // Near your test location
  phone: "+1234567890",
  email: "rider@test.com"
}
```

**Key Field**: `isAvailable: true` (Rider must be available to receive notifications)

---

### Step 5: Run and Test (1 minute)

**Terminal 1 - Customer App**:
```bash
flutter run
```

**Terminal 2 - Rider App** (on different device/emulator):
```bash
flutter run
```

---

## 🧪 TESTING THE FLOW

### Test 1: Order Placement & Notification

**Customer App**:
1. Login as customer
2. Add items to cart
3. Select delivery address
4. Click "Place Order" (₹XX)
5. ✅ **Expected**: Redirected to "Finding Delivery Partner" screen
6. ✅ **Expected**: Lottie animation playing

**Rider App**:
7. Login as rider (with `isAvailable: true` in Firestore)
8. Keep app open or in background
9. ✅ **Expected**: Notification appears: "🚀 New Delivery Request"

---

### Test 2: Accept Delivery

**Rider App**:
1. Tap the notification
2. ✅ **Expected**: Beautiful dialog opens with order details
3. Review: Pickup location, Drop location, Items, Payment
4. Click "✅ Accept Delivery"
5. ✅ **Expected**:
   - Dialog closes
   - Navigate to `/riderNavigation` screen
   - GPS tracking starts (check console logs: "📍 GPS Update")

**Check Firestore**:
- `orders/{orderId}` → `status: "RIDER_ACCEPTED"`
- `rider_locations/{riderId}` → Updates every 3-5 seconds

---

### Test 3: Customer Auto-Redirect

**Customer App** (still on "Finding Partner" screen):
1. ✅ **Expected**: Automatically redirected to "Live Tracking" screen
2. ✅ **Expected**: Map shows:
   - 📍 Green marker (Pickup)
   - 📍 Red marker (Drop)
   - 🛵 Blue marker (Rider - moving in real-time!)
3. ✅ **Expected**: Status timeline shows "Rider Accepted"

---

### Test 4: Reject Delivery

Repeat Test 1-2, but at step 4:
1. Click "❌ Reject" instead
2. ✅ **Expected**:
   - Dialog closes
   - Order status → `PLACED`
   - Customer still on "Finding Partner" screen
   - Notification sent to other available riders

---

### Test 5: 2-Minute Timeout

1. Place order without any available riders (`isAvailable: false` for all riders)
2. Wait on "Finding Partner" screen
3. After 2 minutes:
4. ✅ **Expected**: Orange message appears:
   ```
   ⚠️ Still finding partner...
   High demand right now. We're trying our best!
   ```

---

## 🐛 TROUBLESHOOTING

### Issue: Rider doesn't receive notification

**Solution 1**: Check Firestore
- Open `users/{rider_uid}`
- Verify: `isAvailable: true`
- Verify: `fcmToken` exists (should be set automatically)

**Solution 2**: Check FCM Token
```dart
// Add to rider home screen initState():
final token = await FCMService().getToken();
print('🔑 Rider FCM Token: $token');
```

**Solution 3**: Test with manual notification
Firebase Console → Cloud Messaging → Send test message to rider's token

---

### Issue: Customer doesn't auto-redirect to tracking

**Solution**: Check order status in Firestore
- Should change from `PLACED` → `RIDER_ASSIGNED` → `RIDER_ACCEPTED`
- `FindingPartnerScreen` listens to status changes and auto-redirects on `RIDER_ACCEPTED`

---

### Issue: GPS not updating

**Solution 1**: Check Permissions
- Ensure location permissions granted on rider device
- Check `AndroidManifest.xml` has location permissions

**Solution 2**: Check RiderLocationService
```dart
// In rider navigation screen, check console logs:
// Should see: "📍 GPS Update: lat, lng" every 3-5 seconds
```

**Solution 3**: Check Firestore
- Open `rider_locations/{rider_uid}`
- Should update every 3-5 seconds
- If not updating, restart GPS tracking:
```dart
await RiderLocationService().stopTracking(riderId);
await RiderLocationService().startTracking(riderId, orderId, ...);
```

---

### Issue: Notification tap doesn't open dialog

**Solution**: Add notification handler in rider home screen

```dart
@override
void initState() {
  super.initState();
  
  // Check for pending notification
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final fcmData = FCMService().getPendingNavigation();
    if (fcmData != null && fcmData['route'] == '/riderDeliveryRequest') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RiderDeliveryRequestDialog(
          orderId: fcmData['orderId'],
        ),
      );
    }
  });
}
```

---

## 📱 MANUAL TESTING (Without FCM)

If FCM is not working, test manually:

### 1. Place Order (Customer)
- Order creates with `status: PLACED`

### 2. Simulate Rider Assignment (Firebase Console)
- Go to Firestore → `orders/{orderId}`
- Update:
```javascript
{
  status: "RIDER_ASSIGNED",
  riderId: "actual_rider_uid_here"
}
```

### 3. Rider Opens App
- Rider home screen shows "View Request" button
- Tap → Opens delivery request screen
- Accept → Status changes to `RIDER_ACCEPTED`
- GPS tracking starts

### 4. Customer Auto-Redirect
- Customer app detects `RIDER_ACCEPTED` status
- Auto-redirects to live tracking
- Map shows real-time rider location

---

## 🎯 SUCCESS CRITERIA

Your implementation is working correctly if:

✅ Customer places order → Sees "Finding Partner" screen  
✅ Rider receives push notification  
✅ Notification tap → Opens beautiful dialog  
✅ Rider accepts → GPS tracking starts  
✅ Customer auto-redirects to live tracking  
✅ Map shows moving rider marker (updates every 3-5 seconds)  
✅ Rider can update status throughout delivery  
✅ Order completes successfully  

---

## 🚀 NEXT STEPS

Once basic testing works:

1. **Deploy Cloud Functions** (Production)
   - See `SWIGGY_TRACKING_IMPLEMENTATION.md`
   - Moves notification logic to backend
   - More reliable and secure

2. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Add Optional Features**
   - ETA calculation
   - Rider ratings
   - Live chat
   - Order history

4. **Production Optimizations**
   - Geohash for faster distance calculations
   - Battery optimization for GPS
   - Notification queue system
   - Analytics tracking

---

## 📚 DOCUMENTATION FILES

- **SWIGGY_TRACKING_IMPLEMENTATION.md** - Complete implementation guide
- **REALTIME_TRACKING_FIXED.md** - Previous tracking system fixes
- **INTEGRATION_FIXES.md** - Integration issues resolved
- **TESTING_GUIDE.md** - Detailed testing workflows

---

## 🎉 You're Ready!

Run `flutter run` in two terminals (customer + rider) and start testing!

For detailed documentation, see **SWIGGY_TRACKING_IMPLEMENTATION.md**.

Good luck! 🚀
