import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/order_model.dart';

/// 🎯 ANIMATED ORDER STATUS CARD
/// Swiggy-style status updates with smooth animations
class AnimatedStatusCard extends StatefulWidget {
  final OrderStatus status;
  final String? riderId;
  final String? riderName;
  final int? etaMinutes;
  final VoidCallback? onCallRider;

  const AnimatedStatusCard({
    super.key,
    required this.status,
    this.riderId,
    this.riderName,
    this.etaMinutes,
    this.onCallRider,
  });

  @override
  State<AnimatedStatusCard> createState() => _AnimatedStatusCardState();
}

class _AnimatedStatusCardState extends State<AnimatedStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  StatusConfig _getStatusConfig() {
    switch (widget.status) {
      case OrderStatus.PLACED:
        return StatusConfig(
          title: 'Assigning Delivery Partner',
          subtitle: 'Finding the best rider near you...',
          color: Colors.orange,
          icon: Icons.search,
          lottieAsset: 'assets/lottie/delivery motorbike.json',
          showProgress: true,
        );
      case OrderStatus.RIDER_ASSIGNED:
        return StatusConfig(
          title: 'Rider Found!',
          subtitle: 'Waiting for acceptance...',
          color: Colors.blue,
          icon: Icons.person_search,
          lottieAsset: 'assets/lottie/delivery motorbike.json',
          showProgress: true,
        );
      case OrderStatus.RIDER_ACCEPTED:
        return StatusConfig(
          title: 'Rider Accepted',
          subtitle: widget.riderName ?? 'Rider is on the way',
          color: Colors.green,
          icon: Icons.check_circle,
          lottieAsset: null,
          showProgress: false,
        );
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return StatusConfig(
          title: 'Rider Coming to Pickup',
          subtitle: 'ETA: ${widget.etaMinutes ?? "..."}  mins',
          color: Colors.purple,
          icon: Icons.two_wheeler,
          lottieAsset: 'assets/lottie/delivery motorbike.json',
          showProgress: false,
        );
      case OrderStatus.PICKED_UP:
        return StatusConfig(
          title: 'Order Picked Up!',
          subtitle: 'On the way to delivery',
          color: Colors.teal,
          icon: Icons.shopping_bag,
          lottieAsset: null,
          showProgress: false,
        );
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return StatusConfig(
          title: 'Out for Delivery',
          subtitle: 'ETA: ${widget.etaMinutes ?? "..."}  mins',
          color: const Color(0xFFFC8019),
          icon: Icons.delivery_dining,
          lottieAsset: 'assets/lottie/delivery motorbike.json',
          showProgress: false,
        );
      case OrderStatus.DELIVERED:
        return StatusConfig(
          title: 'Delivered Successfully!',
          subtitle: 'Enjoy your meal 🎉',
          color: Colors.green[700]!,
          icon: Icons.done_all,
          lottieAsset: 'assets/lottie/order_placed.json',
          showProgress: false,
        );
      default:
        return StatusConfig(
          title: 'Processing Order',
          subtitle: 'Please wait...',
          color: Colors.grey,
          icon: Icons.hourglass_empty,
          lottieAsset: null,
          showProgress: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                config.color.withOpacity(0.1),
                config.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: config.color.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: config.color.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon or Lottie
                  if (config.lottieAsset != null)
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Lottie.asset(
                        config.lottieAsset!,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: config.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        config.icon,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: config.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Progress indicator
              if (config.showProgress) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    backgroundColor: config.color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(config.color),
                    minHeight: 6,
                  ),
                ),
              ],
              
              // Call rider button
              if (widget.status.index >= OrderStatus.RIDER_ACCEPTED.index &&
                  widget.status != OrderStatus.DELIVERED &&
                  widget.onCallRider != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onCallRider,
                    icon: const Icon(Icons.phone),
                    label: Text('Call ${widget.riderName ?? "Rider"}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: config.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Status configuration model
class StatusConfig {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String? lottieAsset;
  final bool showProgress;

  StatusConfig({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.lottieAsset,
    required this.showProgress,
  });
}

/// 📊 ORDER TIMELINE WIDGET
/// Visual progress timeline like Swiggy
class OrderTimeline extends StatelessWidget {
  final OrderStatus currentStatus;

  const OrderTimeline({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      TimelineStep(
        title: 'Order Placed',
        status: OrderStatus.PLACED,
        icon: Icons.receipt,
      ),
      TimelineStep(
        title: 'Rider Assigned',
        status: OrderStatus.RIDER_ACCEPTED,
        icon: Icons.person,
      ),
      TimelineStep(
        title: 'Picked Up',
        status: OrderStatus.PICKED_UP,
        icon: Icons.shopping_bag,
      ),
      TimelineStep(
        title: 'On The Way',
        status: OrderStatus.ON_THE_WAY_TO_DROP,
        icon: Icons.two_wheeler,
      ),
      TimelineStep(
        title: 'Delivered',
        status: OrderStatus.DELIVERED,
        icon: Icons.check_circle,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isCompleted = currentStatus.index >= step.status.index;
          final isActive = currentStatus == step.status;

          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFFC8019)
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFC8019).withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    step.icon,
                    color: isCompleted ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? const Color(0xFFFC8019) : Colors.grey,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class TimelineStep {
  final String title;
  final OrderStatus status;
  final IconData icon;

  TimelineStep({
    required this.title,
    required this.status,
    required this.icon,
  });
}
