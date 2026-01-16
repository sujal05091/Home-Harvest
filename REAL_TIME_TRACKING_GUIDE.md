# 🚀 Real-Time Order Tracking Implementation Guide

## Overview
This guide covers the complete implementation of Swiggy/Zomato-style real-time GPS tracking for the Home Harvest app, supporting both normal delivery and home-to-office tiffin orders.

---

## 📋 Table of Contents
1. [System Architecture](#system-architecture)
2. [Order Flow](#order-flow)
3. [Implementation Details](#implementation-details)
4. [Usage Guide](#usage-guide)
5. [Testing](#testing)
6. [Security](#security)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ System Architecture

### Components Created
```
lib/
├── models/
│   ├── rider_location_model.dart      ✅ GPS data structure
│   └── order_model.dart                ✅ Updated with new statuses
├── services/
│   └── rider_location_service.dart     ✅ Core GPS tracking service
├── screens/
│   ├── customer/
│   │   ├── finding_partner_screen.dart ✅ Loading screen
│   │   └── live_tracking_screen.dart   ✅ Real-time tracking
│   └── rider/
│       └── rider_delivery_request_screen.dart ✅ Accept/reject
└── firestore.rules                     ✅ Security rules
```

### Technology Stack
- **Maps**: OpenStreetMap via `flutter_map` (FREE)
- **GPS**: `geolocator` package (high accuracy)
- **Real-time DB**: Cloud Firestore with StreamBuilder
- **Update Frequency**: 4 seconds
- **Distance Filter**: 5 meters minimum movement
- **Tiles**: CartoDB Positron (clean professional look)

---

## 🔄 Order Flow

### Status Progression
```
1. PLACED 
   → Customer creates order
   → Redirect to Finding Partner Screen
   → Backend searches for available riders

2. ACCEPTED
   → Cook accepts the order
   → Continues finding rider

3. RIDER_ASSIGNED
   → System assigns nearest rider
   → Rider sees delivery request screen
   → Can accept or reject

4. RIDER_ACCEPTED
   → Rider accepts delivery
   → GPS tracking STARTS (RiderLocationService.startTracking())
   → Customer redirected to Live Tracking Screen
   → Location updates every 4 seconds to Firestore

5. ON_THE_WAY_TO_PICKUP
   → Rider heading to restaurant/home
   → Customer sees "Rider on the way to pickup"

6. PICKED_UP
   → Rider picked up food
   → Customer sees "Food picked up! Coming to you"

7. ON_THE_WAY_TO_DROP
   → Rider heading to customer
   → Customer sees "Rider arriving soon"

8. DELIVERED
   → Order completed
   → GPS tracking STOPS (RiderLocationService.stopTracking())
   → Show delivery confirmation
```

---

## 🛠️ Implementation Details

### 1. RiderLocationModel
**File**: `lib/models/rider_location_model.dart`

```dart
class RiderLocationModel {
  final String riderId;
  final double latitude;
  final double longitude;
  final double? speed;        // km/h
  final double? heading;      // degrees (0-360)
  final String? orderId;      // Current active order
  final DateTime updatedAt;
  final bool isActive;        // Is rider currently delivering
}
```

**Firestore Path**: `rider_locations/{riderId}`

### 2. RiderLocationService
**File**: `lib/services/rider_location_service.dart`

#### Key Methods:

##### startTracking()
```dart
await RiderLocationService().startTracking(
  riderId,
  orderId,
  onLocationUpdate: (location) {
    print('Lat: ${location.latitude}, Lng: ${location.longitude}');
  },
);
```
- Starts GPS stream with high accuracy
- Updates Firestore every 4 seconds
- Only saves if rider moved 5+ meters
- Dual approach: GPS stream + backup timer

##### stopTracking()
```dart
await RiderLocationService().stopTracking(riderId);
```
- Cancels GPS subscriptions
- Marks rider as inactive in Firestore
- Call when order is DELIVERED

##### listenToRiderLocation()
```dart
Stream<RiderLocationModel?> stream = 
  RiderLocationService().listenToRiderLocation(riderId);
```
- Returns real-time stream from Firestore
- Customer app listens to this for live updates
- Auto-updates map markers

##### calculateETA()
```dart
String eta = RiderLocationService().calculateETA(distanceKm);
// Returns: "5 min" or "1h 20min"
```

### 3. Finding Partner Screen
**File**: `lib/screens/customer/finding_partner_screen.dart`

**When to Show**: 
- Order status == `PLACED`, `ACCEPTED`, or `RIDER_ASSIGNED`

**Features**:
- Lottie animation (delivery motorbike)
- Map with pickup + drop markers (NO rider yet)
- Loading indicator with animated progress bar
- Order summary (from, to, items)
- Auto-navigates to Live Tracking when status == `RIDER_ACCEPTED`

**Navigation**:
```dart
Navigator.pushNamed(
  context,
  '/findingPartner',
  arguments: {'orderId': orderId},
);
```

### 4. Rider Delivery Request Screen
**File**: `lib/screens/rider/rider_delivery_request_screen.dart`

**When to Show**: 
- Order status == `RIDER_ASSIGNED`
- Rider receives notification

**Features**:
- Full-screen map with pickup → drop route
- Gradient delivery fee card (₹10/km + ₹20 base)
- Order details: distance, pickup/drop addresses, customer info, items
- Tiffin badge for home-to-office orders
- Accept → Starts GPS tracking, sets status to `RIDER_ACCEPTED`
- Reject → Removes assignment, sets status back to `PLACED`

**Accept Flow**:
```dart
// 1. Update Firestore
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({'status': 'RIDER_ACCEPTED'});

// 2. Start GPS tracking
await RiderLocationService().startTracking(riderId, orderId, ...);

// 3. Navigate to navigation screen
Navigator.pushReplacementNamed(context, '/riderNavigation', ...);
```

### 5. Live Tracking Screen
**File**: `lib/screens/customer/live_tracking_screen.dart`

**When to Show**: 
- Order status >= `RIDER_ACCEPTED` and < `DELIVERED`

**Features**:
- Real-time animated rider marker (blue pulse)
- Pickup marker (green), Drop marker (orange)
- Route polyline: Pickup → Rider → Drop
- Gradient ETA card (auto-calculated)
- Distance display (km)
- Rider info card with call button
- Auto-follow toggle (follows rider movement)
- Status-based messaging
- Tiffin badge for home-to-office orders

**Real-time Updates**:
```dart
// Listen to rider location
_riderLocationSubscription = _locationService
  .listenToRiderLocation(riderId)
  .listen((riderLocation) {
    setState(() {
      _riderLatLng = LatLng(
        riderLocation.latitude,
        riderLocation.longitude,
      );
    });
    _updateMap(); // Refresh markers and route
  });
```

---

## 📖 Usage Guide

### For Backend Developers

#### 1. Assign Rider to Order
```dart
// When backend finds available rider
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({
    'status': 'RIDER_ASSIGNED',
    'assignedRiderId': riderId,
    'assignedRiderName': riderName,
    'assignedRiderPhone': riderPhone,
    'assignedAt': FieldValue.serverTimestamp(),
  });

// Send push notification to rider
await sendNotification(
  riderId, 
  'New Delivery Request',
  'Delivery fee: ₹${fee.toStringAsFixed(0)}',
);
```

#### 2. Rider Assignment Logic (Suggestion)
```dart
// Find nearest available rider
Future<String?> findNearestRider(GeoPoint pickupLocation) async {
  final ridersSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'rider')
    .where('isAvailable', isEqualTo: true)
    .get();
  
  double minDistance = double.infinity;
  String? nearestRiderId;
  
  for (var doc in ridersSnapshot.docs) {
    final riderLocation = doc.data()['currentLocation'] as GeoPoint?;
    if (riderLocation == null) continue;
    
    final distance = RiderLocationService().calculateDistance(
      pickupLocation.latitude,
      pickupLocation.longitude,
      riderLocation.latitude,
      riderLocation.longitude,
    );
    
    if (distance < minDistance) {
      minDistance = distance;
      nearestRiderId = doc.id;
    }
  }
  
  return nearestRiderId;
}
```

### For Customer App

#### After Order Creation
```dart
// Create order in Firestore
final orderId = await createOrder(...);

// Redirect to Finding Partner screen
Navigator.pushNamed(
  context,
  '/findingPartner',
  arguments: {'orderId': orderId},
);
// Screen auto-navigates to live tracking when rider accepts
```

### For Rider App

#### On Receiving Notification
```dart
// Show delivery request screen
Navigator.pushNamed(
  context,
  '/riderDeliveryRequest',
  arguments: {'orderId': orderId},
);
```

#### On Accept
```dart
// Handled automatically by RiderDeliveryRequestScreen
// - Updates status to RIDER_ACCEPTED
// - Starts GPS tracking
// - Navigates to navigation screen
```

#### Update Status During Delivery
```dart
// Arrived at restaurant
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({'status': 'ON_THE_WAY_TO_PICKUP'});

// Picked up food
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({
    'status': 'PICKED_UP',
    'pickedUpAt': FieldValue.serverTimestamp(),
  });

// On the way to customer
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({'status': 'ON_THE_WAY_TO_DROP'});

// Delivered
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({
    'status': 'DELIVERED',
    'deliveredAt': FieldValue.serverTimestamp(),
  });

// IMPORTANT: Stop GPS tracking
await RiderLocationService().stopTracking(riderId);
```

---

## 🧪 Testing

### Test Scenarios

#### 1. Order Creation Flow
```
1. Create order as customer
2. Verify redirect to Finding Partner screen
3. Check Firestore: orders/{orderId}.status == 'PLACED'
4. Check UI: Shows loading animation, pickup/drop markers
```

#### 2. Rider Assignment
```
1. Manually set order.status = 'RIDER_ASSIGNED' in Firestore
2. Verify Finding Partner screen shows "Waiting for acceptance..."
3. Open rider app, navigate to delivery request screen
4. Check UI: Shows map, delivery fee, order details
```

#### 3. GPS Tracking Start
```
1. Rider clicks "Accept & Start"
2. Check Firestore: 
   - orders/{orderId}.status == 'RIDER_ACCEPTED'
   - rider_locations/{riderId} document created
3. Verify customer redirected to Live Tracking screen
4. Check UI: Shows rider marker on map
```

#### 4. Real-time Location Updates
```
1. Move device with rider app (or use Location Simulator)
2. Check Firestore: rider_locations/{riderId}.updatedAt updates every 4 sec
3. Check customer app: Rider marker moves smoothly
4. Verify ETA recalculates automatically
5. Check console: "Rider location updated: lat, lng"
```

#### 5. Status Updates
```
1. Rider updates status to ON_THE_WAY_TO_PICKUP
2. Check customer UI: "Rider heading to restaurant"
3. Update to PICKED_UP
4. Check customer UI: "Food picked up! Coming to you"
5. Update to DELIVERED
6. Check Firestore: rider_locations/{riderId}.isActive == false
7. Verify GPS tracking stopped
```

### Testing Tools

#### Location Simulator (Android Studio)
```
1. Open Android Studio
2. Tools → AVD Manager → Click "..." on running emulator
3. Extended Controls → Location
4. Set custom lat/lng or load GPX route
5. Click "Send" to simulate movement
```

#### Firestore Console
```
1. Go to Firebase Console → Firestore Database
2. Monitor collections: orders, rider_locations
3. Manually update status for testing
4. Check timestamps, location updates
```

---

## 🔒 Security

### Firestore Rules Deployed
**File**: `firestore.rules`

#### Key Rules:

1. **Rider Locations**
   - Read: Anyone authenticated (change to customer-only in production)
   - Write: Only the rider themselves

2. **Orders**
   - Read: Customer, Cook, or assigned Rider only
   - Update: 
     - Customer can cancel
     - Cook can accept
     - Rider can update delivery status

3. **Production Rule** (commented out, enable when ready):
```javascript
// Only assigned customer can read rider location
allow read: if isAuthenticated() && 
  exists(/databases/$(database)/documents/orders/$(orderId)) &&
  get(/databases/$(database)/documents/orders/$(orderId)).data.assignedRiderId == riderId &&
  get(/databases/$(database)/documents/orders/$(orderId)).data.customerId == request.auth.uid;
```

### Deploy Rules
```bash
firebase deploy --only firestore:rules
```

---

## 🛠️ Troubleshooting

### Issue: Rider location not updating

**Possible Causes**:
1. GPS permission not granted
2. Location services disabled
3. Poor GPS signal (indoors)
4. Firestore rules blocking writes

**Solutions**:
```dart
// Check permissions
final permission = await Geolocator.checkPermission();
print('Location permission: $permission');

// Request if denied
if (permission == LocationPermission.denied) {
  await Geolocator.requestPermission();
}

// Check if location service is enabled
final isEnabled = await Geolocator.isLocationServiceEnabled();
print('Location service enabled: $isEnabled');

// Check Firestore console for write errors
```

### Issue: Customer not seeing rider marker

**Possible Causes**:
1. Rider hasn't accepted order yet
2. Firestore stream not initialized
3. assignedRiderId is null

**Solutions**:
```dart
// Check order status
print('Order status: ${order.status}');
print('Assigned rider: ${order.assignedRiderId}');

// Check stream subscription
print('Subscription active: ${_riderLocationSubscription != null}');

// Check Firestore data
final doc = await FirebaseFirestore.instance
  .collection('rider_locations')
  .doc(riderId)
  .get();
print('Rider location doc exists: ${doc.exists}');
print('Data: ${doc.data()}');
```

### Issue: ETA showing "Calculating..."

**Possible Causes**:
1. Rider location not available yet
2. Distance calculation failed
3. Speed is 0 or null

**Solutions**:
```dart
// Check rider location
print('Rider LatLng: $_riderLatLng');
print('Drop LatLng: $_dropLatLng');

// Check distance calculation
final distance = _locationService.calculateDistance(...);
print('Distance: $distance km');

// Check ETA calculation
final eta = _locationService.calculateETA(distance);
print('ETA: $eta');
```

### Issue: App crashes on status update

**Possible Causes**:
1. Missing enum value in switch statement
2. Null safety issue
3. Missing field in OrderModel

**Solutions**:
```dart
// Make switch statements exhaustive
switch (order.status) {
  case OrderStatus.PLACED:
  case OrderStatus.ACCEPTED:
  case OrderStatus.RIDER_ASSIGNED:
  case OrderStatus.RIDER_ACCEPTED:
  case OrderStatus.ON_THE_WAY_TO_PICKUP:
  case OrderStatus.PICKED_UP:
  case OrderStatus.ON_THE_WAY_TO_DROP:
  case OrderStatus.DELIVERED:
  case OrderStatus.CANCELLED:
    // Handle each case
    break;
}

// Check for nulls
print('Assigned rider name: ${order.assignedRiderName ?? "NULL"}');
```

---

## 🎯 Next Steps

### Already Implemented ✅
- ✅ Updated OrderStatus enum with all tracking states
- ✅ Created RiderLocationModel and RiderLocationService
- ✅ Built Finding Partner screen with auto-navigation
- ✅ Built Rider Delivery Request screen with accept/reject
- ✅ Built Live Tracking screen with real-time updates
- ✅ Added routes to app_router.dart
- ✅ Created Firestore security rules

### TODO (Remaining)
- ⏳ Integrate GPS tracking into existing Rider Navigation screen
- ⏳ Add status update buttons for rider (ON_THE_WAY_TO_PICKUP, PICKED_UP, etc.)
- ⏳ Implement home-to-office tiffin mode fully (address selection)
- ⏳ Add smooth marker animations (AnimationController for marker movement)
- ⏳ Implement auto-camera following with smooth transitions
- ⏳ Add call functionality (url_launcher for phone calls)
- ⏳ Create backend rider assignment logic
- ⏳ Add push notifications for rider assignments
- ⏳ Deploy Firestore rules to production
- ⏳ Test on physical devices with real GPS movement

### Backend Integration Required
```dart
// TODO: Create Cloud Function or backend API
// 1. Listen to new orders (status == PLACED)
// 2. Find nearest available rider using Geohash or similar
// 3. Update order with assignedRiderId
// 4. Send push notification to rider
// 5. Set timeout (2 min) for rider to accept
// 6. If timeout, reassign to next nearest rider
```

---

## 📞 Support

For issues or questions:
1. Check Firestore Console for data
2. Check device logs for error messages
3. Test with Location Simulator first
4. Verify Firestore rules are deployed
5. Ensure all permissions are granted

---

**Last Updated**: 2024
**Version**: 1.0.0
**Status**: Core Implementation Complete ✅
