import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../services/seller_wallet_service.dart';

/// Full-featured withdrawal screen for sellers.
///
/// Balance = total earnings from DELIVERED orders
///         - sum of non-rejected (PENDING / APPROVED / PAID) withdrawal amounts.
class SellerWithdrawScreen extends StatefulWidget {
  const SellerWithdrawScreen({super.key});

  @override
  State<SellerWithdrawScreen> createState() => _SellerWithdrawScreenState();
}

class _SellerWithdrawScreenState extends State<SellerWithdrawScreen> {
  // -- Services ------------------------------------------------------------
  final _service = SellerWalletService();

  // -- Subscriptions --------------------------------------------------------
  StreamSubscription<List<OrderModel>>? _ordersSub;
  StreamSubscription<List<SellerWithdrawalRequest>>? _withdrawalSub;

  // -- Live state -----------------------------------------------------------
  double _totalEarnings = 0;
  double _lockedInRequests = 0; // sum of PENDING + APPROVED + PAID requests
  List<SellerWithdrawalRequest> _withdrawals = [];
  bool _loading = true;

  // -- Form -----------------------------------------------------------------
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  int _paymentMethod = 0; // 0 = Bank Transfer, 1 = UPI
  bool _isSubmitting = false;

  // -- Computed -------------------------------------------------------------
  double get _availableBalance =>
      (_totalEarnings - _lockedInRequests).clamp(0.0, double.infinity);

  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
      _listen(uid);
    });
  }

  void _listen(String uid) {
    // Orders stream ? compute total earnings
    _ordersSub =
        FirestoreService().getSellerOrderHistory(uid).listen((orders) {
      if (!mounted) return;
      double e = 0;
      for (final o in orders) {
        if (o.status == OrderStatus.DELIVERED) {
          e += o.total - o.deliveryCharge;
        }
      }
      setState(() {
        _totalEarnings = e;
        _loading = false;
      });
    }, onError: (_) => setState(() => _loading = false));

    // Withdrawals stream ? compute locked amount
    _withdrawalSub = _service.streamWithdrawals(uid).listen((ws) {
      if (!mounted) return;
      double locked = 0;
      for (final w in ws) {
        if (w.status != SellerWithdrawalStatus.REJECTED) {
          locked += w.amount;
        }
      }
      setState(() {
        _withdrawals = ws;
        _lockedInRequests = locked;
      });
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _withdrawalSub?.cancel();
    _amountCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  // -- Submit withdrawal ----------------------------------------------------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (amount < SellerWalletService.MIN_WITHDRAWAL) {
      _snack('Minimum withdrawal is ₹${SellerWalletService.MIN_WITHDRAWAL.toInt()}',
          isError: true);
      return;
    }
    if (amount > SellerWalletService.MAX_WITHDRAWAL) {
      _snack('Maximum withdrawal is ₹${SellerWalletService.MAX_WITHDRAWAL.toInt()}',
          isError: true);
      return;
    }
    if (amount > _availableBalance) {
      _snack('Insufficient balance. Available: ₹${_availableBalance.toStringAsFixed(2)}',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;

    try {
      String? id;
      if (_paymentMethod == 0) {
        id = await _service.createWithdrawal(
          sellerId: uid,
          amount: amount,
          availableBalance: _availableBalance,
          bankName: _bankNameCtrl.text.trim(),
          accountNumber: _accountCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        );
      } else {
        id = await _service.createWithdrawal(
          sellerId: uid,
          amount: amount,
          availableBalance: _availableBalance,
          upiId: _upiCtrl.text.trim(),
        );
      }

      if (id != null) {
        _snack('? Withdrawal request submitted successfully!');
        _formKey.currentState!.reset();
        _amountCtrl.clear();
        _bankNameCtrl.clear();
        _accountCtrl.clear();
        _ifscCtrl.clear();
        _upiCtrl.clear();
      } else {
        _snack('Failed to submit request. Please try again.', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green[700],
    ));
  }

  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Withdraw Earnings',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFC8019),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFC8019)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 24),
                  _buildWithdrawalForm(),
                  const SizedBox(height: 24),
                  _buildHistory(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // -- Balance card ---------------------------------------------------------
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFC8019), Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFC8019).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('Available Balance',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            '₹${_availableBalance.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _balanceStat('Total Earned', _totalEarnings),
              Container(
                  width: 1, height: 32, color: Colors.white24),
              _balanceStat('Withdrawn / Pending', _lockedInRequests),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceStat(String label, double value) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text('₹${value.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // -- Withdrawal form -------------------------------------------------------
  Widget _buildWithdrawalForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request Withdrawal',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Min ₹${SellerWalletService.MIN_WITHDRAWAL.toInt()}  �  '
              'Max ₹${SellerWalletService.MAX_WITHDRAWAL.toInt()}',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 18),

            // Amount field
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount (?)',
                prefixText: '₹ ',
                hintText: 'Enter amount',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Withdrawal Limits'),
                      content: Text(
                        'Min: ₹${SellerWalletService.MIN_WITHDRAWAL.toInt()}\n'
                        'Max: ₹${SellerWalletService.MAX_WITHDRAWAL.toInt()}\n'
                        'Available: ₹${_availableBalance.toStringAsFixed(2)}',
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'))
                      ],
                    ),
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter amount';
                final a = double.tryParse(v);
                if (a == null) return 'Invalid amount';
                if (a < SellerWalletService.MIN_WITHDRAWAL) {
                  return 'Minimum ₹${SellerWalletService.MIN_WITHDRAWAL.toInt()}';
                }
                if (a > _availableBalance) return 'Insufficient balance';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Payment method toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _methodTab(0, Icons.account_balance, 'Bank Transfer'),
                  _methodTab(1, Icons.payment, 'UPI'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment-method-specific fields
            if (_paymentMethod == 0) ...[
              _textField(
                controller: _bankNameCtrl,
                label: 'Bank Name',
                icon: Icons.account_balance,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter bank name' : null,
              ),
              const SizedBox(height: 14),
              _textField(
                controller: _accountCtrl,
                label: 'Account Number',
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter account number';
                  if (v.length < 9 || v.length > 18) {
                    return 'Invalid account number (9-18 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _textField(
                controller: _ifscCtrl,
                label: 'IFSC Code',
                icon: Icons.code,
                capitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter IFSC code';
                  if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                      .hasMatch(v.toUpperCase())) {
                    return 'Invalid IFSC code';
                  }
                  return null;
                },
              ),
            ] else ...[
              _textField(
                controller: _upiCtrl,
                label: 'UPI ID',
                icon: Icons.payment,
                hint: 'example@upi',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter UPI ID';
                  if (!v.contains('@')) return 'Invalid UPI ID format';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting || _availableBalance < SellerWalletService.MIN_WITHDRAWAL
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC8019),
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _availableBalance < SellerWalletService.MIN_WITHDRAWAL
                            ? 'Insufficient Balance'
                            : 'Submit Withdrawal Request',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTab(int index, IconData icon, String label) {
    final selected = _paymentMethod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFC8019) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.grey,
                  size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: selected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }

  // -- Withdrawal history ----------------------------------------------------
  Widget _buildHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Withdrawal History',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (_withdrawals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No withdrawal requests yet',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _withdrawals.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 20),
              itemBuilder: (_, i) =>
                  _buildHistoryItem(_withdrawals[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(SellerWithdrawalRequest req) {
    late Color color;
    late IconData icon;
    late String statusLabel;

    switch (req.status) {
      case SellerWithdrawalStatus.PENDING:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        statusLabel = 'Pending';
        break;
      case SellerWithdrawalStatus.APPROVED:
        color = Colors.blue;
        icon = Icons.check_circle_outline;
        statusLabel = 'Approved';
        break;
      case SellerWithdrawalStatus.PAID:
        color = Colors.green;
        icon = Icons.check_circle;
        statusLabel = 'Paid';
        break;
      case SellerWithdrawalStatus.REJECTED:
        color = Colors.red;
        icon = Icons.cancel;
        statusLabel = 'Rejected';
        break;
    }

    final method = req.upiId != null
        ? 'UPI: ${req.upiId}'
        : req.bankName != null
            ? '${req.bankName} ���${req.accountNumber?.substring(req.accountNumber!.length > 4 ? req.accountNumber!.length - 4 : 0)}'
            : 'Unknown';

    final dateStr = _fmt(req.requestedAt);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${req.amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(method,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(dateStr,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[400])),
              if (req.rejectionReason != null &&
                  req.status == SellerWithdrawalStatus.REJECTED)
                Text(
                  'Reason: ${req.rejectionReason}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.red[400]),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(statusLabel,
              style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
