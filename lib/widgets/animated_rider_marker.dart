import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 🏍️ ANIMATED RIDER MARKER
/// Smoothly animates rider position and rotates based on direction
/// Updates every 2-3 seconds with smooth interpolation
class AnimatedRiderMarker {
  static Marker create({
    required LatLng currentPosition,
    LatLng? targetPosition,
    double bearing = 0,
    required String riderId,
  }) {
    return Marker(
      point: currentPosition,
      width: 80,
      height: 80,
      child: _AnimatedRiderWidget(
        currentPosition: currentPosition,
        targetPosition: targetPosition,
        bearing: bearing,
        riderId: riderId,
      ),
    );
  }
}

class _AnimatedRiderWidget extends StatefulWidget {
  final LatLng currentPosition;
  final LatLng? targetPosition;
  final double bearing;
  final String riderId;

  const _AnimatedRiderWidget({
    required this.currentPosition,
    this.targetPosition,
    this.bearing = 0,
    required this.riderId,
  });

  @override
  State<_AnimatedRiderWidget> createState() => _AnimatedRiderWidgetState();
}

class _AnimatedRiderWidgetState extends State<_AnimatedRiderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  LatLng _displayPosition = const LatLng(0, 0);
  double _displayBearing = 0;
  
  Timer? _interpolationTimer;
  int _interpolationSteps = 0;
  static const int _totalSteps = 30; // 30 frames for smooth animation
  
  LatLng? _lastTargetPosition;

  @override
  void initState() {
    super.initState();
    _displayPosition = widget.currentPosition;
    _displayBearing = widget.bearing;
    
    // Rotation animation for continuous movement effect
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AnimatedRiderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if target position changed
    if (widget.targetPosition != null &&
        widget.targetPosition != _lastTargetPosition) {
      _lastTargetPosition = widget.targetPosition;
      _startInterpolation();
    }
    
    // Update bearing smoothly
    if (widget.bearing != _displayBearing) {
      _animateBearingChange(widget.bearing);
    }
  }

  /// Smooth position interpolation
  void _startInterpolation() {
    if (widget.targetPosition == null) return;
    
    _interpolationTimer?.cancel();
    _interpolationSteps = 0;
    
    final startLat = _displayPosition.latitude;
    final startLng = _displayPosition.longitude;
    final endLat = widget.targetPosition!.latitude;
    final endLng = widget.targetPosition!.longitude;
    
    // Interpolate position over 3 seconds (30 steps * 100ms)
    _interpolationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (_interpolationSteps >= _totalSteps) {
          timer.cancel();
          return;
        }
        
        _interpolationSteps++;
        final progress = _interpolationSteps / _totalSteps;
        
        // Ease-in-out interpolation
        final easedProgress = _easeInOutCubic(progress);
        
        final newLat = startLat + (endLat - startLat) * easedProgress;
        final newLng = startLng + (endLng - startLng) * easedProgress;
        
        if (mounted) {
          setState(() {
            _displayPosition = LatLng(newLat, newLng);
          });
        }
      },
    );
  }

  /// Smooth bearing rotation
  void _animateBearingChange(double newBearing) {
    final oldBearing = _displayBearing;
    
    // Handle 360° wrap-around (choose shortest rotation path)
    double diff = newBearing - oldBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    
    _controller.reset();
    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _displayBearing = newBearing;
        });
      }
    });
  }

  /// Ease-in-out cubic for smooth interpolation
  double _easeInOutCubic(double t) {
    return t < 0.5
        ? 4 * t * t * t
        : 1 - pow(-2 * t + 2, 3) / 2;
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpolationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _displayBearing * pi / 180, // Convert to radians
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Transparent PNG Rider Image - No background
              Image.asset(
                'assets/images/rider_homeharvest.png',
                width: 70,
                height: 70,
                fit: BoxFit.contain,
              ),
              
              // Direction indicator
              Positioned(
                top: 5,
                child: Container(
                  width: 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC8019),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 📍 CUSTOM MARKER HELPERS
class CustomMapMarkers {
  /// Home/Pickup marker
  static Marker createHomeMarker(LatLng position, String label) {
    return Marker(
      point: position,
      width: 60,
      height: 80,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.home, color: Colors.white, size: 24),
          ),
          // Pin tail
          CustomPaint(
            size: const Size(10, 10),
            painter: _PinTailPainter(Colors.green),
          ),
        ],
      ),
    );
  }

  /// Customer/Drop marker
  static Marker createCustomerMarker(LatLng position, String label) {
    return Marker(
      point: position,
      width: 60,
      height: 80,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFC8019),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFC8019),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFC8019).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
          // Pin tail
          CustomPaint(
            size: const Size(10, 10),
            painter: _PinTailPainter(const Color(0xFFFC8019)),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for pin tail
class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
