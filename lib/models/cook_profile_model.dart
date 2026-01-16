import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// Extended cook profile for discovery screen
class CookProfileModel {
  final String cookId;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool verified;
  final GeoPoint? location;
  final String? address;
  
  // Cook-specific fields
  final double rating;
  final int totalOrders;
  final int totalReviews;
  final List<String> specialties; // e.g., ["North Indian", "Breakfast", "Vegan"]
  final bool isVeg;
  final String? bio; // Short description
  final List<String> kitchenImages;
  final Map<String, bool> availableTimeSlots; // e.g., {"breakfast": true, "lunch": true, "dinner": false}
  final double? avgPricePerMeal;
  final DateTime joinedAt;
  final bool isAvailable; // Currently accepting orders

  CookProfileModel({
    required this.cookId,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.verified,
    this.location,
    this.address,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalReviews = 0,
    this.specialties = const [],
    this.isVeg = false,
    this.bio,
    this.kitchenImages = const [],
    this.availableTimeSlots = const {},
    this.avgPricePerMeal,
    required this.joinedAt,
    this.isAvailable = true,
  });

  factory CookProfileModel.fromMap(Map<String, dynamic> map, String cookId) {
    return CookProfileModel(
      cookId: cookId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      verified: map['verified'] ?? false,
      location: map['location'],
      address: map['address'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      totalReviews: map['totalReviews'] ?? 0,
      specialties: List<String>.from(map['specialties'] ?? []),
      isVeg: map['isVeg'] ?? false,
      bio: map['bio'],
      kitchenImages: List<String>.from(map['kitchenImages'] ?? []),
      availableTimeSlots: Map<String, bool>.from(map['availableTimeSlots'] ?? {}),
      avgPricePerMeal: map['avgPricePerMeal']?.toDouble(),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'verified': verified,
      'location': location,
      'address': address,
      'rating': rating,
      'totalOrders': totalOrders,
      'totalReviews': totalReviews,
      'specialties': specialties,
      'isVeg': isVeg,
      'bio': bio,
      'kitchenImages': kitchenImages,
      'availableTimeSlots': availableTimeSlots,
      'avgPricePerMeal': avgPricePerMeal,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isAvailable': isAvailable,
    };
  }

  // Calculate distance from user location (in km)
  double? distanceFrom(GeoPoint? userLocation) {
    if (location == null || userLocation == null) return null;
    
    // Haversine formula
    const double earthRadius = 6371; // km
    double dLat = _toRadians(userLocation.latitude - location!.latitude);
    double dLon = _toRadians(userLocation.longitude - location!.longitude);
    
    double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(location!.latitude)) *
        math.cos(_toRadians(userLocation.latitude)) *
        math.pow(math.sin(dLon / 2), 2);
    
    double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
