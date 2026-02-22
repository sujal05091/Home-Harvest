import 'package:cloud_firestore/cloud_firestore.dart';
import 'dish_model.dart';

/// Model to represent a Cook Section with their dishes
/// Used for grouping dishes by cook in the Home Screen
class CookSectionModel {
  final String cookId;
  final String cookName;
  final String? cookPhotoUrl;
  final String? cookAddress;
  final GeoPoint? cookLocation;
  final bool isVerified;
  final double rating; // Average rating of cook's dishes
  final int totalDishes; // Total available dishes
  final List<DishModel> dishes; // Cook's available dishes
  
  // Calculated fields
  final double? distanceInKm; // Distance from user (optional)
  final int? estimatedTimeMinutes; // Estimated delivery time (optional)

  CookSectionModel({
    required this.cookId,
    required this.cookName,
    this.cookPhotoUrl,
    this.cookAddress,
    this.cookLocation,
    required this.isVerified,
    required this.rating,
    required this.totalDishes,
    required this.dishes,
    this.distanceInKm,
    this.estimatedTimeMinutes,
  });

  /// Calculate average rating from cook's dishes
  static double calculateAverageRating(List<DishModel> dishes) {
    if (dishes.isEmpty) return 0.0;
    final sum = dishes.fold<double>(0.0, (sum, dish) => sum + dish.rating);
    return sum / dishes.length;
  }

  /// Copy with method
  CookSectionModel copyWith({
    String? cookId,
    String? cookName,
    String? cookPhotoUrl,
    String? cookAddress,
    GeoPoint? cookLocation,
    bool? isVerified,
    double? rating,
    int? totalDishes,
    List<DishModel>? dishes,
    double? distanceInKm,
    int? estimatedTimeMinutes,
  }) {
    return CookSectionModel(
      cookId: cookId ?? this.cookId,
      cookName: cookName ?? this.cookName,
      cookPhotoUrl: cookPhotoUrl ?? this.cookPhotoUrl,
      cookAddress: cookAddress ?? this.cookAddress,
      cookLocation: cookLocation ?? this.cookLocation,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      totalDishes: totalDishes ?? this.totalDishes,
      dishes: dishes ?? this.dishes,
      distanceInKm: distanceInKm ?? this.distanceInKm,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
    );
  }
}
