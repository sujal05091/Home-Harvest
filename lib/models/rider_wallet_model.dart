import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction Type for Wallet
enum TransactionType {
  CREDIT,  // Money added to wallet (delivery earnings)
  DEBIT,   // Money deducted from wallet (withdrawal)
}

/// Rider Wallet Model - Real Money System (₹)
class RiderWalletModel {
  final String riderId;
  final double walletBalance;      // Current balance in ₹
  final double todayEarnings;      // Today's earnings in ₹
  final double totalEarnings;      // Lifetime earnings in ₹
  final DateTime lastUpdated;

  RiderWalletModel({
    required this.riderId,
    required this.walletBalance,
    required this.todayEarnings,
    required this.totalEarnings,
    required this.lastUpdated,
  });

  factory RiderWalletModel.fromMap(Map<String, dynamic> map, String riderId) {
    return RiderWalletModel(
      riderId: riderId,
      walletBalance: (map['walletBalance'] ?? 0).toDouble(),
      todayEarnings: (map['todayEarnings'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory RiderWalletModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RiderWalletModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'walletBalance': walletBalance,
      'todayEarnings': todayEarnings,
      'totalEarnings': totalEarnings,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Create initial wallet for new rider
  factory RiderWalletModel.initial(String riderId) {
    return RiderWalletModel(
      riderId: riderId,
      walletBalance: 0.0,
      todayEarnings: 0.0,
      totalEarnings: 0.0,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Wallet Transaction Model
class WalletTransactionModel {
  final String transactionId;
  final String riderId;
  final TransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? orderId;            // Link to order (for delivery earnings)
  final String? withdrawalId;       // Link to withdrawal request
  final String description;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.transactionId,
    required this.riderId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.withdrawalId,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map, String transactionId) {
    return WalletTransactionModel(
      transactionId: transactionId,
      riderId: map['riderId'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.CREDIT,
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

  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'type': type.name,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'orderId': orderId,
      'withdrawalId': withdrawalId,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Withdrawal Request Model
enum WithdrawalStatus {
  PENDING,   // Awaiting admin approval
  APPROVED,  // Admin approved, processing transfer
  PAID,      // Money transferred to rider
  REJECTED,  // Admin rejected
}

class WithdrawalRequestModel {
  final String requestId;
  final String riderId;
  final String riderName;
  final double amount;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String? upiId;
  final WithdrawalStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? rejectionReason;
  final String? adminNote;

  WithdrawalRequestModel({
    required this.requestId,
    required this.riderId,
    required this.riderName,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.upiId,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.rejectionReason,
    this.adminNote,
  });

  factory WithdrawalRequestModel.fromMap(Map<String, dynamic> map, String requestId) {
    return WithdrawalRequestModel(
      requestId: requestId,
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
      upiId: map['upiId'],
      status: WithdrawalStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WithdrawalStatus.PENDING,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
      adminNote: map['adminNote'],
    );
  }

  factory WithdrawalRequestModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WithdrawalRequestModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'riderName': riderName,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'rejectionReason': rejectionReason,
      'adminNote': adminNote,
    };
  }
}
