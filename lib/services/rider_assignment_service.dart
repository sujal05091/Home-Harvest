import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order_model.dart';

/// 🤖 Rider Assignment Service
/// 
/// Automatically assigns nearest available rider to new orders
/// 
/// IMPORTANT: In production, use Cloud Functions for this logic!
/// This is a simplified version for testing purposes.
class RiderAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Assign nearest available rider to an order
  /// 
  /// Call this after order is created with status = PLACED
  /// 
  /// Example:
  /// ```dart
  /// final service = RiderAssignmentService();
  /// await service.assignNearestRider(orderId);
  /// ```
  Future<void> assignNearestRider(String orderId) async {
    try {
      // 1. Get the order
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final order = OrderModel.fromFirestore(orderDoc);

      if (order.status != OrderStatus.PLACED) {
        print('⚠️ Order status is not PLACED, skipping assignment');
        return;
      }

      // 2. Get all available riders
      final ridersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rider')
          .where('isOnline', isEqualTo: true)
          .get();

      if (ridersSnapshot.docs.isEmpty) {
        throw Exception('No available riders found');
      }

      // 3. Find nearest rider
      String? nearestRiderId;
      String? nearestRiderName;
      String? nearestRiderPhone;
      double minDistance = double.infinity;

      final pickupLat = order.pickupLocation.latitude;
      final pickupLng = order.pickupLocation.longitude;

      for (var riderDoc in ridersSnapshot.docs) {
        final riderData = riderDoc.data();
        
        // Get rider's last known location
        final riderLocation = riderData['lastLocation'] as GeoPoint?;
        
        if (riderLocation != null) {
          final distance = Geolocator.distanceBetween(
            pickupLat,
            pickupLng,
            riderLocation.latitude,
            riderLocation.longitude,
          ) / 1000; // Convert to kilometers

          if (distance < minDistance) {
            minDistance = distance;
            nearestRiderId = riderDoc.id;
            nearestRiderName = riderData['name'] as String?;
            nearestRiderPhone = riderData['phone'] as String?;
          }
        }
      }

      if (nearestRiderId == null) {
        throw Exception('Could not calculate rider distances');
      }

      // 4. Update order with rider assignment
      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.RIDER_ASSIGNED.name,
        'assignedRiderId': nearestRiderId,
        'assignedRiderName': nearestRiderName ?? 'Unknown Rider',
        'assignedRiderPhone': nearestRiderPhone ?? 'N/A',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Create delivery document
      await _firestore.collection('deliveries').doc(orderId).set({
        'deliveryId': orderId,
        'orderId': orderId,
        'riderId': nearestRiderId,
        'riderName': nearestRiderName ?? 'Unknown Rider',
        'riderPhone': nearestRiderPhone ?? 'N/A',
        'customerId': order.customerId,
        'cookId': order.cookId,
        'status': 'ASSIGNED',
        'pickupLocation': order.pickupLocation,
        'dropLocation': order.dropLocation,
        'deliveryFee': 40.0,
        'distanceKm': minDistance,
        'estimatedMinutes': (minDistance * 3).round(), // Rough estimate
        'assignedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Assigned rider $nearestRiderName to order $orderId');
      print('📦 Created delivery document for order $orderId');
      print('📍 Distance: ${minDistance.toStringAsFixed(1)} km');

      // TODO: Send push notification to rider
      // await _sendNotificationToRider(nearestRiderId, orderId);

    } catch (e) {
      print('❌ Error assigning rider: $e');
      rethrow;
    }
  }

  /// Listen to new orders and auto-assign riders
  /// 
  /// For testing only! In production, use Cloud Functions
  /// 
  /// Example:
  /// ```dart
  /// final service = RiderAssignmentService();
  /// service.startAutoAssignment();
  /// ```
  void startAutoAssignment() {
    _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.PLACED.name)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final orderId = change.doc.id;
          print('🆕 New order detected: $orderId');
          assignNearestRider(orderId).catchError((e) {
            print('❌ Auto-assignment failed for $orderId: $e');
          });
        }
      }
    });
  }

  // TODO: Implement push notification
  // Future<void> _sendNotificationToRider(String riderId, String orderId) async {
  //   // Get rider's FCM token
  //   // Send notification via Firebase Cloud Messaging
  // }
}
