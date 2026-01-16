import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../models/cook_model.dart';
import 'cook_detail_screen.dart';

/// 👨‍🍳 BROWSE HOME COOKS SCREEN
/// Shows list of verified home cooks for normal food ordering
class BrowseCooksScreen extends StatefulWidget {
  final GeoPoint? customerLocation;

  const BrowseCooksScreen({
    super.key,
    this.customerLocation,
  });

  @override
  State<BrowseCooksScreen> createState() => _BrowseCooksScreenState();
}

class _BrowseCooksScreenState extends State<BrowseCooksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Cooks Near You'),
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cooks')
            .where('isVerified', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final cooks = snapshot.data!.docs
              .map((doc) => CookModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();

          // Sort by distance if customer location available
          if (widget.customerLocation != null) {
            cooks.sort((a, b) {
              final distA = a.distanceFrom(widget.customerLocation!) ?? double.infinity;
              final distB = b.distanceFrom(widget.customerLocation!) ?? double.infinity;
              return distA.compareTo(distB);
            });
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cooks.length,
            itemBuilder: (context, index) {
              return _buildCookCard(cooks[index]);
            },
          );
        },
      ),
    );
  }

  /// Build cook card widget
  Widget _buildCookCard(CookModel cook) {
    final distance = widget.customerLocation != null
        ? cook.distanceFrom(widget.customerLocation!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CookDetailScreen(cook: cook),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cook Profile Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: cook.profileImage != null
                    ? CachedNetworkImage(
                        imageUrl: cook.profileImage!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildDefaultAvatar(cook.name),
                      )
                    : _buildDefaultAvatar(cook.name),
              ),
              
              const SizedBox(width: 16),
              
              // Cook Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Verification Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cook.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cook.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.green, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Rating + Total Orders
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: cook.rating,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${cook.rating.toStringAsFixed(1)} (${cook.totalReviews})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Specialties
                    if (cook.specialties.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: cook.specialties.take(3).map((specialty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              specialty,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFF7A00),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Distance + Total Orders
                    Row(
                      children: [
                        if (distance != null) ...[
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km away',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        const Icon(Icons.shopping_bag, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${cook.totalOrders}+ orders',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// Build default avatar with first letter
  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A00),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Home Cooks Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for delicious home-cooked meals!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
