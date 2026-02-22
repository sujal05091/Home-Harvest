import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// TEST SCRIPT: Manually create a notification to test popup
/// Run this from a button in the app to test if popup works
Future<void> createTestNotification() async {
  try {
    final riderId = 'pCPNkvC4hqTNZqMuLlqjue9NVAF3'; // Your rider ID
    final testOrderId = 'TEST_ORDER_${DateTime.now().millisecondsSinceEpoch}';
    
    print('🧪 [TEST] Creating test notification...');
    print('   Rider ID: $riderId');
    print('   Order ID: $testOrderId');
    
    // First create a test order
    await FirebaseFirestore.instance.collection('orders').doc(testOrderId).set({
      'orderId': testOrderId,
      'customerId': FirebaseAuth.instance.currentUser!.uid,
      'customerName': 'Test Customer',
      'customerPhone': '1234567890',
      'cookId': FirebaseAuth.instance.currentUser!.uid,
      'cookName': 'Test Cook',
      'dishItems': [
        {'dishId': 'test', 'dishName': 'Test Dish', 'price': 100, 'quantity': 1}
      ],
      'total': 150.0,
      'deliveryCharge': 50.0,
      'riderEarning': 50.0,
      'platformCommission': 10.0,
      'paymentMethod': 'COD',
      'status': 'READY',
      'isHomeToOffice': false, // IMPORTANT: Must be false for popup
      'pickupAddress': 'Test Pickup',
      'dropAddress': 'Test Drop',
      'pickupLocation': const GeoPoint(13.3882, 74.7398),
      'dropLocation': const GeoPoint(13.3599, 74.7629),
      'distanceKm': 5.0,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': false,
      'isSettled': false,
    });
    
    print('✅ [TEST] Test order created');
    
    // Now create notification
    final docRef = await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': riderId,
      'orderId': testOrderId,
      'type': 'NEW_DELIVERY_REQUEST',
      'title': '🧪 TEST New Delivery Request',
      'body': 'Test order ready for pickup',
      'data': {
        'orderId': testOrderId,
        'type': 'NEW_DELIVERY_REQUEST',
      },
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ [TEST] Notification created with ID: ${docRef.id}');
    print('🎯 [TEST] If rider app is running, popup should appear NOW!');
    print('');
    print('Check rider logs for:');
    print('  📩 [NotificationListener] Snapshot received with 1 documents');
    print('  🚀 [NotificationListener] Showing pop-up for NORMAL FOOD delivery');
    
  } catch (e) {
    print('❌ [TEST] Error: $e');
  }
}
