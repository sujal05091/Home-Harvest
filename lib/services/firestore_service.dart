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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<OrderModel>> getCookOrders(String cookId) {
    return _firestore
        .collection('orders')
        .where('cookId', isEqualTo: cookId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .where((order) => 
              order.status != OrderStatus.DELIVERED && 
              order.status != OrderStatus.CANCELLED)
            .toList());
  }

  Stream<OrderModel?> getOrderById(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map((doc) {
      if (doc.exists) {
        return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // Verifications
  Future<String> submitVerification(VerificationModel verification) async {
    DocumentReference ref = await _firestore
        .collection('cook_verifications')
        .add(verification.toMap());
    return ref.id;
  }

  Stream<VerificationModel?> getCookVerification(String cookId) {
    return _firestore
        .collection('cook_verifications')
        .where('cookId', isEqualTo: cookId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return VerificationModel.fromMap(
            snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
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
        .where('status', whereIn: ['ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'ON_THE_WAY'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryModel.fromMap(doc.data(), doc.id))
            .toList());
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
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AddressModel.fromMap(doc.data()))
            .toList());
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
    
    // Update dish rating
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromMap(doc.data()))
            .toList());
  }

  Stream<List<ReviewModel>> getCookReviews(String cookId) {
    return _firestore
        .collection('reviews')
        .where('cookId', isEqualTo: cookId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromMap(doc.data()))
            .toList());
  }

  // Chat Messages
  Future<void> sendMessage(ChatMessageModel message) async {
    await _firestore.collection('chats').doc(message.messageId).set(message.toMap());
  }

  Stream<List<ChatMessageModel>> getOrderMessages(String orderId) {
    return _firestore
        .collection('chats')
        .where('orderId', isEqualTo: orderId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessageModel.fromMap(doc.data()))
            .toList());
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
}
