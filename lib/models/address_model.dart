import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String addressId;
  final String userId;
  final String label; // 'Home', 'Office', 'Other'
  final String fullAddress;
  final String landmark;
  final GeoPoint location;
  final String city;
  final String state;
  final String pincode;
  final String contactName;
  final String contactPhone;
  final bool isDefault;
  final DateTime createdAt;

  AddressModel({
    required this.addressId,
    required this.userId,
    required this.label,
    required this.fullAddress,
    this.landmark = '',
    required this.location,
    required this.city,
    required this.state,
    required this.pincode,
    required this.contactName,
    required this.contactPhone,
    this.isDefault = false,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'addressId': addressId,
      'userId': userId,
      'label': label,
      'fullAddress': fullAddress,
      'landmark': landmark,
      'location': location,
      'city': city,
      'state': state,
      'pincode': pincode,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      addressId: map['addressId'] ?? '',
      userId: map['userId'] ?? '',
      label: map['label'] ?? 'Other',
      fullAddress: map['fullAddress'] ?? '',
      landmark: map['landmark'] ?? '',
      location: map['location'] ?? const GeoPoint(0, 0),
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      contactName: map['contactName'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      isDefault: map['isDefault'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  AddressModel copyWith({
    String? addressId,
    String? userId,
    String? label,
    String? fullAddress,
    String? landmark,
    GeoPoint? location,
    String? city,
    String? state,
    String? pincode,
    String? contactName,
    String? contactPhone,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return AddressModel(
      addressId: addressId ?? this.addressId,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      landmark: landmark ?? this.landmark,
      location: location ?? this.location,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
