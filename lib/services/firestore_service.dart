import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';
import '../models/order_model.dart';
import '../models/delivery_model.dart';
import '../models/verification_model.dart';
import '../models/address_model.dart';
import '../models/review_model.dart';
import '../models/chat_message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔒 Accept order with Firestore transaction (prevents race conditions)
  /// 
  /// PRODUCTION-SAFE: Only one rider can accept an order
  /// Returns: true if successful, false if order already taken
  Future<bool> acceptOrderAsRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderPhone,
  }) async {
    try {
      print('🔒 [Transaction] Attempting to accept order $orderId by rider $riderId');
      
      final result = await _firestore.runTransaction<bool>((transaction) async {
        // 1. Read order document
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);
        
        if (!orderSnapshot.exists) {
          throw Exception('Order not found');
        }
        
        final orderData = orderSnapshot.data()!;
        final currentStatus = orderData['status'] as String;
        final assignedRiderId = orderData['assignedRiderId'] as String?;
        
        // 2. Validate: Order must be READY and not yet assigned
        if (currentStatus != OrderStatus.READY.name) {
          print('❌ [Transaction] Order status is $currentStatus, expected READY');
          return false; // Order not ready for pickup
        }
        
        if (assignedRiderId != null && assignedRiderId.isNotEmpty) {
          print('❌ [Transaction] Order already assigned to rider $assignedRiderId');
          return false; // Order already taken by another rider
        }
        
        // 3. Check if rider already has an active delivery
        // DISABLED - Riders can accept multiple deliveries
        /*
        final activeDeliveriesQuery = await _firestore
            .collection('orders')
            .where('assignedRiderId', isEqualTo: riderId)
            .where('status', whereIn: [
              OrderStatus.RIDER_ASSIGNED.name,
              OrderStatus.RIDER_ACCEPTED.name,
              OrderStatus.ON_THE_WAY_TO_PICKUP.name,
              OrderStatus.PICKED_UP.name,
              OrderStatus.ON_THE_WAY_TO_DROP.name,
            ])
            .get();
        
        if (activeDeliveriesQuery.docs.isNotEmpty) {
          print('❌ [Transaction] Rider already has ${activeDeliveriesQuery.docs.length} active delivery(ies)');
          throw Exception('You already have an active delivery. Complete it first.');
        }
        */
        
        // 4. Update order - assign rider (READY → RIDER_ASSIGNED)
        transaction.update(orderRef, {
          'status': OrderStatus.RIDER_ASSIGNED.name,
          'assignedRiderId': riderId,
          'assignedRiderName': riderName,
          'assignedRiderPhone': riderPhone,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ [Transaction] Order $orderId successfully assigned to rider $riderId');
        return true;
      });
      
      return result;
    } catch (e) {
      print('❌ [Transaction] Error: $e');
      rethrow;
    }
  }

  // Dishes
  Future<void> addDish(DishModel dish) async {
    await _firestore.collection('dishes').doc(dish.dishId).set(dish.toMap());
  }

  Future<void> updateDish(DishModel dish) async {
    await _firestore.collection('dishes').doc(dish.dishId).update(dish.toMap());
  }

  Future<void> deleteDish(String dishId) async {
    await _firestore.collection('dishes').doc(dishId).delete();
  }

  Stream<List<DishModel>> getDishes() {
    return _firestore
        .collection('dishes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DishModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<DishModel>> getCookDishes(String cookId) {
    return _firestore
        .collection('dishes')
        .where('cookId', isEqualTo: cookId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DishModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<DishModel?> getDishById(String dishId) async {
    DocumentSnapshot doc =
        await _firestore.collection('dishes').doc(dishId).get();
    if (doc.exists) {
      return DishModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Orders
  Future<String> createOrder(OrderModel order) async {
    DocumentReference ref =
        await _firestore.collection('orders').add(order.toMap());
    return ref.id;
  }

  Future<void> updateOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.orderId).update(order.toMap());
  }

  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        // Note: Removed .orderBy to avoid requiring Firestore composite index
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort in memory by createdAt descending (newest first)
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return orders;
        });
  }

  Stream<List<OrderModel>> getCookOrders(String cookId) {
    return _firestore
        .collection('orders')
        .where('cookId', isEqualTo: cookId)
        // Note: Removed .orderBy to avoid requiring Firestore composite index
        // Sorting in memory instead (see below)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .where((order) => 
                order.status != OrderStatus.DELIVERED && 
                order.status != OrderStatus.CANCELLED)
              .toList();
          
          // Sort in memory by createdAt descending (newest first)
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return orders;
        });
  }

  Stream<OrderModel?> getOrderById(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map((doc) {
      if (doc.exists) {
        return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  Future<OrderModel?> getOrder(String orderId) async {
    DocumentSnapshot doc = await _firestore.collection('orders').doc(orderId).get();
    if (doc.exists) {
      return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Verifications
  Future<String> submitVerification(VerificationModel verification) async {
    DocumentReference ref = await _firestore
        .collection('cook_verifications')
        .add(verification.toMap());
    
    // ✅ Update user's verificationStatus field
    await _firestore.collection('users').doc(verification.cookId).update({
      'verificationStatus': 'PENDING',
      'verified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    return ref.id;
  }

  Stream<VerificationModel?> getCookVerification(String cookId) {
    return _firestore
        .collection('cook_verifications')
        .where('cookId', isEqualTo: cookId)
        // Note: Removed .orderBy and .limit, sorting in memory instead
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      
      // Sort in memory by createdAt descending and get first (most recent)
      final verifications = snapshot.docs
          .map((doc) => VerificationModel.fromMap(doc.data(), doc.id))
          .toList();
      verifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      if (verifications.isNotEmpty) {
        return verifications.first;
      }
      return null;
    });
  }

  /// ✅ Admin updates verification status and syncs to user document
  /// This method should ONLY be called from admin panel
  Future<void> updateVerificationStatus({
    required String verificationId,
    required String cookId,
    required String status, // "PENDING", "APPROVED", "REJECTED"
    String? adminNotes,
    String? rejectionReason,
  }) async {
    // Update verification document
    await _firestore.collection('cook_verifications').doc(verificationId).update({
      'status': status,
      'adminNotes': adminNotes,
      'rejectionReason': rejectionReason,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    // ✅ Sync verification status to user document
    await _firestore.collection('users').doc(cookId).update({
      'verificationStatus': status,
      'verified': status == 'APPROVED', // Set verified=true only if APPROVED
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Deliveries
  Future<String> createDelivery(DeliveryModel delivery) async {
    DocumentReference ref =
        await _firestore.collection('deliveries').add(delivery.toMap());
    return ref.id;
  }

  Future<void> updateDelivery(DeliveryModel delivery) async {
    await _firestore
        .collection('deliveries')
        .doc(delivery.deliveryId)
        .update(delivery.toMap());
  }

  Stream<List<DeliveryModel>> getRiderDeliveries(String riderId) {
    return _firestore
        .collection('deliveries')
        .where('riderId', isEqualTo: riderId)
        .where('status', whereIn: ['ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'ON_THE_WAY', 'DELIVERED'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // 🆕 Get unassigned orders for riders (READY orders waiting for rider acceptance)
  // PRODUCTION RULE: Only show orders where food is READY for pickup
  Stream<List<OrderModel>> getUnassignedOrders() {
    print('🔍 [FirestoreService] Setting up unassigned orders stream (READY status only)...');
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.READY.name) // Only READY orders (food prepared)
        .where('isActive', isEqualTo: true) // ✅ Must be active for riders to see
        .where('assignedRiderId', isNull: true) // Not yet assigned to any rider
        .limit(50)
        .snapshots()
        .map((snapshot) {
          print('📡 [FirestoreService] Snapshot received: ${snapshot.docs.length} READY orders');
          final orders = snapshot.docs
              .map((doc) {
                print('   Order: ${doc.id} - Status: ${doc.data()['status']} - Active: ${doc.data()['isActive']} - Cook: ${doc.data()['cookName']}');
                return OrderModel.fromMap(doc.data(), doc.id);
              })
              .toList();
          // Sort in memory by createdAt descending (newest first)
          orders.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          print('✅ [FirestoreService] Mapped and sorted ${orders.length} READY orders');
          return orders;
        });
  }

  Stream<DeliveryModel?> getDeliveryByOrderId(String orderId) {
    return _firestore
        .collection('deliveries')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return DeliveryModel.fromMap(
            snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    });
  }

  // Addresses
  Future<void> saveAddress(AddressModel address) async {
    await _firestore.collection('addresses').doc(address.addressId).set(address.toMap());
  }

  Stream<List<AddressModel>> getUserAddresses(String userId) {
    return _firestore
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        // Note: Removed .orderBy clauses to avoid requiring Firestore composite index
        .snapshots()
        .map((snapshot) {
          final addresses = snapshot.docs
              .map((doc) => AddressModel.fromMap(doc.data()))
              .toList();
          
          // Sort in memory: default addresses first, then by createdAt descending
          addresses.sort((a, b) {
            if (a.isDefault != b.isDefault) {
              return a.isDefault ? -1 : 1; // Default addresses first
            }
            return b.createdAt.compareTo(a.createdAt); // Newest first
          });
          
          return addresses;
        });
  }

  Future<AddressModel?> getDefaultAddress(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return AddressModel.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> deleteAddress(String addressId) async {
    await _firestore.collection('addresses').doc(addressId).delete();
  }

  // Reviews
  Future<void> addReview(ReviewModel review) async {
    await _firestore.collection('reviews').doc(review.reviewId).set(review.toMap());
    
    // Update dish rating (check if dish exists first)
    final dishDoc = await _firestore.collection('dishes').doc(review.dishId).get();
    
    if (!dishDoc.exists) {
      print('⚠️ Dish ${review.dishId} not found in database, skipping rating update');
      return;
    }
    
    final reviews = await _firestore
        .collection('reviews')
        .where('dishId', isEqualTo: review.dishId)
        .get();
    
    if (reviews.docs.isNotEmpty) {
      double totalRating = 0;
      for (var doc in reviews.docs) {
        totalRating += (doc.data()['rating'] as num).toDouble();
      }
      double avgRating = totalRating / reviews.docs.length;
      
      await _firestore.collection('dishes').doc(review.dishId).update({
        'rating': avgRating,
        'totalRatings': reviews.docs.length,
      });
    }
  }

  Stream<List<ReviewModel>> getDishReviews(String dishId) {
    return _firestore
        .collection('reviews')
        .where('dishId', isEqualTo: dishId)
        // Note: Removed .orderBy to avoid requiring Firestore composite index
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map((doc) => ReviewModel.fromMap(doc.data()))
              .toList();
          
          // Sort in memory by createdAt descending (newest first)
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return reviews;
        });
  }

  Stream<List<ReviewModel>> getCookReviews(String cookId) {
    return _firestore
        .collection('reviews')
        .where('cookId', isEqualTo: cookId)
        // Note: Removed .orderBy to avoid requiring Firestore composite index
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map((doc) => ReviewModel.fromMap(doc.data()))
              .toList();
          
          // Sort in memory by createdAt descending (newest first)
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return reviews;
        });
  }

  // Chat Messages
  Future<void> sendMessage(ChatMessageModel message) async {
    await _firestore.collection('chats').doc(message.messageId).set(message.toMap());
  }

  Stream<List<ChatMessageModel>> getOrderMessages(String orderId) {
    return _firestore
        .collection('chats')
        .where('orderId', isEqualTo: orderId)
        // Note: Removed .orderBy to avoid requiring Firestore composite index
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data()))
              .toList();
          
          // Sort in memory by timestamp ascending (oldest first)
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          return messages;
        });
  }

  Future<void> markMessageAsRead(String messageId) async {
    await _firestore.collection('chats').doc(messageId).update({'isRead': true});
  }

  // Delivery Location Updates (for rider navigation)
  Future<void> updateDeliveryLocation(
    String deliveryId,
    double latitude,
    double longitude,
  ) async {
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'currentLocation': GeoPoint(latitude, longitude),
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<DeliveryModel?> getDeliveryById(String deliveryId) {
    return _firestore
        .collection('deliveries')
        .doc(deliveryId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return DeliveryModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> updateDeliveryStatus(
    String deliveryId,
    DeliveryStatus status,
  ) async {
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔐 ORDER STATE MACHINE - Production-Grade Status Management
  // ═══════════════════════════════════════════════════════════════════════

  /// Valid order status transitions map
  static const Map<OrderStatus, List<OrderStatus>> _validTransitions = {
    OrderStatus.PLACED: [OrderStatus.ACCEPTED, OrderStatus.CANCELLED],
    OrderStatus.ACCEPTED: [OrderStatus.PREPARING, OrderStatus.CANCELLED],
    OrderStatus.PREPARING: [OrderStatus.READY, OrderStatus.CANCELLED],
    OrderStatus.READY: [OrderStatus.RIDER_ASSIGNED, OrderStatus.CANCELLED],
    OrderStatus.RIDER_ASSIGNED: [
      OrderStatus.RIDER_ACCEPTED,
      OrderStatus.PLACED, // Allow unassignment if rider rejects
      OrderStatus.CANCELLED
    ],
    OrderStatus.RIDER_ACCEPTED: [
      OrderStatus.ON_THE_WAY_TO_PICKUP,
      OrderStatus.CANCELLED
    ],
    OrderStatus.ON_THE_WAY_TO_PICKUP: [OrderStatus.PICKED_UP],
    OrderStatus.PICKED_UP: [OrderStatus.ON_THE_WAY_TO_DROP],
    OrderStatus.ON_THE_WAY_TO_DROP: [OrderStatus.DELIVERED],
    OrderStatus.DELIVERED: [],
    OrderStatus.CANCELLED: [],
  };

  /// Validate if status transition is allowed
  bool isValidOrderTransition(OrderStatus from, OrderStatus to) {
    if (from == to) return false;
    final allowed = _validTransitions[from];
    return allowed?.contains(to) ?? false;
  }

  /// Update order status with validation
  /// Throws [StateError] if transition is invalid
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw StateError('Order $orderId not found');
      }

      final orderData = orderDoc.data()!;
      final currentStatus = OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == orderData['status'],
        orElse: () => OrderStatus.PLACED,
      );

      // Validate transition
      if (!isValidOrderTransition(currentStatus, newStatus)) {
        throw StateError(
            'Invalid status transition: ${currentStatus.name} → ${newStatus.name}');
      }

      // Prepare update data
      final updateData = {
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      // Add status-specific timestamps
      switch (newStatus) {
        case OrderStatus.ACCEPTED:
          updateData['acceptedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.RIDER_ACCEPTED:
          updateData['riderAcceptedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.PICKED_UP:
          updateData['pickedUpAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.DELIVERED:
          updateData['deliveredAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.CANCELLED:
          updateData['cancelledAt'] = FieldValue.serverTimestamp();
          break;
        default:
          break;
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);

      print(
          '✅ Order $orderId: ${currentStatus.name} → ${newStatus.name}');
    } catch (e) {
      print('❌ Failed to update order status: $e');
      rethrow;
    }
  }

  /// Cook accepts order
  Future<void> cookAcceptOrder(String orderId, String cookId) async {
    await updateOrderStatus(
      orderId: orderId,
      newStatus: OrderStatus.ACCEPTED,
      additionalData: {'acceptedBy': cookId},
    );
  }

  /// Cook marks order as PREPARING
  Future<void> markOrderPreparing(String orderId) async {
    await updateOrderStatus(
      orderId: orderId,
      newStatus: OrderStatus.PREPARING,
      additionalData: {'preparingStartedAt': FieldValue.serverTimestamp()},
    );
  }

  /// Cook marks food as READY for pickup (does NOT assign rider yet)
  /// Rider assignment should be triggered by external service after this
  Future<void> markFoodReady(String orderId) async {
    await updateOrderStatus(
      orderId: orderId,
      newStatus: OrderStatus.READY,
      additionalData: {
        'foodReadyAt': FieldValue.serverTimestamp(),
        'isActive': true, // ✅ Make visible to riders
      },
    );
    
    print('✅ Food marked ready for order $orderId');
    print('🔔 Rider assignment should be triggered now by external service');
  }

  /// System assigns rider to READY order (called by RiderAssignmentService)
  Future<void> assignRiderToOrder({
    required String orderId,
    required String riderId,
    required String riderName,
    String? riderPhone,
  }) async {
    await updateOrderStatus(
      orderId: orderId,
      newStatus: OrderStatus.RIDER_ASSIGNED,
      additionalData: {
        'assignedRiderId': riderId,
        'assignedRiderName': riderName,
        if (riderPhone != null) 'assignedRiderPhone': riderPhone,
        'assignedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Rider accepts delivery
  Future<void> riderAcceptOrder({
    required String orderId,
    required String riderId,
    required String riderName,
    String? riderPhone,
  }) async {
    await updateOrderStatus(
      orderId: orderId,
      newStatus: OrderStatus.RIDER_ACCEPTED,
      additionalData: {
        'assignedRiderId': riderId,
        'assignedRiderName': riderName,
        if (riderPhone != null) 'assignedRiderPhone': riderPhone,
        'isActive': true, // 🔥 Set delivery as active
        'riderAcceptedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Get user-friendly status description
  static String getOrderStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return 'Finding delivery partner...';
      case OrderStatus.ACCEPTED:
        return 'Order accepted by cook';
      case OrderStatus.PREPARING:
        return 'Preparing your order';
      case OrderStatus.READY:
        return 'Ready for pickup';
      case OrderStatus.RIDER_ASSIGNED:
        return 'Delivery partner assigned';
      case OrderStatus.RIDER_ACCEPTED:
        return 'On the way to pickup';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'Picking up your order';
      case OrderStatus.PICKED_UP:
        return 'Order picked up';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'On the way to you';
      case OrderStatus.DELIVERED:
        return 'Delivered successfully';
      case OrderStatus.CANCELLED:
        return 'Order cancelled';
    }
  }

  /// Get progress percentage for UI
  static double getOrderProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return 0.1;
      case OrderStatus.ACCEPTED:
        return 0.2;
      case OrderStatus.PREPARING:
        return 0.3;
      case OrderStatus.READY:
        return 0.35;
      case OrderStatus.RIDER_ASSIGNED:
        return 0.4;
      case OrderStatus.RIDER_ACCEPTED:
        return 0.5;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 0.65;
      case OrderStatus.PICKED_UP:
        return 0.75;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 0.85;
      case OrderStatus.DELIVERED:
        return 1.0;
      case OrderStatus.CANCELLED:
        return 0.0;
    }
  }
}
