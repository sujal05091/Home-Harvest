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
  final List<String> images; // URLs of kitchen, ID, sample dish photos
  final String description;
  final Map<String, bool> hygieneChecklist;
  final VerificationStatus status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  VerificationModel({
    required this.verificationId,
    required this.cookId,
    required this.cookName,
    required this.cookEmail,
    required this.cookPhone,
    required this.images,
    required this.description,
    required this.hygieneChecklist,
    required this.status,
    this.adminNotes,
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
      images: List<String>.from(map['images'] ?? []),
      description: map['description'] ?? '',
      hygieneChecklist: Map<String, bool>.from(map['hygieneChecklist'] ?? {}),
      status: VerificationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VerificationStatus.PENDING,
      ),
      adminNotes: map['adminNotes'],
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
      'images': images,
      'description': description,
      'hygieneChecklist': hygieneChecklist,
      'status': status.name,
      'adminNotes': adminNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  VerificationModel copyWith({
    VerificationStatus? status,
    String? adminNotes,
    DateTime? reviewedAt,
  }) {
    return VerificationModel(
      verificationId: verificationId,
      cookId: cookId,
      cookName: cookName,
      cookEmail: cookEmail,
      cookPhone: cookPhone,
      images: images,
      description: description,
      hygieneChecklist: hygieneChecklist,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
