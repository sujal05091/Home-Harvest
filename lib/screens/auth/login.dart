import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../app_router.dart';
import '../../services/fcm_service.dart';
import '../../theme.dart';
import '../../widgets/forgot_password_modal.dart';

class LoginScreen extends StatefulWidget {
  final String? role;

  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: widget.role,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      // 🔔 Save FCM token for riders immediately after login
      if (authProvider.currentUser?.role == 'rider') {
        try {
          await FCMService().saveFCMToken();
          print('✅ FCM token saved for rider after login');
        } catch (e) {
          print('⚠️ Failed to save FCM token: $e');
        }
      }
      
      // Navigate based on role
      switch (authProvider.currentUser?.role) {
        case 'customer':
          Navigator.pushReplacementNamed(context, AppRouter.customerHome);
          break;
        case 'cook':
          Navigator.pushReplacementNamed(context, AppRouter.cookDashboardModern);
          break;
        case 'rider':
          Navigator.pushReplacementNamed(context, AppRouter.riderHome);
          break;
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Use the role from widget parameter or default to 'customer'
    final role = widget.role ?? 'customer';
    
    bool success = await authProvider.signInWithGoogle(role: role);

    setState(() => _isLoading = false);

    if (success && mounted) {
      // 🔔 Save FCM token for riders immediately after login
      if (authProvider.currentUser?.role == 'rider') {
        try {
          await FCMService().saveFCMToken();
          print('✅ FCM token saved for rider after Google login');
        } catch (e) {
          print('⚠️ Failed to save FCM token: $e');
        }
      }
      
      // Navigate based on role
      switch (authProvider.currentUser?.role) {
        case 'customer':
          Navigator.pushReplacementNamed(context, AppRouter.customerHome);
          break;
        case 'cook':
          Navigator.pushReplacementNamed(context, AppRouter.cookDashboardModern);
          break;
        case 'rider':
          Navigator.pushReplacementNamed(context, AppRouter.riderHome);
          break;
      }
    } else if (mounted && authProvider.errorMessage != null) {
      // Show detailed error dialog for configuration issues
      if (authProvider.errorMessage!.contains('not configured') || 
          authProvider.errorMessage!.contains('ApiException: 10')) {
        _showGoogleSignInErrorDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Google Sign In failed'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showGoogleSignInErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Google Sign-In Setup Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Google Sign-In needs to be configured in Firebase Console.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Quick Steps:', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('1. Run: cd android && ./gradlew signingReport'),
            Text('2. Copy SHA-1 fingerprint'),
            Text('3. Add to Firebase Console'),
            Text('4. Download new google-services.json'),
            Text('5. Restart app'),
            SizedBox(height: 12),
            Text(
              'For now, please use Email/Password login instead.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got It'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Could open GOOGLE_SIGNIN_SETUP.md or a help link
            },
            child: Text('View Full Guide', style: TextStyle(color: AppTheme.primaryOrange)),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordModal() {
    ForgotPasswordModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                // Lottie Animation (role-based)
                Center(
                  child: widget.role == 'cook'
                      ? Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Lottie.asset(
                            'assets/lottie/cook_signup.json',
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Lottie.asset(
                          widget.role == 'rider'
                              ? 'assets/lottie/rider_signup.json'
                              : 'assets/lottie/customer_signup.json',
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Login Account',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Please login with registered account',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Email / Phone Field Label
                Text(
                  'Email or Phone Number',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                // Email / Phone Input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email or phone number',
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppTheme.lightGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.primaryOrange,
                        width: 1,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: _emailController.text.isEmpty
                          ? AppTheme.textSecondary
                          : AppTheme.primaryOrange,
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter email or phone' : null,
                  onChanged: (value) => setState(() {}),
                ),

                const SizedBox(height: 20),

                // Password Field Label
                Text(
                  'Password',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                // Password Input
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppTheme.lightGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.primaryOrange,
                        width: 1,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outlined,
                      color: _passwordController.text.isEmpty
                          ? AppTheme.textSecondary
                          : AppTheme.primaryOrange,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter password' : null,
                  onChanged: (value) => setState(() {}),
                ),

                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordModal,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign In Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                        ? Lottie.asset(
                            'assets/lottie/loading_auth.json',
                            width: 40,
                            height: 40,
                          )
                        : Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or continue with',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.dividerColor)),
                  ],
                ),

                const SizedBox(height: 24),

                // Google Sign In Button
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const FaIcon(
                      FontAwesomeIcons.google,
                      size: 20,
                      color: AppTheme.primaryOrange,
                    ),
                    label: Text(
                      'Sign In with Google',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Facebook Sign In Button
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Facebook Sign In coming soon!')),
                            );
                          },
                    icon: const FaIcon(
                      FontAwesomeIcons.facebook,
                      size: 20,
                      color: Color(0xFF1877F2),
                    ),
                    label: Text(
                      'Sign In with Facebook',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Sign Up Link
                InkWell(
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRouter.signup,
                    arguments: {'role': widget.role},
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          'Sign Up',
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

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
