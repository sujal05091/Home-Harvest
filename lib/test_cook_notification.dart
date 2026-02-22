import 'package:cloud_firestore/cloud_firestore.dart';

/// Test function to manually create notification from cook app
/// This bypasses all the complex FCMService logic
Future<void> createTestNotificationFromCook({
  required String riderId,
  required String orderId,
}) async {
  try {
    print('🧪 [TEST] Creating test notification from cook...');
    print('   Rider ID: $riderId');
    print('   Order ID: $orderId');

    final notificationData = {
      'recipientId': riderId,
      'orderId': orderId,
      'type': 'NEW_DELIVERY_REQUEST',
      'title': '🚀 New Delivery Request',
      'body': 'Test notification from cook app',
      'data': {
        'orderId': orderId,
        'type': 'NEW_DELIVERY_REQUEST',
      },
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    print('📝 [TEST] Notification data ready');
    print('📤 [TEST] Writing to Firestore...');

    final docRef = await FirebaseFirestore.instance
        .collection('notifications')
        .add(notificationData);

    print('✅ [TEST] Notification created successfully!');
    print('   Document ID: ${docRef.id}');
    print('   Collection: notifications');
    print('   Recipient: $riderId');
    
  } catch (e, stackTrace) {
    print('❌ [TEST] ERROR creating notification: $e');
    print('📚 [TEST] Stack trace: $stackTrace');
    
    if (e.toString().contains('PERMISSION_DENIED')) {
      print('🚨 [TEST] PERMISSION DENIED - Check Firestore rules!');
    }
  }
}
