import 'package:cloud_firestore/cloud_firestore.dart';

// ──────────────────────────────────────────────────────────────────────────
// Seller Withdrawal Status
// ──────────────────────────────────────────────────────────────────────────
enum SellerWithdrawalStatus {
  PENDING,   // Request submitted, awaiting admin action
  APPROVED,  // Admin approved, payment processing
  PAID,      // Money transferred to seller
  REJECTED,  // Request rejected by admin
}

// ──────────────────────────────────────────────────────────────────────────
// Seller Withdrawal Request Model
// ──────────────────────────────────────────────────────────────────────────
class SellerWithdrawalRequest {
  final String id;
  final String sellerId;
  final double amount;
  final SellerWithdrawalStatus status;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? adminNote;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const SellerWithdrawalRequest({
    required this.id,
    required this.sellerId,
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

  factory SellerWithdrawalRequest.fromMap(
      Map<String, dynamic> map, String id) {
    return SellerWithdrawalRequest(
      id: id,
      sellerId: map['sellerId'] as String? ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: SellerWithdrawalStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SellerWithdrawalStatus.PENDING,
      ),
      bankName: map['bankName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      ifscCode: map['ifscCode'] as String?,
      upiId: map['upiId'] as String?,
      adminNote: map['adminNote'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      requestedAt:
          (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
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

// ──────────────────────────────────────────────────────────────────────────
// Seller Wallet Service
// ──────────────────────────────────────────────────────────────────────────
class SellerWalletService {
  final _db = FirebaseFirestore.instance;

  static const String _collection = 'seller_withdrawal_requests';

  /// Minimum amount a seller can withdraw in ₹
  static const double MIN_WITHDRAWAL = 100.0;

  /// Maximum amount a seller can withdraw in a single request
  static const double MAX_WITHDRAWAL = 100000.0;

  // ── Streams ───────────────────────────────────────────────────────────

  /// Real-time stream of all withdrawal requests for a seller
  Stream<List<SellerWithdrawalRequest>> streamWithdrawals(String sellerId) {
    return _db
        .collection(_collection)
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => SellerWithdrawalRequest.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  // ── Write operations ──────────────────────────────────────────────────

  /// Submit a new withdrawal request.
  ///
  /// [availableBalance] is the pre-computed balance the caller has already
  /// validated (totalEarnings - sum of non-rejected withdrawals).
  ///
  /// Returns the new document ID on success, null on failure.
  Future<String?> createWithdrawal({
    required String sellerId,
    required double amount,
    required double availableBalance,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
  }) async {
    if (amount < MIN_WITHDRAWAL || amount > MAX_WITHDRAWAL) {
      print('❌ [SellerWallet] Amount out of range: ₹$amount');
      return null;
    }
    if (amount > availableBalance) {
      print('❌ [SellerWallet] Insufficient balance: ₹$availableBalance < ₹$amount');
      return null;
    }

    try {
      final ref = _db.collection(_collection).doc();
      final req = SellerWithdrawalRequest(
        id: ref.id,
        sellerId: sellerId,
        amount: amount,
        status: SellerWithdrawalStatus.PENDING,
        bankName: bankName,
        accountNumber: accountNumber,
        ifscCode: ifscCode,
        upiId: upiId,
        requestedAt: DateTime.now(),
      );
      await ref.set(req.toMap());
      print('✅ [SellerWallet] Withdrawal request created: ${ref.id}');
      return ref.id;
    } catch (e) {
      print('❌ [SellerWallet] Error creating withdrawal: $e');
      return null;
    }
  }
}
