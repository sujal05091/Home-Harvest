# 🚀 QUICK START - Real-Time GPS Tracking

## ⚡ 3-Minute Integration Guide

### Step 1: Update Order Creation (Customer App)
```dart
// In CartScreen or CheckoutScreen, after order creation:
final orderId = await createOrder(...);

// OLD: Navigate to order history
// Navigator.pushNamed(context, '/orderHistory');

// NEW: Navigate to finding partner screen
Navigator.pushReplacementNamed(
  context,
  '/findingPartner',
  arguments: {'orderId': orderId},
);
```

### Step 2: Backend Rider Assignment
```dart
// Listen to new orders and assign riders
FirebaseFirestore.instance
  .collection('orders')
  .where('status', isEqualTo: 'PLACED')
  .snapshots()
  .listen((snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final orderId = change.doc.id;
        
        // Find nearest available rider (implement your logic)
        final riderId = await findNearestRider(...);
        
        // Assign rider
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
        
        // Send push notification
        await sendNotification(riderId, 'New Delivery', orderId);
      }
    }
  });
```

### Step 3: Rider App - Show Delivery Requests
```dart
// In RiderHomeScreen:
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('orders')
    .where('assignedRiderId', isEqualTo: currentRiderId)
    .where('status', isEqualTo: 'RIDER_ASSIGNED')
    .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
      final orderId = snapshot.data!.docs.first.id;
      
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/riderDeliveryRequest',
            arguments: {'orderId': orderId},
          );
        },
        icon: Icon(Icons.delivery_dining),
        label: Text('New Delivery Request'),
        backgroundColor: Colors.orange,
      );
    }
    return SizedBox.shrink();
  },
)
```

### Step 4: Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

---

## 🎯 That's It!

Everything else is handled automatically:
- ✅ Rider accepts → GPS tracking starts
- ✅ Customer auto-navigates to live tracking
- ✅ Location updates every 4 seconds
- ✅ ETA and distance auto-calculated
- ✅ Map updates in real-time
- ✅ Status updates reflected instantly

---

## 🧪 Quick Test

### Test Without Backend
```dart
// 1. Create order normally
// 2. Manually update in Firestore Console:
orders/{orderId}
  status: "RIDER_ASSIGNED"
  assignedRiderId: "test_rider_123"
  assignedRiderName: "Test Rider"
  assignedRiderPhone: "+91 98765 43210"

// 3. In rider app, navigate manually:
Navigator.pushNamed(
  context,
  '/riderDeliveryRequest',
  arguments: {'orderId': 'YOUR_ORDER_ID'},
);

// 4. Click "Accept & Start"
// 5. Check customer app - should show live tracking!
```

### Simulate GPS Movement (Android Studio)
```
1. Run rider app on emulator
2. Tools → AVD Manager → Extended Controls
3. Location tab → Set custom lat/lng
4. Click "Send" multiple times with changing coordinates
5. Watch customer app update in real-time!
```

---

## 📋 Integration Checklist

### Must Do
- [x] Add `/findingPartner` navigation after order creation
- [ ] Implement backend rider assignment logic
- [ ] Deploy Firestore rules
- [ ] Test on physical device with GPS

### Optional (Already Works!)
- [x] GPS tracking auto-starts on accept
- [x] Customer auto-navigates to live tracking
- [x] Real-time location updates
- [x] ETA calculation
- [x] Home-to-office tiffin support

---

## 🎨 Customization

### Change Update Frequency
```dart
// In rider_location_service.dart, line 15:
static const int UPDATE_INTERVAL_SECONDS = 4; // Change to 3 or 5
```

### Change Distance Filter
```dart
// In rider_location_service.dart, line 18:
static const int MIN_DISTANCE_METERS = 5; // Change to 10 or 3
```

### Change ETA Average Speed
```dart
// In rider_location_service.dart, line 105:
double avgSpeedKmh = 25; // Change to 20 or 30
```

---

## 📚 Documentation

- **REAL_TIME_TRACKING_GUIDE.md** - Complete implementation details
- **ROUTE_USAGE.md** - Navigation patterns and examples
- **TRACKING_SUMMARY.md** - Feature overview and checklist
- **FLOW_DIAGRAM.md** - Visual flow diagrams

---

## 🆘 Common Issues

### Issue: Rider location not updating
```dart
// Check permissions
final permission = await Geolocator.checkPermission();
print('Permission: $permission');

// Request if needed
if (permission == LocationPermission.denied) {
  await Geolocator.requestPermission();
}
```

### Issue: Customer not seeing rider marker
```dart
// Check Firestore
final doc = await FirebaseFirestore.instance
  .collection('rider_locations')
  .doc(riderId)
  .get();
print('Rider location exists: ${doc.exists}');
print('Data: ${doc.data()}');
```

### Issue: ETA showing "Calculating..."
```dart
// Check rider location is available
print('Rider LatLng: $_riderLatLng');
if (_riderLatLng == null) {
  print('Rider location not yet available');
}
```

---

## 📞 Quick Reference

### Routes
```dart
'/findingPartner'       // Finding delivery partner (customer)
'/liveTracking'         // Real-time tracking (customer)
'/riderDeliveryRequest' // Accept/reject screen (rider)
```

### Status Flow
```
PLACED → RIDER_ASSIGNED → RIDER_ACCEPTED → ON_THE_WAY_TO_PICKUP 
→ PICKED_UP → ON_THE_WAY_TO_DROP → DELIVERED
```

### Key Service Methods
```dart
RiderLocationService().startTracking(riderId, orderId, callback)
RiderLocationService().stopTracking(riderId)
RiderLocationService().listenToRiderLocation(riderId)
RiderLocationService().calculateETA(distanceKm)
```

---

**Total Integration Time**: 15-30 minutes (excluding backend)
**Lines of Code to Add**: ~50 lines
**Status**: ✅ Ready to Use!

🎉 **You're all set!** The heavy lifting is done. Just integrate the 3 steps above and you have Swiggy/Zomato-style tracking!
