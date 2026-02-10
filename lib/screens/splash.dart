import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadCurrentUser();

    if (!mounted) return;

    // Check if user has seen onboarding
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (authProvider.isAuthenticated) {
      // User is logged in, navigate based on role
      switch (authProvider.currentUser?.role) {
        case 'customer':
          Navigator.of(context).pushReplacementNamed(AppRouter.customerHome);
          break;
        case 'cook':
          Navigator.of(context).pushReplacementNamed(AppRouter.cookDashboardModern); // 🎨 NEW MODERN UI
          break;
        case 'rider':
          Navigator.of(context).pushReplacementNamed(AppRouter.riderHomeModern); // 🎨 NEW MODERN UI
          break;
        default:
          Navigator.of(context).pushReplacementNamed(AppRouter.onboarding);
      }
    } else {
      // User is not logged in
      if (hasSeenOnboarding) {
        // Show role selection if already seen onboarding
        Navigator.of(context).pushReplacementNamed(AppRouter.roleSelect);
      } else {
        // Show onboarding for first time users
        Navigator.of(context).pushReplacementNamed(AppRouter.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/logo_animation.json',
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.6,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
