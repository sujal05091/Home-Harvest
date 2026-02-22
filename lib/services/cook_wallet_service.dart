import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cook_wallet_model.dart';

/// Cook Wallet Service - Real Money Management (₹)
class CookWalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String WALLETS_COLLECTION = 'cook_wallets';
  static const String TRANSACTIONS_COLLECTION = 'cook_wallet_transactions';
  static const String WITHDRAWALS_COLLECTION = 'cook_withdrawal_requests';

  // Withdrawal limits
  static const double MIN_WITHDRAWAL_AMOUNT = 500.0;  // ₹500 minimum
  static const double MAX_WITHDRAWAL_AMOUNT = 100000.0; // ₹1,00,000 maximum

  /// Get cook's wallet
  Future<CookWalletModel?> getCookWallet(String cookId) async {
    try {
      final doc = await _firestore.collection(WALLETS_COLLECTION).doc(cookId).get();

      if (!doc.exists) {
        // Create initial wallet for new cook
        final initialWallet = CookWalletModel.initial(cookId);
        await _firestore.collection(WALLETS_COLLECTION).doc(cookId).set(initialWallet.toMap());
        return initialWallet;
      }

      return CookWalletModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting cook wallet: $e');
      return null;
    }
  }

  /// Stream cook's wallet (real-time updates)
  Stream<CookWalletModel?> streamCookWallet(String cookId) {
    return _firestore
        .collection(WALLETS_COLLECTION)
        .doc(cookId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return CookWalletModel.fromFirestore(doc);
        });
  }

  /// Credit money to cook wallet (on order delivery)
  /// Returns transaction ID if successful
  Future<String?> creditWallet({
    required String cookId,
    required double amount,
    required String orderId,
    required String description,
  }) async {
    if (amount <= 0) {
      print('❌ Invalid credit amount: $amount');
      return null;
    }

    try {
      // Get current wallet
      final walletDoc = await _firestore.collection(WALLETS_COLLECTION).doc(cookId).get();
      
      CookWalletModel wallet;
      if (!walletDoc.exists) {
        wallet = CookWalletModel.initial(cookId);
      } else {
        wallet = CookWalletModel.fromFirestore(walletDoc);
      }

      final balanceBefore = wallet.walletBalance;
      final balanceAfter = balanceBefore + amount;

      // Check if it's today's date
      final now = DateTime.now();
      final lastUpdated = wallet.lastUpdated;
      final isToday = now.year == lastUpdated.year &&
          now.month == lastUpdated.month &&
          now.day == lastUpdated.day;

      final newTodayEarnings = isToday ? wallet.todayEarnings + amount : amount;
      final newTotalEarnings = wallet.totalEarnings + amount;

      // Create transaction record
      final transactionRef = _firestore.collection(TRANSACTIONS_COLLECTION).doc();
      final transaction = CookWalletTransactionModel(
        transactionId: transactionRef.id,
        cookId: cookId,
        type: CookTransactionType.CREDIT,
        amount: amount,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        orderId: orderId,
        description: description,
        createdAt: DateTime.now(),
      );

      // Update wallet and create transaction atomically
      await _firestore.runTransaction((txn) async {
        txn.set(
          _firestore.collection(WALLETS_COLLECTION).doc(cookId),
          {
            'walletBalance': balanceAfter,
            'todayEarnings': newTodayEarnings,
            'totalEarnings': newTotalEarnings,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        txn.set(transactionRef, transaction.toMap());
      });

      print('✅ Credited ₹$amount to cook $cookId. New balance: ₹$balanceAfter');
      return transactionRef.id;
    } catch (e) {
      print('❌ Error crediting wallet: $e');
      return null;
    }
  }

  /// Debit money from cook wallet (on withdrawal approval)
  Future<String?> debitWallet({
    required String cookId,
    required double amount,
    required String withdrawalId,
    required String description,
  }) async {
    if (amount <= 0) {
      print('❌ Invalid debit amount: $amount');
      return null;
    }

    try {
      // Get current wallet
      final walletDoc = await _firestore.collection(WALLETS_COLLECTION).doc(cookId).get();
      
      if (!walletDoc.exists) {
        print('❌ Wallet not found for cook: $cookId');
        return null;
      }

      final wallet = CookWalletModel.fromFirestore(walletDoc);
      final balanceBefore = wallet.walletBalance;

      // Check sufficient balance
      if (balanceBefore < amount) {
        print('❌ Insufficient balance. Available: ₹$balanceBefore, Requested: ₹$amount');
        return null;
      }

      final balanceAfter = balanceBefore - amount;

      // Create transaction record
      final transactionRef = _firestore.collection(TRANSACTIONS_COLLECTION).doc();
      final transaction = CookWalletTransactionModel(
        transactionId: transactionRef.id,
        cookId: cookId,
        type: CookTransactionType.DEBIT,
        amount: amount,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        withdrawalId: withdrawalId,
        description: description,
        createdAt: DateTime.now(),
      );

      // Update wallet and create transaction atomically
      await _firestore.runTransaction((txn) async {
        txn.update(
          _firestore.collection(WALLETS_COLLECTION).doc(cookId),
          {
            'walletBalance': balanceAfter,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        );

        txn.set(transactionRef, transaction.toMap());
      });

      print('✅ Debited ₹$amount from cook $cookId. New balance: ₹$balanceAfter');
      return transactionRef.id;
    } catch (e) {
      print('❌ Error debiting wallet: $e');
      return null;
    }
  }

  /// Get transaction history for cook
  Stream<List<CookWalletTransactionModel>> streamTransactions(String cookId) {
    return _firestore
        .collection(TRANSACTIONS_COLLECTION)
        .where('cookId', isEqualTo: cookId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CookWalletTransactionModel.fromMap(
                  doc.data(),
                  doc.id,
                ))
            .toList());
  }

  /// Create withdrawal request
  Future<String?> createWithdrawalRequest({
    required String cookId,
    required double amount,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
  }) async {
    try {
      // Validate amount
      if (amount < MIN_WITHDRAWAL_AMOUNT) {
        print('❌ Amount below minimum: ₹$amount');
        return null;
      }

      if (amount > MAX_WITHDRAWAL_AMOUNT) {
        print('❌ Amount above maximum: ₹$amount');
        return null;
      }

      // Check wallet balance
      final wallet = await getCookWallet(cookId);
      if (wallet == null || wallet.walletBalance < amount) {
        print('❌ Insufficient balance for withdrawal');
        return null;
      }

      // Create withdrawal request
      final withdrawalRef = _firestore.collection(WITHDRAWALS_COLLECTION).doc();
      final withdrawal = CookWithdrawalRequestModel(
        withdrawalId: withdrawalRef.id,
        cookId: cookId,
        amount: amount,
        status: CookWithdrawalStatus.PENDING,
        bankName: bankName,
        accountNumber: accountNumber,
        ifscCode: ifscCode,
        upiId: upiId,
        requestedAt: DateTime.now(),
      );

      await withdrawalRef.set(withdrawal.toMap());

      print('✅ Withdrawal request created: ${withdrawalRef.id}');
      return withdrawalRef.id;
    } catch (e) {
      print('❌ Error creating withdrawal request: $e');
      return null;
    }
  }

  /// Get withdrawal requests for cook
  Stream<List<CookWithdrawalRequestModel>> streamWithdrawalRequests(String cookId) {
    return _firestore
        .collection(WITHDRAWALS_COLLECTION)
        .where('cookId', isEqualTo: cookId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CookWithdrawalRequestModel.fromMap(
                  doc.data(),
                  doc.id,
                ))
            .toList());
  }
}
