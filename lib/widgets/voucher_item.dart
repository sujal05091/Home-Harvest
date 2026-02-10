import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:badges/badges.dart' as badges;

/// Voucher/Coupon Item Card Widget
class VoucherItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String highlightText;
  final int availableCount;
  final VoidCallback? onGetDiscount;
  final bool isUsed;

  const VoucherItem({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.description,
    this.highlightText = '',
    this.availableCount = 0,
    this.onGetDiscount,
    this.isUsed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 169,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFC8019).withOpacity(0.3),
                        const Color(0xFFFC8019).withOpacity(0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.discount,
                      size: 60,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title and description
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFC8019),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Description with highlighted text
                      Padding(
                        padding: const EdgeInsets.only(right: 100),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                            children: _buildDescriptionSpans(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Get Discount button
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: isUsed ? null : onGetDiscount,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          isUsed ? 'Used' : 'Get Discount',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Gift icon with badge (top right)
            if (availableCount > 0)
              Positioned(
                top: 16,
                right: 16,
                child: badges.Badge(
                  badgeContent: Text(
                    availableCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  showBadge: true,
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: Colors.green,
                    elevation: 3,
                    padding: const EdgeInsets.all(8),
                  ),
                  position: badges.BadgePosition.topEnd(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ),
              ),

            // Used overlay
            if (isUsed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'USED',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildDescriptionSpans() {
    if (highlightText.isEmpty) {
      return [
        TextSpan(text: description),
      ];
    }

    // Split description by highlight text
    final parts = description.split(highlightText);
    final spans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      // Add regular text
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }

      // Add highlighted text (except after last part)
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: highlightText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFC8019),
            ),
          ),
        );
      }
    }

    return spans;
  }
}
