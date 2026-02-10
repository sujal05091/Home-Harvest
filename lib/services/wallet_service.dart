import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rider_wallet_model.dart';

/// Rider Wallet Service - Real Money Management (₹)
class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String WALLETS_COLLECTION = 'rider_wallets';
  static const String TRANSACTIONS_COLLECTION = 'wallet_transactions';
  static const String WITHDRAWALS_COLLECTION = 'withdrawal_requests';

  // Withdrawal limits
  static const double MIN_WITHDRAWAL_AMOUNT = 100.0;  // ₹100 minimum
  static const double MAX_WITHDRAWAL_AMOUNT = 50000.0; // ₹50,000 maximum

  /// Get rider's wallet
  Future<RiderWalletModel?> getRiderWallet(String riderId) async {
    try {
      final doc = await _firestore.collection(WALLETS_COLLECTION).doc(riderId).get();
      
      if (!doc.exists) {
        // Create initial wallet for new rider
        final initialWallet = RiderWalletModel.initial(riderId);
        await _firestore.collection(WALLETS_COLLECTION).doc(riderId).set(initialWallet.toMap());
        return initialWallet;
      }

      return RiderWalletModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting rider wallet: $e');
      return null;
    }
  }

  /// Stream rider's wallet (real-time updates)
  Stream<RiderWalletModel?> streamRiderWallet(String riderId) {
    return _firestore
        .collection(WALLETS_COLLECTION)
        .doc(riderId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return RiderWalletModel.fromFirestore(doc);
        });
  }

  /// Credit money to rider wallet (on delivery completion)
  /// Returns transaction ID if successful
  Future<String?> creditWallet({
    required String riderId,
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
      final walletDoc = await _firestore.collection(WALLETS_COLLECTION).doc(riderId).get();
      
      RiderWalletModel wallet;
      if (!walletDoc.exists) {
        wallet = RiderWalletModel.initial(riderId);
      } else {
        wallet = RiderWalletModel.fromFirestore(walletDoc);
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
      final transaction = WalletTransactionModel(
        transactionId: transactionRef.id,
        riderId: riderId,
        type: TransactionType.CREDIT,
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
          _firestore.collection(WALLETS_COLLECTION).doc(riderId),
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

      print('✅ Credited ₹$amount to rider $riderId. New balance: ₹$balanceAfter');
      return transactionRef.id;
    } catch (e) {
      print('❌ Error crediting wallet: $e');
      return null;
    }
  }

  /// Debit money from rider wallet (on withdrawal approval)
  Future<String?> debitWallet({
    required String riderId,
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
      final walletDoc = await _firestore.collection(WALLETS_COLLECTION).doc(riderId).get();
      
      if (!walletDoc.exists) {
        print('❌ Wallet not found for rider: $riderId');
        return null;
      }

      final wallet = RiderWalletModel.fromFirestore(walletDoc);
      final balanceBefore = wallet.walletBalance;

      // Check sufficient balance
      if (balanceBefore < amount) {
        print('❌ Insufficient balance. Available: ₹$balanceBefore, Requested: ₹$amount');
        return null;
      }

      final balanceAfter = balanceBefore - amount;

      // Create transaction record
      final transactionRef = _firestore.collection(TRANSACTIONS_COLLECTION).doc();
      final transaction = WalletTransactionModel(
        transactionId: transactionRef.id,
        riderId: riderId,
        type: TransactionType.DEBIT,
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
          _firestore.collection(WALLETS_COLLECTION).doc(riderId),
          {
            'walletBalance': balanceAfter,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        );

        txn.set(transactionRef, transaction.toMap());
      });

      print('✅ Debited ₹$amount from rider $riderId. New balance: ₹$balanceAfter');
      return transactionRef.id;
    } catch (e) {
      print('❌ Error debiting wallet: $e');
      return null;
    }
  }

  /// Get transaction history for rider
  Stream<List<WalletTransactionModel>> streamTransactions(String riderId) {
    return _firestore
        .collection(TRANSACTIONS_COLLECTION)
        .where('riderId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransactionModel.fromFirestore(doc))
            .toList());
  }

  /// Create withdrawal request
  Future<String?> createWithdrawalRequest({
    required String riderId,
    required String riderName,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
  }) async {
    try {
      // Validate amount
      if (amount < MIN_WITHDRAWAL_AMOUNT) {
        print('❌ Minimum withdrawal amount is ₹$MIN_WITHDRAWAL_AMOUNT');
        return null;
      }

      if (amount > MAX_WITHDRAWAL_AMOUNT) {
        print('❌ Maximum withdrawal amount is ₹$MAX_WITHDRAWAL_AMOUNT');
        return null;
      }

      // Check wallet balance
      final wallet = await getRiderWallet(riderId);
      if (wallet == null || wallet.walletBalance < amount) {
        print('❌ Insufficient balance for withdrawal');
        return null;
      }

      // Create withdrawal request
      final requestRef = _firestore.collection(WITHDRAWALS_COLLECTION).doc();
      final request = WithdrawalRequestModel(
        requestId: requestRef.id,
        riderId: riderId,
        riderName: riderName,
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        ifscCode: ifscCode,
        upiId: upiId,
        status: WithdrawalStatus.PENDING,
        createdAt: DateTime.now(),
      );

      await requestRef.set(request.toMap());

      print('✅ Withdrawal request created: ₹$amount');
      return requestRef.id;
    } catch (e) {
      print('❌ Error creating withdrawal request: $e');
      return null;
    }
  }

  /// Get withdrawal requests for rider
  Stream<List<WithdrawalRequestModel>> streamWithdrawalRequests(String riderId) {
    return _firestore
        .collection(WITHDRAWALS_COLLECTION)
        .where('riderId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WithdrawalRequestModel.fromFirestore(doc))
            .toList());
  }

  /// Reset today's earnings (called at midnight by Cloud Function)
  Future<void> resetTodayEarnings(String riderId) async {
    try {
      await _firestore.collection(WALLETS_COLLECTION).doc(riderId).update({
        'todayEarnings': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('✅ Reset today\'s earnings for rider: $riderId');
    } catch (e) {
      print('❌ Error resetting today\'s earnings: $e');
    }
  }

  /// Check if rider can accept new orders (COD settlement check)
  Future<bool> canAcceptNewOrders(String riderId) async {
    try {
      // Get pending settlements
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('assignedRiderId', isEqualTo: riderId)
          .where('paymentMethod', isEqualTo: 'COD')
          .where('isSettled', isEqualTo: false)
          .get();

      double totalPendingSettlement = 0.0;
      for (var doc in ordersSnapshot.docs) {
        final pendingSettlement = (doc.data()['pendingSettlement'] as num?)?.toDouble() ?? 0.0;
        totalPendingSettlement += pendingSettlement;
      }

      // Limit: ₹500 pending settlement
      const MAX_PENDING_SETTLEMENT = 500.0;
      
      if (totalPendingSettlement > MAX_PENDING_SETTLEMENT) {
        print('⚠️ Rider has pending settlement: ₹$totalPendingSettlement');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking rider availability: $e');
      return false;
    }
  }
}
