import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationStatus {
  PENDING,
  APPROVED,
  REJECTED
}

class VerificationModel {
  final String verificationId;
  final String cookId;
  final String cookName;
  final String cookEmail;
  final String cookPhone;
  
  // Enhanced verification fields
  final String? kitchenName;
  final String? kitchenAddress;
  final List<String> kitchenImages; // Multiple kitchen photos
  final String? kitchenVideoUrl; // Video URL (max 60 seconds)
  final List<String> ingredientsUsed; // List of ingredients
  final String cookingType; // "Veg" / "Non-Veg" / "Both"
  final int experienceYears;
  final List<String> specialityDishes;
  final String? fssaiNumber; // Optional FSSAI certificate
  
  // Legacy fields (kept for backward compatibility)
  final List<String> images; // Deprecated: use kitchenImages instead
  final String description;
  final Map<String, bool> hygieneChecklist;
  
  // Status fields
  final VerificationStatus status;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  VerificationModel({
    required this.verificationId,
    required this.cookId,
    required this.cookName,
    required this.cookEmail,
    required this.cookPhone,
    
    // Enhanced fields
    this.kitchenName,
    this.kitchenAddress,
    this.kitchenImages = const [],
    this.kitchenVideoUrl,
    this.ingredientsUsed = const [],
    this.cookingType = 'Both',
    this.experienceYears = 0,
    this.specialityDishes = const [],
    this.fssaiNumber,
    
    // Legacy fields
    this.images = const [],
    this.description = '',
    this.hygieneChecklist = const {},
    
    // Status
    required this.status,
    this.adminNotes,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
  });

