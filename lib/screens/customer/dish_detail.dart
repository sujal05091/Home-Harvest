import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/order_model.dart';
import '../../providers/dishes_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/auth_provider.dart' as auth;

class DishDetailScreen extends StatefulWidget {
  final String dishId;

  const DishDetailScreen({super.key, required this.dishId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int _quantity = 1;
  bool _showFullDescription = false;

  // ─── Customization state ───────────────────────────────────────────────────
  String _sugar = 'Normal';
  String _spice = 'Normal';
  String _salt = 'Normal';
  String _oil = 'Normal';
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid;
      
      // Load favorites if user is logged in
      if (userId != null) {
        Provider.of<FavoritesProvider>(context, listen: false).loadFavorites(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dishesProvider = Provider.of<DishesProvider>(context);
    final ordersProvider = Provider.of<OrdersProvider>(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);

    return FutureBuilder(
      future: dishesProvider.getDishById(widget.dishId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFC8019)),
              ),
            ),
          );
        }

        final dish = snapshot.data!;
        final isFavorite = favoritesProvider.isDishFavorite(dish.dishId);

        return Scaffold(
          body: Stack(
            children: [
              // ═══════════════════════════════════════════════════════════
              // 📸 FULL-PAGE SCROLLABLE CONTENT (image scrolls too)
              // ═══════════════════════════════════════════════════════════
              CustomScrollView(
                slivers: [
                  // ───────────────────────────────────────
                  // 1️⃣ COLLAPSIBLE IMAGE HEADER
                  // ───────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 350,
                    pinned: false,
                    floating: false,
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: dish.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFC8019)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.restaurant,
                                size: 100,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.black.withOpacity(0.15),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ───────────────────────────────────────
                  // 📝 ALL SCROLLABLE CONTENT
                  // ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // ───────────────────────────────────────
                            // 3️⃣ FOOD TITLE SECTION
                            // ───────────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Fresh badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFC8019)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF27AE60),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'FRESH',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Dish name
                                      Text(
                                        dish.title,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Cook name with badge
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'By ${dish.cookName}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF27AE60)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'HOME COOKED',
                                              style: TextStyle(
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF27AE60),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // ───────────────────────────────────────
                                // 4️⃣ QUANTITY CONTROLLER - Improved
                                // ───────────────────────────────────────
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 20),
                                        onPressed: _quantity > 1
                                            ? () => setState(() => _quantity--)
                                            : null,
                                        color: _quantity > 1
                                            ? Colors.black87
                                            : Colors.grey[400],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          _quantity.toString(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 20),
                                        onPressed: () =>
                                            setState(() => _quantity++),
                                        color: Colors.black87,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ───────────────────────────────────────
                            // 5️⃣ STATS ROW - Card Style
                            // ───────────────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.star_rounded,
                                    iconColor: Colors.amber,
                                    label: 'Rating',
                                    value: dish.rating?.toStringAsFixed(1) ??
                                        '4.5',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[200],
                                  ),
                                  _buildStatItem(
                                    icon: Icons.local_fire_department,
                                    iconColor: const Color.fromARGB(255, 58, 169, 15),
                                    label: 'Freshness',
                                    value: '100% Fresh',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[200],
                                  ),
                                  _buildStatItem(
                                    icon: Icons.access_time_rounded,
                                    iconColor: const Color(0xFFFC8019),
                                    label: 'Time',
                                    value: '15-20 min',
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ───────────────────────────────────────
                            // 6️⃣ DESCRIPTION - Enhanced Readability
                            // ───────────────────────────────────────
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _showFullDescription
                                      ? dish.description
                                      : dish.description.length > 150
                                          ? '${dish.description.substring(0, 150)}...'
                                          : dish.description,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                    height: 1.6,
                                  ),
                                ),
                                if (dish.description.length > 150)
                                  TextButton(
                                    onPressed: () => setState(() =>
                                        _showFullDescription =
                                            !_showFullDescription),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _showFullDescription
                                          ? 'Show Less'
                                          : 'Read More',
                                      style: const TextStyle(
                                        color: Color(0xFFFC8019),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ───────────────────────────────────────
                            // 7️⃣ CUSTOMIZE YOUR MEAL
                            // ───────────────────────────────────────
                            _buildCustomizationSection(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // ───────────────────────────────────────
              // 2️⃣ FLOATING BACK + FAVOURITE BUTTONS
              // ───────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                            color: Colors.black87,
                          ),
                        ),
                        Consumer<FavoritesProvider>(
                          builder: (context, favProvider, _) {
                            final isFav =
                                favProvider.isDishFavorite(dish.dishId);
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color:
                                      isFav ? Colors.red : Colors.black87,
                                ),
                                onPressed: () => favProvider
                                    .toggleDishFavorite(dish.dishId),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════════════════════════
              // 8️⃣ STICKY BOTTOM - Price + Add to Cart
              // ═══════════════════════════════════════════════════════════
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price section - Dominant
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total Price',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '₹ ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color.fromARGB(255, 224, 104, 7),
                                    ),
                                  ),
                                  TextSpan(
                                    text: (dish.price * _quantity)
                                        .toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 15, 10, 5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Add to Cart button - Bold & Primary
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final customization = FoodCustomization(
                                  sugar: _sugar,
                                  spice: _spice,
                                  salt: _salt,
                                  oil: _oil,
                                  notes: _notesController.text.trim().isEmpty
                                      ? null
                                      : _notesController.text.trim(),
                                );
                                ordersProvider.addToCart(
                                  dish,
                                  quantity: _quantity,
                                  customization: customization,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added $_quantity ${_quantity > 1 ? "items" : "item"} to cart',
                                    ),
                                    backgroundColor: const Color(0xFF27AE60),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.shopping_bag, size: 22),
                              label: const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFC8019),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 STAT ITEM WIDGET
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─── CUSTOMIZATION SECTION ────────────────────────────────────────────────
  Widget _buildCustomizationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 20, color: Color(0xFFFC8019)),
              const SizedBox(width: 8),
              const Text(
                'Customize Your Meal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sugar level
          _buildChipSelector(
            label: '🍬 Sugar Level',
            options: const ['No Sugar', 'Less Sugar', 'Normal'],
            selected: _sugar,
            onSelected: (v) => setState(() => _sugar = v),
          ),
          const SizedBox(height: 12),

          // Spice level
          _buildChipSelector(
            label: '🌶️ Spice Level',
            options: const ['Mild', 'Normal', 'Extra Spicy'],
            selected: _spice,
            onSelected: (v) => setState(() => _spice = v),
          ),
          const SizedBox(height: 12),

          // Salt level
          _buildChipSelector(
            label: '🧂 Salt Level',
            options: const ['Less Salt', 'Normal'],
            selected: _salt,
            onSelected: (v) => setState(() => _salt = v),
          ),
          const SizedBox(height: 12),

          // Oil level
          _buildChipSelector(
            label: '🫙 Oil Level',
            options: const ['Low Oil', 'Normal'],
            selected: _oil,
            onSelected: (v) => setState(() => _oil = v),
          ),
          const SizedBox(height: 14),

          // Special notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            maxLength: 120,
            decoration: InputDecoration(
              hintText: 'Any special instructions? (optional)',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              counterStyle:
                  TextStyle(fontSize: 11, color: Colors.grey[400]),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.grey[300]!, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                    color: Color(0xFFFC8019), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSelector({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700]),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selected == option;
            return GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFC8019)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFC8019)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color:
                        isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
