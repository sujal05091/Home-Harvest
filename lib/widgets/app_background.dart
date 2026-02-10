import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showImage;

  const AppBackground({
    super.key,
    required this.child,
    this.showImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showImage) {
      return child;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE8D6), // Light orange
            Color(0xFFFFF9F0), // White center
            Color(0xFFE8F5E9), // Light green
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/app-background.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: child,
      ),
    );
  }
}

// Alternative version with just gradient (if image file doesn't exist)
class AppBackgroundGradient extends StatelessWidget {
  final Widget child;

  const AppBackgroundGradient({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFB347), // Orange
            Color(0xFFFFFBF0), // Light cream center
            Color(0xFF90EE90), // Light green
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
