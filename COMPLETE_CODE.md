# HomeHarvest - Complete Application Code

## ALL CODE FILES PROVIDED BELOW

This document contains ALL the code for the HomeHarvest Flutter application.
Copy each code block to its respective file path as shown.

---

## ALREADY CREATED FILES ✅

The following files have already been created in your project:

1. `lib/main.dart` ✅
2. `lib/theme.dart` ✅  
3. `lib/app_router.dart` ✅
4. `lib/models/user_model.dart` ✅
5. `lib/models/dish_model.dart` ✅
6. `lib/models/order_model.dart` ✅
7. `lib/models/delivery_model.dart` ✅
8. `lib/models/verification_model.dart` ✅
9. `lib/services/auth_service.dart` ✅
10. `pubspec.yaml` ✅

---

## REMAINING FILES TO CREATE

Copy the code below to create each file:

### lib/services/firestore_service.dart

\`\`\`dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';
import '../models/order_model.dart';
import '../models/delivery_model.dart';
import '../models/verification_model.dart';

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
        .where('status', whereIn: ['PLACED', 'ACCEPTED', 'ASSIGNED', 'PICKED_UP', 'ON_THE_WAY'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
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
}
\`\`\`

---

Due to character limits, I need to provide you with a comprehensive file containing all the remaining code. Let me create a complete CODE_REFERENCE.md file that you can use:

