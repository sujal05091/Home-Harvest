import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/home_products_provider.dart';
import '../../models/home_product_model.dart';
import '../../app_router.dart';

const _kCategories = [
  ('All', Icons.grid_view_rounded),
  ('Pickles', Icons.set_meal_outlined),
  ('Snacks', Icons.fastfood_sharp),
  ('Sweets', Icons.cake_outlined),
  ('Masalas', Icons.local_fire_department_outlined),
  ('Jams', Icons.emoji_food_beverage_outlined),
  ('Beverages', Icons.local_drink_outlined),
  ('Baked Goods', Icons.bakery_dining_outlined),
];

class HomeHarvestMarketScreen extends StatefulWidget {
  const HomeHarvestMarketScreen({super.key});

  @override
  State<HomeHarvestMarketScreen> createState() =>
      _HomeHarvestMarketScreenState();
}

class _HomeHarvestMarketScreenState extends State<HomeHarvestMarketScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeProductsProvider>().loadAllProducts();
    });
  }

  @override
  void dispose() {
    context.read<HomeProductsProvider>().cancelAllProductsListener();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
          Consumer<HomeProductsProvider>(
        builder: (context, provider, _) {
          final sellers = provider.sellers.where((s) {
            final matchesSearch = _searchQuery.isEmpty ||
                s.sellerName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == 'All' ||
                provider.productsForSeller(s.sellerId).any((p) =>
                    p.category.toLowerCase() ==
                    _selectedCategory.toLowerCase());
            return matchesSearch && matchesCategory;
          }).toList();

          return CustomScrollView(
            slivers: [
              // Expanding AppBar with background image
              SliverAppBar(
                expandedHeight: 210,
                pinned: true,
                backgroundColor: const Color(0xFFFC8019),
                foregroundColor: Colors.white,
                centerTitle: true,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                actionsIconTheme: const IconThemeData(color: Colors.white),
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: Text(
                  'Home Harvest Market',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/vocher.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF6B00),
                                Color(0xFFFC8019),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.12),
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '~ Homemade Goodness ~',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(children: [
                              TextSpan(
                                text: 'Buy Fresh & ',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: 'Get Healthy',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFD166),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Authentic homemade products from verified sellers',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildSearchBar(),
                ),
              ),

              // Category chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildCategoryChips(),
                ),
              ),

              // Section heading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'Featured Sellers',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!provider.isLoading && sellers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFC8019).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${sellers.length} sellers',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFFC8019),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Loading / Error / Empty / List
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFC8019)),
                  ),
                )
              else if (provider.errorMessage != null)
                SliverFillRemaining(child: _buildErrorState(provider))
              else if (sellers.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _SellerRow(
                        seller: sellers[i],
                        products: provider
                            .productsForSeller(sellers[i].sellerId),
                      ),
                      childCount: sellers.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(33),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: GoogleFonts.poppins(
            fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search sellers...',
          hintStyle: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFFFC8019), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close,
                      size: 18, color: Colors.grey),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _kCategories.map((item) {
          final label = item.$1;
          final icon = item.$2;
          final selected = _selectedCategory == label;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.fromLTRB(10, 7, 16, 7),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFC8019)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(33),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 14,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFFC8019)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color:
                          selected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFFC8019).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_outlined,
                size: 48, color: Color(0xFFFC8019)),
          ),
          const SizedBox(height: 18),
          Text(
            _selectedCategory == 'All'
                ? 'No sellers yet'
                : 'No sellers in "$_selectedCategory"',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),
          Text('Pull down to refresh',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildErrorState(HomeProductsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('Could not load products',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(provider.errorMessage ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => provider.loadAllProducts(),
              icon: const Icon(Icons.refresh),
              label:
                  Text('Retry', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC8019),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(33)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Seller row: info card (name / rating / count) + horizontal product cards
class _SellerRow extends StatelessWidget {
  final HomeSellerSummary seller;
  final List<HomeProductModel> products;

  const _SellerRow({required this.seller, required this.products});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller info card
          Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + verified badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                seller.sellerName,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (seller.verifiedSeller) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded,
                                  color: Color(0xFF1DA1F2), size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Rating
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFB800), size: 16),
                            const SizedBox(width: 3),
                            Text(
                              seller.avgRating > 0
                                  ? seller.avgRating.toStringAsFixed(1)
                                  : 'New',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Item count (right side - big orange number)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${seller.productCount}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFC8019),
                        ),
                      ),
                      Text(
                        'items',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Product cards horizontal scroll � each card taps to product detail
          if (products.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: products.length,
                itemBuilder: (ctx, i) {
                  final p = products[i];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      ctx,
                      AppRouter.productDetail,
                      arguments: p,
                    ),
                    child: _HotDealCard(
                      product: p,
                      margin: EdgeInsets.only(
                          right: i < products.length - 1 ? 12 : 0),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C42), Color(0xFFFC6B1A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood_outlined,
          color: Colors.white.withOpacity(0.55),
          size: 36,
        ),
      ),
    );
  }
}

// -- HotDeals-style product card --------------------------------------------
class _HotDealCard extends StatefulWidget {
  final HomeProductModel product;
  final EdgeInsets margin;

  const _HotDealCard({required this.product, this.margin = EdgeInsets.zero});

  @override
  State<_HotDealCard> createState() => _HotDealCardState();
}

class _HotDealCardState extends State<_HotDealCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Container(
      width: 165,
      height: 380,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Full background image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: p.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _fallback(),
                      errorWidget: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),

          // Content column: top badge + bottom info panel
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Top: rating badge ----------------------------------
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x7F191D31),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFD166), size: 12),
                              const SizedBox(width: 5),
                              Text(
                                p.rating > 0
                                    ? p.rating.toStringAsFixed(1)
                                    : 'New',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // -- Bottom: frosted glass info panel ------------------
              Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x7F191D31),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.fromLTRB(10, 8, 0, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + price
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                RichText(
                                  text: TextSpan(children: [
                                    TextSpan(
                                      text: '\u20B9 ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFFFC8019),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: p.price.toStringAsFixed(0),
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                          // Heart icon
                          GestureDetector(
                            onTap: () =>
                                setState(() => _liked = !_liked),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  4, 0, 8, 0),
                              child: Icon(
                                _liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _liked
                                    ? Colors.redAccent
                                    : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C42), Color(0xFFFC6B1A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood_outlined,
          color: Colors.white.withOpacity(0.5),
          size: 38,
        ),
      ),
    );
  }
}