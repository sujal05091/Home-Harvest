import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:lottie/lottie.dart';
import '../../theme.dart';
import '../../app_router.dart';

class VerificationScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  final String? role;

  const VerificationScreen({
    super.key,
    this.email,
    this.phone,
    this.role,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  String get _displayContact {
    if (widget.email != null && widget.email!.isNotEmpty) {
      // Mask email: d***@email.com
      final parts = widget.email!.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final masked = username.length > 2
            ? '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}'
            : username;
        return '$masked@${parts[1]}';
      }
      return widget.email!;
    } else if (widget.phone != null && widget.phone!.isNotEmpty) {
      // Mask phone: +1 *** *** **34
      final phone = widget.phone!;
      if (phone.length > 4) {
        return '${phone.substring(0, 2)}${'*' * (phone.length - 4)}${phone.substring(phone.length - 2)}';
      }
      return phone;
    }
    return 'demo@email.com';
  }

  Future<void> _verifyCode() async {
    if (_pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter complete verification code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO: Implement actual verification logic
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    if (mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Lottie Animation
            Lottie.asset(
              'assets/lottie/order_placed.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              repeat: false,
            ),
            
            const SizedBox(height: 24),

            // Title
            Text(
              'Verification Successful',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Your account has been verified successfully',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Navigate based on role
                  if (widget.role == 'cook') {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRouter.verificationStatus,
                    );
                  } else if (widget.role == 'customer') {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRouter.customerHome,
                    );
                  } else if (widget.role == 'rider') {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRouter.riderHome,
                    );
                  } else {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRouter.roleSelect,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _resendCode() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification code sent!'),
        backgroundColor: AppTheme.primaryOrange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Back Button and Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: AppTheme.textPrimary,
                  ),
                  Text(
                    'Verification',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the row
                ],
              ),

              const SizedBox(height: 40),

              // Lottie Animation
              Center(
                child: Lottie.asset(
                  'assets/lottie/loading_auth.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'Verification Code',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                'We have sent a verification code to your email / phone',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // Masked Contact
              Text(
                _displayContact,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 40),

              // PIN Code Input
              PinCodeTextField(
                appContext: context,
                length: 4,
                controller: _pinController,
                focusNode: _pinFocusNode,
                obscureText: false,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(16),
                  fieldHeight: 70,
                  fieldWidth: 60,
                  borderWidth: 1,
                  activeColor: AppTheme.primaryOrange,
                  inactiveColor: AppTheme.dividerColor,
                  selectedColor: AppTheme.primaryOrange,
                  activeFillColor: Colors.white,
                  inactiveFillColor: AppTheme.lightGrey,
                  selectedFillColor: AppTheme.lightGrey,
                ),
                cursorColor: AppTheme.primaryOrange,
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                keyboardType: TextInputType.number,
                textStyle: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                onCompleted: (v) {
                  _verifyCode();
                },
                onChanged: (value) {},
                beforeTextPaste: (text) {
                  return true;
                },
              ),

              const SizedBox(height: 40),

              // Verify Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor:
                        AppTheme.primaryOrange.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend Code
              InkWell(
                onTap: _resendCode,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Didn\'t receive the code? ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        'Resend',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
