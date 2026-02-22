import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_model.dart';
import '../app_router.dart';

/// 🚚 Active Delivery Summary Bar
/// 
/// Shows at the bottom of screen (above cart bar) when there's an active delivery.
/// Displays: Order status + "Track Order" action
/// 
/// Features:
/// - Animated slide-up appearance
/// - Sticky positioning above cart bar
/// - Auto-hide when no active delivery
/// - Smooth transitions
/// - Styled like CartSummaryBar
class ActiveDeliveryBar extends StatefulWidget {
  final OrderModel? activeOrder;

  const ActiveDeliveryBar({
    super.key,
    this.activeOrder,
  });

  @override
  State<ActiveDeliveryBar> createState() => _ActiveDeliveryBarState();
}

class _ActiveDeliveryBarState extends State<ActiveDeliveryBar>
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
  void didUpdateWidget(ActiveDeliveryBar oldWidget) {
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
        return 'Rider heading to pickup';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'Rider heading to pickup';
      case OrderStatus.PICKED_UP:
        return 'Order picked up';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'Rider heading to you';
      case OrderStatus.RIDER_ASSIGNED:
        return 'Rider assigned';
      default:
        return 'Delivery in progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide completely when no active delivery (no space taken)
    if (widget.activeOrder == null) {
      return const SizedBox.shrink();
    }

    final order = widget.activeOrder!;
    final statusText = _getStatusText(order.status);

    // Show animated delivery summary bar
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), // 8px gap above cart bar
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFC8019), // Orange 500
                Color(0xFFEA580C), // Orange 600
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFC8019).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Navigate to PREMIUM tracking screen (the new beautiful UI)
                Navigator.pushNamed(
                  context,
                  AppRouter.premiumTracking,
                  arguments: {'orderId': order.orderId},
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // 🚚 Delivery Icon
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        // Pulsing indicator
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Delivery Status Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🚀 Delivery in Progress',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // "Track Order" Button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Track',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFC8019),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Color(0xFFFC8019),
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