  factory VerificationModel.fromMap(Map<String, dynamic> map, String verificationId) {
    return VerificationModel(
      verificationId: verificationId,
      cookId: map['cookId'] ?? '',
      cookName: map['cookName'] ?? '',
      cookEmail: map['cookEmail'] ?? '',
      cookPhone: map['cookPhone'] ?? '',
      
      // Enhanced fields
      kitchenName: map['kitchenName'],
      kitchenAddress: map['kitchenAddress'],
      kitchenImages: List<String>.from(map['kitchenImages'] ?? []),
      kitchenVideoUrl: map['kitchenVideoUrl'],
      ingredientsUsed: List<String>.from(map['ingredientsUsed'] ?? []),
      cookingType: map['cookingType'] ?? 'Both',
      experienceYears: map['experienceYears'] ?? 0,
      specialityDishes: List<String>.from(map['specialityDishes'] ?? []),
      fssaiNumber: map['fssaiNumber'],
      
      // Legacy fields
      images: List<String>.from(map['images'] ?? []),
      description: map['description'] ?? '',
      hygieneChecklist: Map<String, bool>.from(map['hygieneChecklist'] ?? {}),
      
      // Status
      status: VerificationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VerificationStatus.PENDING,
      ),
      adminNotes: map['adminNotes'],
      rejectionReason: map['rejectionReason'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cookId': cookId,
      'cookName': cookName,
      'cookEmail': cookEmail,
      'cookPhone': cookPhone,
      
      // Enhanced fields
      'kitchenName': kitchenName,
      'kitchenAddress': kitchenAddress,
      'kitchenImages': kitchenImages,
      'kitchenVideoUrl': kitchenVideoUrl,
      'ingredientsUsed': ingredientsUsed,
      'cookingType': cookingType,
      'experienceYears': experienceYears,
      'specialityDishes': specialityDishes,
      'fssaiNumber': fssaiNumber,
      
      // Legacy fields
      'images': images,
      'description': description,
      'hygieneChecklist': hygieneChecklist,
      
      // Status
      'status': status.name,
      'adminNotes': adminNotes,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  VerificationModel copyWith({
    VerificationStatus? status,
    String? adminNotes,
    String? rejectionReason,
    DateTime? reviewedAt,
  }) {
    return VerificationModel(
      verificationId: verificationId,
      cookId: cookId,
      cookName: cookName,
      cookEmail: cookEmail,
      cookPhone: cookPhone,
      
      // Enhanced fields
      kitchenName: kitchenName,
      kitchenAddress: kitchenAddress,
      kitchenImages: kitchenImages,
      kitchenVideoUrl: kitchenVideoUrl,
      ingredientsUsed: ingredientsUsed,
      cookingType: cookingType,
      experienceYears: experienceYears,
      specialityDishes: specialityDishes,
      fssaiNumber: fssaiNumber,
      
      // Legacy fields
      images: images,
      description: description,
      hygieneChecklist: hygieneChecklist,
      
      // Status
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🫙 PRODUCT SELLER VERIFICATION MODEL
// Firestore collection: product_verifications
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ProductVerificationModel {
  final String verificationId;
  final String sellerId;
  final String sellerName;
  final String sellerEmail;
  final String sellerPhone;

  // Workplace details
  final String workplaceName;
  final String workplaceAddress;
  final List<String> workplaceImages;
  final String? workplaceVideoUrl;

  // Product details
  final List<String> specialProducts; // What they sell e.g. pickles, masala
  final List<String> ingredientsUsed; // Main ingredients used
  final int experienceYears;          // Years of experience
  final String? fssaiNumber;          // FSSAI certification number

  // Status
  final VerificationStatus status;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  ProductVerificationModel({
    required this.verificationId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerEmail,
    required this.sellerPhone,
    required this.workplaceName,
    required this.workplaceAddress,
    this.workplaceImages = const [],
    this.workplaceVideoUrl,
    this.specialProducts = const [],
    this.ingredientsUsed = const [],
    this.experienceYears = 0,
    this.fssaiNumber,
    required this.status,
    this.adminNotes,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
  });

  factory ProductVerificationModel.fromMap(
      Map<String, dynamic> map, String id) {
    return ProductVerificationModel(
      verificationId: id,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerEmail: map['sellerEmail'] ?? '',
      sellerPhone: map['sellerPhone'] ?? '',
      workplaceName: map['workplaceName'] ?? '',
      workplaceAddress: map['workplaceAddress'] ?? '',
      workplaceImages: List<String>.from(map['workplaceImages'] ?? []),
      workplaceVideoUrl: map['workplaceVideoUrl'],
      specialProducts: List<String>.from(map['specialProducts'] ?? []),
      ingredientsUsed: List<String>.from(map['ingredientsUsed'] ?? []),
      experienceYears: map['experienceYears'] ?? 0,
      fssaiNumber: map['fssaiNumber'],
      status: VerificationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VerificationStatus.PENDING,
      ),
      adminNotes: map['adminNotes'],
      rejectionReason: map['rejectionReason'],
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerEmail': sellerEmail,
      'sellerPhone': sellerPhone,
      'workplaceName': workplaceName,
      'workplaceAddress': workplaceAddress,
      'workplaceImages': workplaceImages,
      'workplaceVideoUrl': workplaceVideoUrl,
      'specialProducts': specialProducts,
      'ingredientsUsed': ingredientsUsed,
      'experienceYears': experienceYears,
      'fssaiNumber': fssaiNumber,
      'status': status.name,
      'adminNotes': adminNotes,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt':
          reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  ProductVerificationModel copyWith({
    VerificationStatus? status,
    String? adminNotes,
    String? rejectionReason,
    DateTime? reviewedAt,
  }) {
    return ProductVerificationModel(
      verificationId: verificationId,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerEmail: sellerEmail,
      sellerPhone: sellerPhone,
      workplaceName: workplaceName,
      workplaceAddress: workplaceAddress,
      workplaceImages: workplaceImages,
      workplaceVideoUrl: workplaceVideoUrl,
      specialProducts: specialProducts,
      ingredientsUsed: ingredientsUsed,
      experienceYears: experienceYears,
      fssaiNumber: fssaiNumber,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
