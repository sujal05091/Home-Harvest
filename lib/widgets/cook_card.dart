import 'package:flutter/material.dart';

class CookCard extends StatelessWidget {
  final String cookName;
  final bool isVerified;
  final double? rating;
  final int? totalOrders;
  final VoidCallback onTap;

  const CookCard({
    super.key,
    required this.cookName,
    required this.isVerified,
    this.rating,
    this.totalOrders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                child: Text(
                  cookName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cookName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isVerified)
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('$rating'),
                        ],
                      ),
                    if (totalOrders != null)
                      Text(
                        '$totalOrders orders completed',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
