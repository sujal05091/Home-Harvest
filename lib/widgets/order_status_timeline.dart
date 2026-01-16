import 'package:flutter/material.dart';

/// Order status timeline widget for tracking screen
class OrderStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final DateTime? placedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    this.placedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: step['completed']
                            ? const Color(0xFFFC8019)
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: step['completed']
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: step['completed']
                            ? const Color(0xFFFC8019)
                            : Colors.grey[300],
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Step details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: step['completed']
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: step['completed']
                              ? Colors.black87
                              : Colors.grey[600],
                        ),
                      ),
                      if (step['time'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(step['time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (!isLast) const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSteps() {
    return [
      {
        'title': 'Order Placed',
        'completed': true,
        'time': placedAt,
      },
      {
        'title': 'Order Accepted by Cook',
        'completed': ['ACCEPTED', 'ASSIGNED', 'PICKED_UP', 'ON_THE_WAY', 'DELIVERED']
            .contains(currentStatus),
        'time': acceptedAt,
      },
      {
        'title': 'Preparing Your Food',
        'completed': ['ASSIGNED', 'PICKED_UP', 'ON_THE_WAY', 'DELIVERED']
            .contains(currentStatus),
        'time': null,
      },
      {
        'title': 'Out for Delivery',
        'completed': ['PICKED_UP', 'ON_THE_WAY', 'DELIVERED']
            .contains(currentStatus),
        'time': pickedUpAt,
      },
      {
        'title': 'Delivered',
        'completed': currentStatus == 'DELIVERED',
        'time': deliveredAt,
      },
    ];
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
