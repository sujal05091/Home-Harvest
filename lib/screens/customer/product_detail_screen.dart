import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/home_product_model.dart';
import '../../providers/orders_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final HomeProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _liked = false;
  int _quantity = 1;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // App background
          Positioned.fill(
            child: Image.asset(
              'assets/images/app-background.png',
              fit: BoxFit.cover,
            ),
          ),
          // White fade overlay
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.72),
            ),
          ),
          // -- Scrollable content ------------------------------------------
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Hero image ------------------------------------------
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  child: SizedBox(
                    height: 340,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Product image
                        p.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: p.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _imageFallback(p),
                                errorWidget: (_, __, ___) =>
                                    _imageFallback(p),
                              )
                            : _imageFallback(p),
                        // Gradient overlay
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0x7F14181B), Color(0x1814181B)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // -- Product name + quantity controller ------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip + name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFC8019).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.category,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFC8019),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'by ${p.sellerName}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Quantity control
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: () {
                                if (_quantity > 1) {
                                  setState(() => _quantity--);
                                }
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$_quantity',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              onTap: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // -- Stats row: rating -----------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _StatChip(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFC8019),
                        label: 'Rating',
                        value: p.rating > 0
                            ? p.rating.toStringAsFixed(1)
                            : 'New',
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.inventory_2_outlined,
                        iconColor: Colors.green,
                        label: 'Stock',
                        value: '${p.stock} left',
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.verified_rounded,
                        iconColor: const Color(0xFF1DA1F2),
                        label: 'Seller',
                        value: p.verifiedSeller ? 'Verified' : 'New',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // -- Description -----------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (p.description.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _expanded = !_expanded),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: _expanded || p.description.length <= 120
                                      ? p.description
                                      : '${p.description.substring(0, 120)}... ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    height: 1.55,
                                  ),
                                ),
                                if (!_expanded && p.description.length > 120)
                                  TextSpan(
                                    text: 'Read More',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: const Color(0xFFFC8019),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          'No description provided.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // -- Ingredients (if available) --------------------------
                if (p.ingredients.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingredients',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p.ingredients,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                // Extra bottom space for the sticky bar
                const SizedBox(height: 100),
              ],
            ),
          ),

          // -- Floating back button + title + heart (over image) ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.black87),
                    ),
                  ),
                  // Title (centered)
                  Expanded(
                    child: Text(
                      'Product Detail',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Heart toggle
                  GestureDetector(
                    onTap: () => setState(() => _liked = !_liked),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: _liked
                            ? Colors.redAccent
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // -- Sticky bottom bar: price + Add to Cart ---------------------
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Price
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '\u20B9 ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFFFC8019),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: (p.price * _quantity).toStringAsFixed(0),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add to Cart button
                  GestureDetector(
                    onTap: () {
                      context.read<OrdersProvider>().addItemToCart(
                            p.productId,
                            p.name,
                            p.price,
                            quantity: _quantity,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$_quantity � ${p.name} added to cart!',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFFFC8019),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFC8019),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFC8019).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback(HomeProductModel p) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C42), Color(0xFFFC6B1A)],
        ),
      ),
      child: Center(
        child: Text(
          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

// -- Small round quantity button -------------------------------------------
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }
}

// -- Stat chip widget ------------------------------------------------------
class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
