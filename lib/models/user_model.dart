import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String phone;
  final String name;
  final String role; // customer, cook, rider
  final bool verified; // for cooks - verification status
  final String? photoUrl;
  final String? address;
  final GeoPoint? location;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.phone,
    required this.name,
    required this.role,
    this.verified = false,
    this.photoUrl,
    this.address,
    this.location,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'customer',
      verified: map['verified'] ?? false,
      photoUrl: map['photoUrl'],
      address: map['address'],
      location: map['location'],
      fcmToken: map['fcmToken'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'name': name,
      'role': role,
      'verified': verified,
      'photoUrl': photoUrl,
      'address': address,
      'location': location,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? email,
    String? phone,
    String? name,
    String? role,
    bool? verified,
    String? photoUrl,
    String? address,
    GeoPoint? location,
    String? fcmToken,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      verified: verified ?? this.verified,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
