import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order_model.dart';
import 'firestore_service.dart';

/// 🤖 Rider Assignment Service (AUTO-ASSIGNMENT)
/// 
/// ⚠️ IMPORTANT: This is for AUTO-ASSIGNMENT only (e.g., for Tiffin service)
/// 
/// For NORMAL FOOD delivery:
/// - DO NOT use auto-assignment
/// - Use MANUAL RIDER ACCEPTANCE instead
/// - Orders appear in rider's available orders list when status = READY
/// - First rider to accept gets the order (transaction-based)
/// 
/// AUTO-ASSIGNMENT FLOW (for Tiffin or special cases):
/// 1. Cook marks food READY (status = READY)
/// 2. This service detects status = READY
/// 3. Finds nearest available rider
/// 4. Updates order to RIDER_ASSIGNED
/// 5. Sends notification to rider
/// 
/// PRODUCTION NOTE: Use Cloud Functions for auto-assignment in production!
/// This client-side version is for development/testing only.
class RiderAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Assign nearest available rider to an order that is READY
  /// 
  /// Only works if order status = READY (food is prepared and ready for pickup)
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

      // ⚠️ CRITICAL: Only assign if food is READY
      if (order.status != OrderStatus.READY) {
        print('⚠️ Order status is ${order.status.name}, expected READY. Skipping assignment.');
        return;
      }

      print('🍽️ Food is ready for order $orderId. Finding nearest rider...');

      // 2. Get all available riders who are online
      final ridersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rider')
          .where('isOnline', isEqualTo: true)
          .get();

      if (ridersSnapshot.docs.isEmpty) {
        throw Exception('No available riders online');
      }

      // 3. Find nearest rider to PICKUP location (cook/restaurant)
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

      // 4. Update order with rider assignment using proper method
      await _firestoreService.assignRiderToOrder(
        orderId: orderId,
        riderId: nearestRiderId,
        riderName: nearestRiderName ?? 'Unknown Rider',
        riderPhone: nearestRiderPhone,
      );

      // 5. Calculate delivery distance for earnings
      final dropLat = order.dropLocation.latitude;
      final dropLng = order.dropLocation.longitude;
      final deliveryDistanceKm = Geolocator.distanceBetween(
        pickupLat,
        pickupLng,
        dropLat,
        dropLng,
      ) / 1000;

      // 6. Create delivery document
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
        'distanceKm': deliveryDistanceKm,
        'riderToPickupDistanceKm': minDistance, // Distance rider needs to travel to pickup
        'estimatedMinutes': (deliveryDistanceKm * 3).round(), // Rough estimate: 3 min per km
        'assignedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Assigned rider $nearestRiderName to order $orderId');
      print('📦 Created delivery document');
      print('📍 Pickup distance: ${minDistance.toStringAsFixed(1)} km');
      print('📍 Delivery distance: ${deliveryDistanceKm.toStringAsFixed(1)} km');

      // TODO: Send push notification to rider
      // await _sendNotificationToRider(nearestRiderId, orderId);

    } catch (e) {
      print('❌ Error assigning rider: $e');
      rethrow;
    }
  }

  /// Listen to READY orders and auto-assign riders
  /// 
  /// For testing only! In production, use Cloud Functions
  /// This watches for orders that change to READY status
  /// 
  /// Example:
  /// ```dart
  /// final service = RiderAssignmentService();
  /// service.startAutoAssignment();
  /// ```
  void startAutoAssignment() {
    print('🚀 Starting auto-assignment service (watching for READY orders)...');
    
    _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.READY.name)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          final orderId = change.doc.id;
          final data = change.doc.data();
          
          // Only assign if not already assigned
          if (data?['assignedRiderId'] == null) {
            print('🍽️ Food ready detected for order: $orderId');
            assignNearestRider(orderId).catchError((e) {
              print('❌ Auto-assignment failed for $orderId: $e');
            });
          }
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
