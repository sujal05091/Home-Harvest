# 🔧 Integration Guide - Complete Active Delivery & Order Flow

## Quick Integration Checklist

This guide shows exactly where to integrate the new wallet, pricing, and COD systems into existing screens.

---

## 1️⃣ Update Order Placement (Customer Side)

### **File:** `lib/screens/customer/tiffin_order.dart` or similar order placement screen

### **STEP 1: Calculate Delivery Charge Before Placing Order**

**Add at top of file:**
```dart
import '../../services/pricing_service.dart';
```

**Before `_placeOrder()` or `_confirmOrder()`, add:**
```dart
Future<void> _calculateDeliveryCharge() async {
  final pricingService = PricingService();
  
  // Calculate distance
  final distanceKm = pricingService.calculateDistance(
    pickupLocation,  // GeoPoint from cook location
    dropLocation,    // GeoPoint from delivery address
  );
  
  // Get pricing
  final pricing = await pricingService.calculateDeliveryCharge(distanceKm);
  
  setState(() {
    _distanceKm = distanceKm;
    _deliveryCharge = pricing['deliveryCharge']!;
    _riderEarning = pricing['riderEarning']!;
    _platformCommission = pricing['platformCommission']!;
  });
}
```

**In order creation map, add:**
```dart
final orderData = {
  // ... existing fields ...
  'isActive': false,  // Will be set to true when rider accepts
  'distanceKm': _distanceKm,
  'deliveryCharge': _deliveryCharge,
  'riderEarning': _riderEarning,
  'platformCommission': _platformCommission,
  'paymentMethod': selectedPaymentMethod,  // "COD" or "ONLINE"
  'cashCollected': null,
  'pendingSettlement': null,
  'isSettled': false,
};
```

---

## 2️⃣ Update Order Completion (Rider Side)

### **File:** `lib/screens/rider/order_detail_screen.dart` or delivery tracking screen

### **STEP 1: Add Wallet Service Import**
```dart
import '../../services/wallet_service.dart';
import '../../services/pricing_service.dart';
```

### **STEP 2: Update `markDelivered()` or `completeOrder()`**

**BEFORE (old code):**
```dart
Future<void> _markDelivered() async {
  await _firestoreService.updateOrderStatus(
    orderId: widget.order.orderId,
    newStatus: OrderStatus.DELIVERED,
  );
  
  // Navigate back
  Navigator.pop(context);
}
```

**AFTER (new code with wallet credit):**
```dart
Future<void> _markDelivered() async {
  try {
    final order = widget.order;
    
    // 1. Update order status to DELIVERED
    await _firestoreService.updateOrderStatus(
      orderId: order.orderId,
      newStatus: OrderStatus.DELIVERED,
    );
    
    // 2. Set order as inactive
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.orderId)
        .update({'isActive': false});
    
    // 3. Credit rider wallet (ONLY for delivery earning)
    final walletService = WalletService();
    final riderEarning = order.riderEarning ?? 0.0;
    
    if (riderEarning > 0) {
      await walletService.creditWallet(
        riderId: order.assignedRiderId!,
        amount: riderEarning,
        orderId: order.orderId,
        description: 'Delivery earnings for order #${order.orderId.substring(0, 8)}',
      );
      
      print('✅ Credited ₹$riderEarning to rider wallet');
    }
    
    // 4. Handle COD settlement
    if (order.paymentMethod == 'COD') {
      final pricingService = PricingService();
      final total = order.total + order.deliveryCharge;  // Food + Delivery
      
      final codBreakdown = pricingService.calculateCODSettlement(
        cashCollected: total,
        riderEarning: riderEarning,
      );
      
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .update({
        'cashCollected': codBreakdown['cashCollected'],
        'pendingSettlement': codBreakdown['pendingSettlement'],
        'isSettled': false,
      });
      
      print('💰 COD: Cash ₹${codBreakdown['cashCollected']}, Pending ₹${codBreakdown['pendingSettlement']}');
    }
    
    // 5. Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Order delivered! +₹$riderEarning earned'),
        backgroundColor: Colors.green,
      ),
    );
    
    // 6. Navigate back
    Navigator.pop(context);
  } catch (e) {
    print('❌ Error marking delivered: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## 3️⃣ Active Delivery Persistence (Customer)

### **File:** `lib/screens/customer/home.dart` or main customer screen

### **Add in `initState()`:**
```dart
@override
void initState() {
  super.initState();
  _checkActiveOrder();
}

Future<void> _checkActiveOrder() async {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  
  try {
    final activeOrderSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    
    if (activeOrderSnapshot.docs.isNotEmpty) {
      final orderDoc = activeOrderSnapshot.docs.first;
      final order = OrderModel.fromFirestore(orderDoc);
      
      // Show banner or auto-navigate to tracking
      _showActiveDeliveryBanner(order);
      
      // OR auto-navigate:
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => OrderTrackingScreen(order: order),
      //   ),
      // );
    }
  } catch (e) {
    print('❌ Error checking active order: $e');
  }
}

