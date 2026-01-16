import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
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

    if (authProvider.isAuthenticated) {
      // Navigate based on role
      switch (authProvider.currentUser?.role) {
        case 'customer':
          Navigator.of(context).pushReplacementNamed(AppRouter.customerHome);
          break;
        case 'cook':
          Navigator.of(context).pushReplacementNamed(AppRouter.cookDashboard);
          break;
        case 'rider':
          Navigator.of(context).pushReplacementNamed(AppRouter.riderHome);
          break;
        default:
          Navigator.of(context).pushReplacementNamed(AppRouter.roleSelect);
      }
    } else {
      Navigator.of(context).pushReplacementNamed(AppRouter.roleSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6), // Light orange/peach background to match logo
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/logo_app.json',
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.5,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            Lottie.asset(
              'assets/lottie/loading_auth.json',
              width: 100,
              height: 100,
            ),
          ],
        ),
      ),
    );
  }
}
