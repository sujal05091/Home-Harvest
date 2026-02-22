import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cook_wallet_service.dart';
import '../../models/cook_wallet_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';

class CookWithdrawScreen extends StatefulWidget {
  const CookWithdrawScreen({super.key});

  @override
  State<CookWithdrawScreen> createState() => _CookWithdrawScreenState();
}

class _CookWithdrawScreenState extends State<CookWithdrawScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _upiIdController = TextEditingController();
  
  final _cookWalletService = CookWalletService();
  
  // Tab: 0 = Bank Transfer, 1 = UPI
  int _selectedPaymentMethod = 0;
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal(CookWalletModel wallet, String cookId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    final amount = double.parse(_amountController.text.trim());

    // Validate amount
    if (amount < CookWalletService.MIN_WITHDRAWAL_AMOUNT) {
      _showError('Minimum withdrawal amount is ₹${CookWalletService.MIN_WITHDRAWAL_AMOUNT.toInt()}');
      setState(() => _isProcessing = false);
      return;
    }

    if (amount > CookWalletService.MAX_WITHDRAWAL_AMOUNT) {
      _showError('Maximum withdrawal amount is ₹${CookWalletService.MAX_WITHDRAWAL_AMOUNT.toInt()}');
      setState(() => _isProcessing = false);
      return;
    }

    if (amount > wallet.walletBalance) {
      _showError('Insufficient balance. Available: ₹${wallet.walletBalance.toStringAsFixed(2)}');
      setState(() => _isProcessing = false);
      return;
    }

    String? withdrawalId;
    
    try {
      if (_selectedPaymentMethod == 0) {
        // Bank Transfer
        withdrawalId = await _cookWalletService.createWithdrawalRequest(
          cookId: cookId,
          amount: amount,
          bankName: _bankNameController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          ifscCode: _ifscCodeController.text.trim().toUpperCase(),
        );
      } else {
        // UPI
        withdrawalId = await _cookWalletService.createWithdrawalRequest(
          cookId: cookId,
          amount: amount,
          upiId: _upiIdController.text.trim(),
        );
      }

      if (withdrawalId != null) {
        _showSuccess('Withdrawal request submitted successfully!');
        _formKey.currentState!.reset();
        _amountController.clear();
        _bankNameController.clear();
        _accountNumberController.clear();
        _ifscCodeController.clear();
        _upiIdController.clear();
      } else {
        _showError('Failed to create withdrawal request. Please try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cookId = authProvider.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Withdraw Money',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<CookWalletModel?>(
        stream: _cookWalletService.streamCookWallet(cookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final wallet = snapshot.data ?? CookWalletModel.initial(cookId);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Wallet Balance Card
                _buildBalanceCard(wallet),
                
                SizedBox(height: 24),
                
                // Withdrawal Form
                _buildWithdrawalForm(wallet, cookId),
                
                SizedBox(height: 32),
                
                // Withdrawal History
                _buildWithdrawalHistory(cookId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(CookWalletModel wallet) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '₹${wallet.walletBalance.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceStat('Today', wallet.todayEarnings),
              Container(height: 30, width: 1, color: Colors.white24),
              _buildBalanceStat('Total', wallet.totalEarnings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStat(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalForm(CookWalletModel wallet, String cookId) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Withdrawal',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            
            // Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                hintText: 'Enter amount',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Withdrawal Limits'),
                        content: Text(
                          'Min: ₹${CookWalletService.MIN_WITHDRAWAL_AMOUNT.toInt()}\n'
                          'Max: ₹${CookWalletService.MAX_WITHDRAWAL_AMOUNT.toInt()}\n'
                          'Available: ₹${wallet.walletBalance.toStringAsFixed(2)}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value);
                if (amount == null) {
                  return 'Invalid amount';
                }
                if (amount < CookWalletService.MIN_WITHDRAWAL_AMOUNT) {
                  return 'Min ₹${CookWalletService.MIN_WITHDRAWAL_AMOUNT.toInt()}';
                }
                if (amount > wallet.walletBalance) {
                  return 'Insufficient balance';
                }
                return null;
              },
            ),
            
            SizedBox(height: 20),
            
            // Payment Method Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethod = 0),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 0 ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance,
                              color: _selectedPaymentMethod == 0 ? Colors.white : Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Bank Transfer',
                              style: TextStyle(
                                color: _selectedPaymentMethod == 0 ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethod = 1),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 1 ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payment,
                              color: _selectedPaymentMethod == 1 ? Colors.white : Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'UPI',
                              style: TextStyle(
                                color: _selectedPaymentMethod == 1 ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Payment Details Fields
            if (_selectedPaymentMethod == 0) ...[
              // Bank Transfer Fields
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'Bank Name',
                  prefixIcon: Icon(Icons.account_balance),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter bank name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  prefixIcon: Icon(Icons.credit_card),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account number';
                  }
                  if (value.length < 9 || value.length > 18) {
                    return 'Invalid account number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _ifscCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'IFSC Code',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter IFSC code';
                  }
                  if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value.toUpperCase())) {
                    return 'Invalid IFSC code';
                  }
                  return null;
                },
              ),
            ] else ...[
              // UPI Field
              TextFormField(
                controller: _upiIdController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  prefixIcon: Icon(Icons.payment),
                  hintText: 'example@upi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter UPI ID';
                  }
                  if (!value.contains('@')) {
                    return 'Invalid UPI ID';
                  }
                  return null;
                },
              ),
            ],
            
            SizedBox(height: 24),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _submitWithdrawal(wallet, cookId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalHistory(String cookId) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Withdrawal History',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          
          StreamBuilder<List<CookWithdrawalRequestModel>>(
            stream: _cookWalletService.streamWithdrawalRequests(cookId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          'No withdrawal requests yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, __) => Divider(height: 24),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return _buildWithdrawalItem(request);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalItem(CookWithdrawalRequestModel request) {
    Color statusColor;
    IconData statusIcon;
    
    switch (request.status) {
      case CookWithdrawalStatus.PENDING:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case CookWithdrawalStatus.APPROVED:
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case CookWithdrawalStatus.PAID:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case CookWithdrawalStatus.REJECTED:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${request.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                request.upiId ?? '${request.bankName} • ${request.accountNumber?.replaceRange(0, request.accountNumber!.length - 4, '****')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              SizedBox(height: 4),
              Text(
                _formatDate(request.requestedAt),
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              if (request.rejectionReason != null) ...[
                SizedBox(height: 4),
                Text(
                  'Reason: ${request.rejectionReason}',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            request.status.name,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
