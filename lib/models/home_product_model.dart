import 'package:cloud_firestore/cloud_firestore.dart';

class HomeProductModel {
  final String productId;
  final String sellerId;
  final String sellerName;
  final String name;
  final String category;
  final double price;
  final String description;
  final String ingredients;
  final String workplace;
  final String imageUrl;
  final bool verifiedSeller;
  final int stock;
  final bool isAvailable;
  final double rating;
  final int totalRatings;
  final DateTime createdAt;

  HomeProductModel({
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    required this.ingredients,
    required this.workplace,
    required this.imageUrl,
    this.verifiedSeller = false,
    this.stock = 0,
    this.isAvailable = true,
    this.rating = 0.0,
    this.totalRatings = 0,
    required this.createdAt,
  });

  factory HomeProductModel.fromMap(Map<String, dynamic> map, String id) {
    return HomeProductModel(
      productId: id,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      ingredients: map['ingredients'] ?? '',
      workplace: map['workplace'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      verifiedSeller: map['verifiedSeller'] ?? false,
      stock: map['stock'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
      rating: (map['rating'] ?? 0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'name': name,
      'category': category,
      'price': price,
      'description': description,
      'ingredients': ingredients,
      'workplace': workplace,
      'imageUrl': imageUrl,
      'verifiedSeller': verifiedSeller,
      'stock': stock,
      'isAvailable': isAvailable,
      'rating': rating,
      'totalRatings': totalRatings,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  HomeProductModel copyWith({
    String? name,
    String? category,
    double? price,
    String? description,
    String? ingredients,
    String? workplace,
    String? imageUrl,
    int? stock,
    bool? isAvailable,
  }) {
    return HomeProductModel(
      productId: productId,
      sellerId: sellerId,
      sellerName: sellerName,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      workplace: workplace ?? this.workplace,
      imageUrl: imageUrl ?? this.imageUrl,
      verifiedSeller: verifiedSeller,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating,
      totalRatings: totalRatings,
      createdAt: createdAt,
    );
  }
}

/// Lightweight seller summary aggregated from their products
class HomeSellerSummary {
  final String sellerId;
  final String sellerName;
  final bool verifiedSeller;
  final double avgRating;
  final int productCount;

  HomeSellerSummary({
    required this.sellerId,
    required this.sellerName,
    required this.verifiedSeller,
    required this.avgRating,
    required this.productCount,
  });
}
