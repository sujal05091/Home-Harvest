import 'package:cloud_firestore/cloud_firestore.dart';

/// Real-time Rider Location Model
/// Updated every 3-5 seconds during active delivery
class RiderLocationModel {
  final String riderId;
  final double latitude;
  final double longitude;
  final double? speed; // km/h
  final double? heading; // degrees
  final String? orderId; // Current active order
  final DateTime updatedAt;
  final bool isActive; // Is rider currently delivering

  RiderLocationModel({
    required this.riderId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    this.orderId,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'orderId': orderId,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory RiderLocationModel.fromMap(Map<String, dynamic> map) {
    return RiderLocationModel(
      riderId: map['riderId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      speed: map['speed']?.toDouble(),
      heading: map['heading']?.toDouble(),
      orderId: map['orderId'],
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  factory RiderLocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RiderLocationModel.fromMap(data);
  }
}
