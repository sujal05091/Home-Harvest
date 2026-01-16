import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 👨‍🍳 COOK MODEL
/// Represents home cook profile for normal food ordering
class CookModel {
  final String cookId;
  final String name;
  final String email;
  final String? phone;
  final String? profileImage;
  final String? bio;
  final bool isVerified; // Kitchen verification status
  final bool isActive;
  final double rating;
  final int totalOrders;
  final int totalReviews;
  final GeoPoint? location;
  final String? address;
  final List<String> specialties; // e.g., ["North Indian", "Chinese"]
  final DateTime createdAt;
  final DateTime? updatedAt;

  CookModel({
    required this.cookId,
    required this.name,
    required this.email,
    this.phone,
    this.profileImage,
    this.bio,
    this.isVerified = false,
    this.isActive = true,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalReviews = 0,
    this.location,
    this.address,
    this.specialties = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert Firestore document to CookModel
  factory CookModel.fromMap(Map<String, dynamic> map, String cookId) {
    return CookModel(
      cookId: cookId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      profileImage: map['profileImage'],
      bio: map['bio'],
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      totalReviews: map['totalReviews'] ?? 0,
      location: map['location'],
      address: map['address'],
      specialties: List<String>.from(map['specialties'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert CookModel to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'bio': bio,
      'isVerified': isVerified,
      'isActive': isActive,
      'rating': rating,
      'totalOrders': totalOrders,
      'totalReviews': totalReviews,
      'location': location,
      'address': address,
      'specialties': specialties,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Calculate distance from customer location (in km)
  double? distanceFrom(GeoPoint customerLocation) {
    if (location == null) return null;
    
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // km
    final lat1 = customerLocation.latitude * (3.14159 / 180);
    final lat2 = location!.latitude * (3.14159 / 180);
    final dLat = (location!.latitude - customerLocation.latitude) * (3.14159 / 180);
    final dLon = (location!.longitude - customerLocation.longitude) * (3.14159 / 180);
    
    final a = (dLat / 2) * (dLat / 2) +
              lat1 * lat2 * (dLon / 2) * (dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
}

/// 🍽️ DISH MODEL
/// Represents food item in cook's menu
class DishModel {
  final String dishId;
  final String cookId;
  final String name;
  final String description;
  final double price;
  final String? image;
  final String category; // e.g., "Breakfast", "Lunch", "Dinner", "Snacks"
  final bool isAvailable;
  final bool isVeg;
  final int preparationTimeMinutes;
  final List<String> tags; // e.g., ["Spicy", "Healthy", "Popular"]
  final DateTime createdAt;
  final DateTime? updatedAt;

  DishModel({
    required this.dishId,
    required this.cookId,
    required this.name,
    required this.description,
    required this.price,
    this.image,
    this.category = 'Main Course',
    this.isAvailable = true,
    this.isVeg = true,
    this.preparationTimeMinutes = 30,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert Firestore document to DishModel
  factory DishModel.fromMap(Map<String, dynamic> map, String dishId) {
    return DishModel(
      dishId: dishId,
      cookId: map['cookId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      image: map['image'],
      category: map['category'] ?? 'Main Course',
      isAvailable: map['isAvailable'] ?? true,
      isVeg: map['isVeg'] ?? true,
      preparationTimeMinutes: map['preparationTimeMinutes'] ?? 30,
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert DishModel to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'cookId': cookId,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'category': category,
      'isAvailable': isAvailable,
      'isVeg': isVeg,
      'preparationTimeMinutes': preparationTimeMinutes,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// 🛒 CART ITEM MODEL
/// Temporary cart item before order placement
class CartItemModel {
  final DishModel dish;
  int quantity;

  CartItemModel({
    required this.dish,
    this.quantity = 1,
  });

  double get totalPrice => dish.price * quantity;
}

/// 📊 FIRESTORE COLLECTIONS SCHEMA
/// 
/// cooks/
///   {cookId}/
///     - name, email, phone
///     - profileImage, bio
///     - isVerified, isActive
///     - rating, totalOrders, totalReviews
///     - location (GeoPoint)
///     - address
///     - specialties []
///     - createdAt, updatedAt
/// 
/// dishes/
///   {dishId}/
///     - cookId
///     - name, description, price
///     - image
///     - category
///     - isAvailable, isVeg
///     - preparationTimeMinutes
///     - tags []
///     - createdAt, updatedAt
