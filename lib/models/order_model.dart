import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  PLACED,              // Order just placed, finding delivery partner
  ACCEPTED,            // Cook accepted the order
  PREPARING,           // Cook is preparing the food
  READY,               // Food is ready for pickup
  RIDER_ASSIGNED,      // System assigned a rider (rider not yet accepted)
  RIDER_ACCEPTED,      // Rider accepted the delivery (start GPS tracking)
  ON_THE_WAY_TO_PICKUP, // Rider moving to restaurant/home
  PICKED_UP,           // Rider picked up food
  ON_THE_WAY_TO_DROP,  // Rider moving to customer
  DELIVERED,           // Order delivered successfully
  CANCELLED            // Order cancelled
}

class OrderItem {
  final String dishId;
  final String dishName;
  final double price;
  final int quantity;

  OrderItem({
    required this.dishId,
    required this.dishName,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'dishId': dishId,
      'dishName': dishName,
      'price': price,
      'quantity': quantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      dishId: map['dishId'] ?? '',
      dishName: map['dishName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
    );
  }
}

class OrderModel {
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String cookId;
  final String cookName;
  final String? cookPhone;
  final List<OrderItem> dishItems;
  final double total;
  final String paymentMethod;
  final OrderStatus status;
  final bool isHomeToOffice; // Tiffin mode
  final String pickupAddress;
  final GeoPoint pickupLocation;
  final String dropAddress;
  final GeoPoint dropLocation;
  final DateTime? preferredTime;
  final String? assignedRiderId;
  final String? assignedRiderName;
  final String? assignedRiderPhone;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? cancellationReason;
  
  // 🚀 PRODUCTION DELIVERY SYSTEM
  final bool isActive;                   // Active delivery in progress
  final double? distanceKm;              // Actual delivery distance
  final double deliveryCharge;           // Total delivery cost
  final double? riderEarning;            // Rider's share (80%)
  final double? platformCommission;      // Platform's share (20%)
  final double? cashCollected;           // COD: Cash collected by rider
  final double? pendingSettlement;       // COD: Pending settlement with admin
  final bool isSettled;                  // COD: Settlement completed

  OrderModel({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.cookId,
    required this.cookName,
    this.cookPhone,
    required this.dishItems,
    required this.total,
    required this.paymentMethod,
    required this.status,
    this.isHomeToOffice = false,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.dropAddress,
    required this.dropLocation,
    this.preferredTime,
    this.assignedRiderId,
    this.assignedRiderName,
    this.assignedRiderPhone,
    required this.createdAt,
    this.acceptedAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancellationReason,
    this.isActive = false,
    this.distanceKm,
    this.deliveryCharge = 0.0,
    this.riderEarning,
    this.platformCommission,
    this.cashCollected,
    this.pendingSettlement,
    this.isSettled = false,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String orderId) {
    return OrderModel(
      orderId: orderId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      cookId: map['cookId'] ?? '',
      cookName: map['cookName'] ?? '',
      cookPhone: map['cookPhone'],
      dishItems: (map['dishItems'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      total: (map['total'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.PLACED,
      ),
      isHomeToOffice: map['isHomeToOffice'] ?? false,
      pickupAddress: map['pickupAddress'] ?? '',
      pickupLocation: map['pickupLocation'] ?? const GeoPoint(0, 0),
      dropAddress: map['dropAddress'] ?? '',
      dropLocation: map['dropLocation'] ?? const GeoPoint(0, 0),
      preferredTime: (map['preferredTime'] as Timestamp?)?.toDate(),
      assignedRiderId: map['assignedRiderId'],
      assignedRiderName: map['assignedRiderName'],
      assignedRiderPhone: map['assignedRiderPhone'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate(),
      pickedUpAt: (map['pickedUpAt'] as Timestamp?)?.toDate(),
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
      cancellationReason: map['cancellationReason'],
      isActive: map['isActive'] ?? false,
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      deliveryCharge: (map['deliveryCharge'] ?? 0).toDouble(),
      riderEarning: (map['riderEarning'] as num?)?.toDouble(),
      platformCommission: (map['platformCommission'] as num?)?.toDouble(),
      cashCollected: (map['cashCollected'] as num?)?.toDouble(),
      pendingSettlement: (map['pendingSettlement'] as num?)?.toDouble(),
      isSettled: map['isSettled'] ?? false,
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    // Calculate food subtotal from dish items (price * quantity for all items)
    final foodSubtotal = dishItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'cookId': cookId,
      'cookName': cookName,
      'cookPhone': cookPhone,
      'dishItems': dishItems.map((item) => item.toMap()).toList(),
      'total': total,
      'foodSubtotal': foodSubtotal, // 🍳 ADD: Food price only (for cook payment)
      'paymentMethod': paymentMethod,
      'status': status.name,
      'isHomeToOffice': isHomeToOffice,
      'pickupAddress': pickupAddress,
      'pickupLocation': pickupLocation,
      'dropAddress': dropAddress,
      'dropLocation': dropLocation,
      'preferredTime': preferredTime != null ? Timestamp.fromDate(preferredTime!) : null,
      'assignedRiderId': assignedRiderId,
      'assignedRiderName': assignedRiderName,
      'assignedRiderPhone': assignedRiderPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'cancellationReason': cancellationReason,      'isActive': isActive,
      'distanceKm': distanceKm,
      'deliveryCharge': deliveryCharge,
      'riderEarning': riderEarning,
      'platformCommission': platformCommission,
      'cashCollected': cashCollected,
      'pendingSettlement': pendingSettlement,
      'isSettled': isSettled,    };
  }

  OrderModel copyWith({
    OrderStatus? status,
    String? assignedRiderId,
    String? assignedRiderName,
    String? assignedRiderPhone,
    DateTime? acceptedAt,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    String? cancellationReason,
    bool? isActive,
    double? distanceKm,
    double? deliveryCharge,
    double? riderEarning,
    double? platformCommission,
    double? cashCollected,
    double? pendingSettlement,
    bool? isSettled,
  }) {
    return OrderModel(
      orderId: orderId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      cookId: cookId,
      cookName: cookName,
      cookPhone: cookPhone,
      dishItems: dishItems,
      total: total,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      isHomeToOffice: isHomeToOffice,
      pickupAddress: pickupAddress,
      pickupLocation: pickupLocation,
      dropAddress: dropAddress,
      dropLocation: dropLocation,
      preferredTime: preferredTime,
      assignedRiderId: assignedRiderId ?? this.assignedRiderId,
      assignedRiderName: assignedRiderName ?? this.assignedRiderName,
      assignedRiderPhone: assignedRiderPhone ?? this.assignedRiderPhone,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isActive: isActive ?? this.isActive,
      distanceKm: distanceKm ?? this.distanceKm,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      riderEarning: riderEarning ?? this.riderEarning,
      platformCommission: platformCommission ?? this.platformCommission,
      cashCollected: cashCollected ?? this.cashCollected,
      pendingSettlement: pendingSettlement ?? this.pendingSettlement,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}
