import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction Type for Cook Wallet
enum CookTransactionType {
  CREDIT,  // Money added to wallet (order earnings)
  DEBIT,   // Money deducted from wallet (withdrawal)
}

/// Withdrawal Status for Cook
enum CookWithdrawalStatus {
  PENDING,    // Request submitted
  APPROVED,   // Admin approved
  PAID,       // Money transferred
  REJECTED,   // Request rejected
}

/// Cook Wallet Model - Real Money System (₹)
class CookWalletModel {
  final String cookId;
  final double walletBalance;      // Current balance in ₹
  final double todayEarnings;      // Today's earnings in ₹
  final double totalEarnings;      // Lifetime earnings in ₹
  final DateTime lastUpdated;

  CookWalletModel({
    required this.cookId,
    required this.walletBalance,
    required this.todayEarnings,
    required this.totalEarnings,
    required this.lastUpdated,
  });

  factory CookWalletModel.fromMap(Map<String, dynamic> map, String cookId) {
    return CookWalletModel(
      cookId: cookId,
      walletBalance: (map['walletBalance'] ?? 0).toDouble(),
      todayEarnings: (map['todayEarnings'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory CookWalletModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CookWalletModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'walletBalance': walletBalance,
      'todayEarnings': todayEarnings,
      'totalEarnings': totalEarnings,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Create initial wallet for new cook
  factory CookWalletModel.initial(String cookId) {
    return CookWalletModel(
      cookId: cookId,
      walletBalance: 0.0,
      todayEarnings: 0.0,
      totalEarnings: 0.0,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Cook Wallet Transaction Model
class CookWalletTransactionModel {
  final String transactionId;
  final String cookId;
  final CookTransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? orderId;            // Link to order (for food earnings)
  final String? withdrawalId;       // Link to withdrawal request
  final String description;
  final DateTime createdAt;

  CookWalletTransactionModel({
    required this.transactionId,
    required this.cookId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.withdrawalId,
    required this.description,
    required this.createdAt,
  });

  factory CookWalletTransactionModel.fromMap(Map<String, dynamic> map, String transactionId) {
    return CookWalletTransactionModel(
      transactionId: transactionId,
      cookId: map['cookId'] ?? '',
      type: CookTransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CookTransactionType.CREDIT,
      ),
      amount: (map['amount'] ?? 0).toDouble(),
      balanceBefore: (map['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
      orderId: map['orderId'],
      withdrawalId: map['withdrawalId'],
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cookId': cookId,
      'type': type.name,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      if (orderId != null) 'orderId': orderId,
      if (withdrawalId != null) 'withdrawalId': withdrawalId,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Cook Withdrawal Request Model
class CookWithdrawalRequestModel {
  final String withdrawalId;
  final String cookId;
  final double amount;
  final CookWithdrawalStatus status;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? adminNote;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? processedAt;

  CookWithdrawalRequestModel({
    required this.withdrawalId,
    required this.cookId,
    required this.amount,
    required this.status,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.adminNote,
    this.rejectionReason,
    required this.requestedAt,
    this.processedAt,
  });

  factory CookWithdrawalRequestModel.fromMap(Map<String, dynamic> map, String withdrawalId) {
    return CookWithdrawalRequestModel(
      withdrawalId: withdrawalId,
      cookId: map['cookId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: CookWithdrawalStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CookWithdrawalStatus.PENDING,
      ),
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      ifscCode: map['ifscCode'],
      upiId: map['upiId'],
      adminNote: map['adminNote'],
      rejectionReason: map['rejectionReason'],
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cookId': cookId,
      'amount': amount,
      'status': status.name,
      if (bankName != null) 'bankName': bankName,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (ifscCode != null) 'ifscCode': ifscCode,
      if (upiId != null) 'upiId': upiId,
      if (adminNote != null) 'adminNote': adminNote,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'requestedAt': Timestamp.fromDate(requestedAt),
      if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
    };
  }
}
