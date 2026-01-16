import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String orderId;
  final String dishId;
  final String cookId;
  final String customerId;
  final String customerName;
  final double rating; // 1.0 to 5.0
  final String comment;
  final List<String> images;
  final DateTime createdAt;
  final String? cookReply;
  final DateTime? repliedAt;

  ReviewModel({
    required this.reviewId,
    required this.orderId,
    required this.dishId,
    required this.cookId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    this.images = const [],
    required this.createdAt,
    this.cookReply,
    this.repliedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reviewId': reviewId,
      'orderId': orderId,
      'dishId': dishId,
      'cookId': cookId,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'cookReply': cookReply,
      'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      reviewId: map['reviewId'] ?? '',
      orderId: map['orderId'] ?? '',
      dishId: map['dishId'] ?? '',
      cookId: map['cookId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cookReply: map['cookReply'],
      repliedAt: (map['repliedAt'] as Timestamp?)?.toDate(),
    );
  }

  ReviewModel copyWith({
    String? reviewId,
    String? orderId,
    String? dishId,
    String? cookId,
    String? customerId,
    String? customerName,
    double? rating,
    String? comment,
    List<String>? images,
    DateTime? createdAt,
    String? cookReply,
    DateTime? repliedAt,
  }) {
    return ReviewModel(
      reviewId: reviewId ?? this.reviewId,
      orderId: orderId ?? this.orderId,
      dishId: dishId ?? this.dishId,
      cookId: cookId ?? this.cookId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      cookReply: cookReply ?? this.cookReply,
      repliedAt: repliedAt ?? this.repliedAt,
    );
  }
}
