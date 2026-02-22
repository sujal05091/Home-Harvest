import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart' as smooth_page_indicator;
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_router.dart';
import '../../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('hasSeenOnboarding', true);
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
                      }
                    },
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: const [
                  _OnboardingPage(
                    imageGradient: LinearGradient(
                      colors: [Color(0xFFFF6E40), Color(0xFFFF9E80)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      
                    ),
                    icon: Icons.restaurant_menu,
                    title: 'Healthy Home-Cooked Food',
                    subtitle: 'Fresh, low-oil meals made by trusted home cooks',
                    imagePath: 'assets/images/onboarding_1.png',
                    
                    
                  ),
                  _OnboardingPage(
                    imageGradient: LinearGradient(
                      colors: [Color(0xFF00BCD4), Color(0xFF80DEEA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.card_travel,
                    title: 'Home to Office Tiffin',
                    subtitle: 'Get food from your home delivered to your workplace',
                    imagePath: 'assets/images/onboarding_2.jpg',
                  ),
                  _OnboardingPage(
                    imageGradient: LinearGradient(
                      colors: [Color(0xFF48C479), Color(0xFF7ED957)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.location_on,
                    title: 'Live Delivery Tracking',
                    subtitle: 'Track your delivery partner in real time',
                    imagePath: 'assets/images/onboarding_3.png',
                  ),
                ],
              ),
            ),

            // Page Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: smooth_page_indicator.SmoothPageIndicator(
                controller: _pageController,
                count: 3,
                effect: smooth_page_indicator.SlideEffect(
                  spacing: 8,
                  radius: 100,
                  dotWidth: 8,
                  dotHeight: 8,
                  dotColor: AppTheme.lightGrey,
                  activeDotColor: AppTheme.primaryOrange,
                  paintStyle: PaintingStyle.fill,
                ),
                onDotClicked: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Create Account Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hasSeenOnboarding', true);
                        if (context.mounted) {
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
                        'Create Account',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Already have an account button
                  InkWell(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('hasSeenOnboarding', true);
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRouter.login,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        'Already Have an Account',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final Gradient imageGradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? imagePath; // Optional image path

  const _OnboardingPage({
    required this.imageGradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image Card with Gradient
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: imageGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: imageGradient.colors.first.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      imagePath!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image not found
                        return Center(
                          child: Icon(
                            icon,
                            size: 120,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      icon,
                      size: 120,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
