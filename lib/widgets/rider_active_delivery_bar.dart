import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_model.dart';
import '../app_router.dart';

/// 🚚 Rider Active Delivery Summary Bar
/// 
/// Shows at the bottom of rider screen when there's an active delivery.
/// Displays: Delivery status + "Continue Delivery" action
/// 
/// Features:
/// - Animated slide-up appearance
/// - Sticky positioning at bottom
/// - Auto-hide when no active delivery
/// - Smooth transitions
/// - Orange gradient styling
class RiderActiveDeliveryBar extends StatefulWidget {
  final OrderModel? activeOrder;

  const RiderActiveDeliveryBar({
    super.key,
    this.activeOrder,
  });

  @override
  State<RiderActiveDeliveryBar> createState() => _RiderActiveDeliveryBarState();
}

class _RiderActiveDeliveryBarState extends State<RiderActiveDeliveryBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Slide animation (from bottom)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // Start below screen
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // Trigger animation if there's an active order
    if (widget.activeOrder != null) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(RiderActiveDeliveryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate in/out based on active order presence
    if (widget.activeOrder != null && oldWidget.activeOrder == null) {
      _controller.forward();
    } else if (widget.activeOrder == null && oldWidget.activeOrder != null) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.RIDER_ACCEPTED:
        return 'Heading to pickup location';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'On the way to pickup';
      case OrderStatus.PICKED_UP:
        return 'Order picked up - delivering now';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'On the way to customer';
      case OrderStatus.RIDER_ASSIGNED:
        return 'New delivery assigned';
      default:
        return 'Active delivery';
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
      case OrderStatus.RIDER_ACCEPTED:
        return Icons.restaurant;
      case OrderStatus.PICKED_UP:
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Icons.delivery_dining;
      default:
        return Icons.local_shipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeOrder == null) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRouter.riderActiveDelivery,
                  arguments: {'order': widget.activeOrder!},
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Status Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(widget.activeOrder!.status),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    
                    const SizedBox(width: 14),
                    
                    // Status Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getStatusText(widget.activeOrder!.status),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order #${widget.activeOrder!.orderId.substring(0, 8)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action Button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Continue',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF6B35),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFFFF6B35),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