void _showActiveDeliveryBanner(OrderModel order) {
  setState(() {
    _hasActiveDelivery = true;
    _activeOrder = order;
  });
}
```

### **Add Banner Widget in `build()`:**
```dart
if (_hasActiveDelivery && _activeOrder != null)
  GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(order: _activeOrder!),
        ),
      );
    },
    child: Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.delivery_dining, color: Colors.orange[800], size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚀 Delivery in Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Order #${_activeOrder!.orderId.substring(0, 8)}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.orange[800]),
        ],
      ),
    ),
  ),
```

---

## 4️⃣ Active Delivery Persistence (Rider)

### **File:** `lib/screens/rider/home.dart`

### **Same as customer, but check for assignedRiderId:**
```dart
Future<void> _checkActiveDelivery() async {
  final riderId = FirebaseAuth.instance.currentUser!.uid;
  
  try {
    final activeOrderSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('assignedRiderId', isEqualTo: riderId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    
    if (activeOrderSnapshot.docs.isNotEmpty) {
      final orderDoc = activeOrderSnapshot.docs.first;
      final order = OrderModel.fromFirestore(orderDoc);
      
      // Auto-navigate to delivery screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RiderDeliveryScreen(order: order),
          ),
        );
      });
    }
  } catch (e) {
    print('❌ Error checking active delivery: $e');
  }
}
```

---

## 5️⃣ Rider Accepts Order → Set isActive = true

### **File:** `lib/services/firestore_service.dart` or wherever rider accepts order

**Update `riderAcceptOrder()` method:**
```dart
Future<void> riderAcceptOrder({
  required String orderId,
  required String riderId,
  required String riderName,
  required String riderPhone,
}) async {
  await updateOrderStatus(
    orderId: orderId,
    newStatus: OrderStatus.RIDER_ACCEPTED,
    additionalData: {
      'assignedRiderId': riderId,
      'assignedRiderName': riderName,
      'assignedRiderPhone': riderPhone,
      'isActive': true,  // ⭐ SET ACTIVE HERE
      'riderAcceptedAt': FieldValue.serverTimestamp(),
    },
  );
}
```

---

## 6️⃣ Display Delivery Charge in Checkout

### **File:** Order summary/checkout screen

**Add below food total:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('Food Total'),
    Text('₹${foodTotal.toStringAsFixed(2)}'),
  ],
),
SizedBox(height: 8),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('Delivery Charge (${_distanceKm.toStringAsFixed(1)} km)'),
    Text('₹${_deliveryCharge.toStringAsFixed(2)}'),
  ],
),
Divider(),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'Grand Total',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    ),
    Text(
      '₹${(foodTotal + _deliveryCharge).toStringAsFixed(2)}',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    ),
  ],
),
```

---

## 7️⃣ Add Wallet to Rider Dashboard

### **File:** `lib/screens/rider/home.dart`

**Add wallet card in dashboard:**
```dart
StreamBuilder<RiderWalletModel?>(
  stream: WalletService().streamRiderWallet(riderId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return SizedBox();
    
    final wallet = snapshot.data!;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RiderWalletScreen()),
        );
      },
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[600]!, Colors.green[400]!],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💰 Wallet Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '₹${wallet.walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  },
),
```

---

## 8️⃣ COD Settlement Warning

### **File:** Rider order acceptance screen

**Before allowing rider to accept order:**
```dart
Future<bool> _canAcceptOrder() async {
  final walletService = WalletService();
  final canAccept = await walletService.canAcceptNewOrders(riderId);
  
  if (!canAccept) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('⚠️ Settlement Required'),
        content: Text(
          'You have pending cash settlements exceeding ₹500. '
          'Please settle with admin before accepting new orders.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }
  
  return true;
}

// In accept order button:
onPressed: () async {
  if (await _canAcceptOrder()) {
    // Accept order
  }
}
```

---

## ✅ Quick Test Workflow

1. **Place Order:**
   - Should calculate delivery charge based on distance
   - Should save pricing fields in order document

2. **Rider Accepts:**
   - `isActive` should become `true`
   - Customer sees banner on home screen

3. **Rider Delivers:**
   - Order status → DELIVERED
   - `isActive` → false
   - Wallet credited with rider earning
   - COD: pendingSettlement calculated

4. **Rider Checks Wallet:**
   - Balance increased
   - Transaction logged
   - Today's earnings updated

5. **Rider Withdraws:**
   - Request created with PENDING status
   - Admin approves (manual)
   - Balance deducted

---

## 🚀 Deploy Checklist

- [ ] Update Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Create `config/pricing` document in Firestore
- [ ] Test order placement with delivery charge
- [ ] Test order completion with wallet credit
- [ ] Test COD settlement calculation
- [ ] Test withdrawal request
- [ ] Test active delivery persistence

---

**Status:** Ready for integration! 🎯  
**Time Estimate:** 2-3 hours for all integrations  
**Difficulty:** Medium (copy-paste with minor adjustments)
