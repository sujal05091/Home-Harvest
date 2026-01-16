import 'package:cloud_firestore/cloud_firestore.dart';

enum DeliveryStatus {
  ASSIGNED,
  ACCEPTED,
  PICKED_UP,
  ON_THE_WAY,
  DELIVERED
}

class DeliveryModel {
  final String deliveryId;
  final String orderId;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final String customerId;
  final String cookId;
  final GeoPoint pickupLocation;
  final GeoPoint dropLocation;
  final GeoPoint? currentLocation;
  final DeliveryStatus status;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final double? distanceKm;
  final int? estimatedMinutes;
  final double? deliveryFee;

  DeliveryModel({
    required this.deliveryId,
    required this.orderId,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.customerId,
    required this.cookId,
    required this.pickupLocation,
    required this.dropLocation,
    this.currentLocation,
    required this.status,
    required this.assignedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.distanceKm,
    this.estimatedMinutes,
    this.deliveryFee,
  });

  factory DeliveryModel.fromMap(Map<String, dynamic> map, String deliveryId) {
    return DeliveryModel(
      deliveryId: deliveryId,
      orderId: map['orderId'] ?? '',
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      riderPhone: map['riderPhone'] ?? '',
      customerId: map['customerId'] ?? '',
      cookId: map['cookId'] ?? '',
      pickupLocation: map['pickupLocation'] ?? const GeoPoint(0, 0),
      dropLocation: map['dropLocation'] ?? const GeoPoint(0, 0),
      currentLocation: map['currentLocation'],
      status: DeliveryStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DeliveryStatus.ASSIGNED,
      ),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      pickedUpAt: (map['pickedUpAt'] as Timestamp?)?.toDate(),
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
      distanceKm: map['distanceKm']?.toDouble(),
      estimatedMinutes: map['estimatedMinutes'],
      deliveryFee: map['deliveryFee']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'customerId': customerId,
      'cookId': cookId,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'currentLocation': currentLocation,
      'status': status.name,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'distanceKm': distanceKm,
      'estimatedMinutes': estimatedMinutes,
      'deliveryFee': deliveryFee,
    };
  }

  DeliveryModel copyWith({
    GeoPoint? currentLocation,
    DeliveryStatus? status,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    double? distanceKm,
    int? estimatedMinutes,
    double? deliveryFee,
  }) {
    return DeliveryModel(
      deliveryId: deliveryId,
      orderId: orderId,
      riderId: riderId,
      riderName: riderName,
      riderPhone: riderPhone,
      customerId: customerId,
      cookId: cookId,
      pickupLocation: pickupLocation,
      dropLocation: dropLocation,
      currentLocation: currentLocation ?? this.currentLocation,
      status: status ?? this.status,
      assignedAt: assignedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      deliveryFee: deliveryFee ?? this.deliveryFee,
    );
  }
}
