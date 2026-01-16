# 🗺️ Real-Time Tracking - Route Usage Guide

## Quick Navigation Reference

### Customer Routes

#### 1. Finding Partner Screen
```dart
// When customer creates order (status: PLACED)
Navigator.pushNamed(
  context,
  '/findingPartner',
  arguments: {'orderId': orderId},
);
```
**Shows**: Loading animation, "Finding nearest delivery partner", map with pickup + drop markers

**Auto-navigates to**: Live Tracking when rider accepts (status: RIDER_ACCEPTED)

---

#### 2. Live Tracking Screen
```dart
// After rider accepts (status: RIDER_ACCEPTED or later)
Navigator.pushNamed(
  context,
  '/liveTracking',
  arguments: {'orderId': orderId},
);
```
**Shows**: Real-time rider location, ETA, distance, route polyline, rider info

**Updates**: Every 4 seconds via Firestore stream

---

### Rider Routes

#### 3. Delivery Request Screen
```dart
// When rider is assigned (status: RIDER_ASSIGNED)
Navigator.pushNamed(
  context,
  '/riderDeliveryRequest',
  arguments: {'orderId': orderId},
);
```
**Shows**: Order details, delivery fee, pickup/drop addresses, Accept/Reject buttons

**On Accept**: 
- Status → RIDER_ACCEPTED
- Starts GPS tracking
- Navigates to rider navigation screen

---

## Complete Flow Example

### Customer Side
```dart
// 1. Order Created
final orderId = await createOrder(...);

// 2. Redirect to Finding Partner
Navigator.pushNamed(
  context,
  '/findingPartner',
  arguments: {'orderId': orderId},
);

// 3. Screen auto-navigates to /liveTracking when rider accepts
// (No manual navigation needed!)
```

### Backend Side
```dart
// When rider is found
await FirebaseFirestore.instance
  .collection('orders')
  .doc(orderId)
  .update({
    'status': 'RIDER_ASSIGNED',
    'assignedRiderId': riderId,
    'assignedRiderName': name,
    'assignedRiderPhone': phone,
  });

// Send notification to rider
await sendPushNotification(riderId, ...);
```

### Rider Side
```dart
// 1. Receive notification, open app
Navigator.pushNamed(
  context,
  '/riderDeliveryRequest',
  arguments: {'orderId': orderId},
);

// 2. Rider clicks "Accept & Start"
// (Handled automatically by screen)

// 3. Screen navigates to /riderNavigation
// GPS tracking starts automatically
```

---

## Status-Based Navigation

```dart
// Smart navigation based on order status
void navigateToTracking(String orderId, OrderStatus status) {
  switch (status) {
    case OrderStatus.PLACED:
    case OrderStatus.ACCEPTED:
    case OrderStatus.RIDER_ASSIGNED:
      // Show finding partner screen
      Navigator.pushNamed(
        context,
        '/findingPartner',
        arguments: {'orderId': orderId},
      );
      break;
      
    case OrderStatus.RIDER_ACCEPTED:
    case OrderStatus.ON_THE_WAY_TO_PICKUP:
    case OrderStatus.PICKED_UP:
    case OrderStatus.ON_THE_WAY_TO_DROP:
      // Show live tracking
      Navigator.pushNamed(
        context,
        '/liveTracking',
        arguments: {'orderId': orderId},
      );
      break;
      
    case OrderStatus.DELIVERED:
      // Show order history or confirmation
      Navigator.pushNamed(
        context,
        '/orderHistory',
      );
      break;
      
    case OrderStatus.CANCELLED:
      // Show cancellation details
      showDialog(...);
      break;
  }
}
```

---

## Integration Points

### In Order History Screen
```dart
ListTile(
  title: Text('Order #${order.orderId}'),
  subtitle: Text(_getStatusText(order.status)),
  trailing: ElevatedButton(
    onPressed: () {
      // Navigate based on status
      if (order.status == OrderStatus.PLACED ||
          order.status == OrderStatus.RIDER_ASSIGNED) {
        Navigator.pushNamed(
          context,
          '/findingPartner',
          arguments: {'orderId': order.orderId},
        );
      } else if (order.status == OrderStatus.RIDER_ACCEPTED ||
                 order.status == OrderStatus.ON_THE_WAY_TO_PICKUP ||
                 order.status == OrderStatus.PICKED_UP ||
                 order.status == OrderStatus.ON_THE_WAY_TO_DROP) {
        Navigator.pushNamed(
          context,
          '/liveTracking',
          arguments: {'orderId': order.orderId},
        );
      }
    },
    child: Text('Track Order'),
  ),
)
```

### In Cart Screen (After Checkout)
```dart
// After successful order creation
final orderId = await _createOrder();

// Clear cart
await cartProvider.clearCart();

// Navigate to tracking
Navigator.pushReplacementNamed(
  context,
  '/findingPartner',
  arguments: {'orderId': orderId},
);
```

### In Rider Home Screen
```dart
// When rider receives notification
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('orders')
    .where('assignedRiderId', isEqualTo: currentRiderId)
    .where('status', isEqualTo: 'RIDER_ASSIGNED')
    .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
      return ElevatedButton(
        onPressed: () {
          final orderId = snapshot.data!.docs.first.id;
          Navigator.pushNamed(
            context,
            '/riderDeliveryRequest',
            arguments: {'orderId': orderId},
          );
        },
        child: Text('New Delivery Request'),
      );
    }
    return SizedBox.shrink();
  },
)
```

---

## Testing Routes

### Test Finding Partner Screen
```dart
// In any screen
ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(
      context,
      '/findingPartner',
      arguments: {'orderId': 'TEST_ORDER_ID'},
    );
  },
  child: Text('Test Finding Partner'),
)
```

### Test Live Tracking Screen
```dart
// In any screen
ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(
      context,
      '/liveTracking',
      arguments: {'orderId': 'TEST_ORDER_ID'},
    );
  },
  child: Text('Test Live Tracking'),
)
```

### Test Rider Request Screen
```dart
// In any screen
ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(
      context,
      '/riderDeliveryRequest',
      arguments: {'orderId': 'TEST_ORDER_ID'},
    );
  },
  child: Text('Test Rider Request'),
)
```

---

## AppRouter Constants

```dart
// From app_router.dart
static const String findingPartner = '/findingPartner';
static const String liveTracking = '/liveTracking';
static const String riderDeliveryRequest = '/riderDeliveryRequest';

// Usage
Navigator.pushNamed(context, AppRouter.findingPartner, ...);
Navigator.pushNamed(context, AppRouter.liveTracking, ...);
Navigator.pushNamed(context, AppRouter.riderDeliveryRequest, ...);
```

---

## Common Patterns

### Replace vs Push
```dart
// Use pushNamed for normal navigation (can go back)
Navigator.pushNamed(context, '/findingPartner', ...);

// Use pushReplacementNamed for final destinations (no back)
Navigator.pushReplacementNamed(context, '/liveTracking', ...);
```

### Passing Complex Arguments
```dart
Navigator.pushNamed(
  context,
  '/findingPartner',
  arguments: {
    'orderId': orderId,
    'customerId': customerId, // Optional
    'showAnimation': true,     // Optional
  },
);
```

### Receiving Arguments in Screen
```dart
@override
Widget build(BuildContext context) {
  final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  final orderId = args['orderId'] as String;
  
  // Use orderId
}
```

---

**Quick Tip**: All three screens auto-handle Firestore streams and status updates. Just pass the `orderId` and they do the rest! 🚀
