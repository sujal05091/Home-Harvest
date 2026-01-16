import 'package:cloud_firestore/cloud_firestore.dart';

class DishModel {
  final String dishId;
  final String cookId;
  final String cookName;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> allergens;
  final double price;
  final String imageUrl;
  final int availableSlots;
  final GeoPoint location;
  final String address;
  final double hygieneScore;
  final double rating;
  final int totalRatings;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  DishModel({
    required this.dishId,
    required this.cookId,
    required this.cookName,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.allergens,
    required this.price,
    required this.imageUrl,
    required this.availableSlots,
    required this.location,
    required this.address,
    this.hygieneScore = 0.0,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DishModel.fromMap(Map<String, dynamic> map, String dishId) {
    return DishModel(
      dishId: dishId,
      cookId: map['cookId'] ?? '',
      cookName: map['cookName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      ingredients: List<String>.from(map['ingredients'] ?? []),
      allergens: List<String>.from(map['allergens'] ?? []),
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      availableSlots: map['availableSlots'] ?? 0,
      location: map['location'] ?? const GeoPoint(0, 0),
      address: map['address'] ?? '',
      hygieneScore: (map['hygieneScore'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cookId': cookId,
      'cookName': cookName,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'allergens': allergens,
      'price': price,
      'imageUrl': imageUrl,
      'availableSlots': availableSlots,
      'location': location,
      'address': address,
      'hygieneScore': hygieneScore,
      'rating': rating,
      'totalRatings': totalRatings,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DishModel copyWith({
    int? availableSlots,
    bool? isAvailable,
    double? rating,
    int? totalRatings,
  }) {
    return DishModel(
      dishId: dishId,
      cookId: cookId,
      cookName: cookName,
      title: title,
      description: description,
      ingredients: ingredients,
      allergens: allergens,
      price: price,
      imageUrl: imageUrl,
      availableSlots: availableSlots ?? this.availableSlots,
      location: location,
      address: address,
      hygieneScore: hygieneScore,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
