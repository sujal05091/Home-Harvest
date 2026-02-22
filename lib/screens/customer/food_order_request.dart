import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/dishes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/dish_model.dart';
import '../../models/address_model.dart';
import '../../services/delivery_charge_service.dart';
import 'select_address.dart';
import 'cart.dart';

/// 🍽️ Food Order Request Screen - For Normal Food Delivery
/// Separate from Tiffin Service
class FoodOrderRequestScreen extends StatefulWidget {
  const FoodOrderRequestScreen({super.key});

  @override
  State<FoodOrderRequestScreen> createState() => _FoodOrderRequestScreenState();
}

class _FoodOrderRequestScreenState extends State<FoodOrderRequestScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _selectedDishes = {}; // dishId: quantity
  AddressModel? _selectedAddress;
  bool _isLoadingCharges = false;
  double? _estimatedDeliveryCharge;

  final List<String> _categories = [
    'All',
    'North Indian',
    'South Indian',
    'Chinese',
    'Continental',
    'Fast Food',
    'Desserts',
    'Beverages',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Calculate total items
  int get _totalItems {
    return _selectedDishes.values.fold(0, (sum, qty) => sum + qty);
  }

  // Calculate subtotal
  double _calculateSubtotal(List<DishModel> dishes) {
    double subtotal = 0;
    for (var entry in _selectedDishes.entries) {
      final dish = dishes.firstWhere((d) => d.dishId == entry.key,
          orElse: () => DishModel(
                dishId: '',
                name: '',
                description: '',
                price: 0,
                imageUrl: '',
                category: '',
                cookId: '',
                cookName: '',
              ));
      subtotal += dish.price * entry.value;
    }
    return subtotal;
  }

  // Fetch delivery charge
  Future<void> _fetchDeliveryCharge(double subtotal) async {
    if (_selectedAddress == null) return;

    setState(() => _isLoadingCharges = true);

    try {
      // Get first dish's cook location (assuming single cook orders)
      final firstDishId = _selectedDishes.keys.first;
      final dishDoc = await FirebaseFirestore.instance
          .collection('dishes')
          .doc(firstDishId)
          .get();

      if (dishDoc.exists) {
        final cookId = dishDoc.data()?['cookId'];
        final cookDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cookId)
            .get();

        if (cookDoc.exists && cookDoc.data()?['currentLocation'] != null) {
          final cookLocation = cookDoc.data()!['currentLocation'];
          final deliveryChargeData =
              await DeliveryChargeService.calculateDeliveryCharge(
            orderAmount: subtotal,
            distance: 5.0, // Placeholder - calculate actual distance
            customerLat: _selectedAddress!.latitude,
            customerLng: _selectedAddress!.longitude,
            cookLat: cookLocation['latitude'],
            cookLng: cookLocation['longitude'],
          );

          setState(() {
            _estimatedDeliveryCharge = deliveryChargeData['deliveryCharge'];
          });
        }
      }
    } catch (e) {
      print('Error fetching delivery charge: $e');
    } finally {
      setState(() => _isLoadingCharges = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dishesProvider = Provider.of<DishesProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          '🍽️ Order Food',
          style: TextStyle(
            color: Color(0xFFFC8019),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFC8019)),
        actions: [
          // Cart button
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════════════
          // 🔍 SEARCH BAR
          // ═══════════════════════════════════════════════════════════
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search dishes...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFC8019)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // 🏷️ CATEGORY CHIPS
          // ═══════════════════════════════════════════════════════════
          Container(
            height: 50,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                    },
                    selectedColor: const Color(0xFFFC8019),
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ═══════════════════════════════════════════════════════════
          // 📍 ADDRESS SELECTION
          // ═══════════════════════════════════════════════════════════
          if (_selectedDishes.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  final address = await Navigator.push<AddressModel>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelectAddressScreen(
                        onAddressSelected: (addr) => Navigator.pop(context, addr),
                      ),
                    ),
                  );
                  if (address != null) {
                    setState(() => _selectedAddress = address);
                    final subtotal = _calculateSubtotal(dishesProvider.dishes);
                    _fetchDeliveryCharge(subtotal);
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      _selectedAddress == null
                          ? Icons.location_on_outlined
                          : Icons.location_on,
                      color: const Color(0xFFFC8019),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAddress == null
                                ? 'Select Delivery Address'
                                : _selectedAddress!.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_selectedAddress != null)
                            Text(
                              _selectedAddress!.fullAddress,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

          // ═══════════════════════════════════════════════════════════
          // 🍽️ DISHES LIST
          // ═══════════════════════════════════════════════════════════
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dishes')
                  .where('isAvailable', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFC8019)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No dishes available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter dishes
                List<DishModel> dishes = snapshot.data!.docs.map((doc) {
                  return DishModel.fromFirestore(doc);
                }).toList();

                // Apply category filter
                if (_selectedCategory != 'All') {
                  dishes = dishes
                      .where((dish) => dish.category == _selectedCategory)
                      .toList();
                }

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  dishes = dishes.where((dish) {
                    return dish.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        dish.description
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (dishes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No dishes found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dishes.length,
                  itemBuilder: (context, index) {
                    final dish = dishes[index];
                    final quantity = _selectedDishes[dish.dishId] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dish Image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: dish.imageUrl,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.restaurant, size: 40),
                              ),
                            ),
                          ),

                          // Dish Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dish.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dish.description,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${dish.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFFFC8019),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Add/Remove buttons
                                      if (quantity == 0)
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedDishes[dish.dishId] = 1;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFFC8019),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'ADD',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFFFC8019),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon:
                                                    const Icon(Icons.remove, size: 16),
                                                onPressed: () {
                                                  setState(() {
                                                    if (quantity > 1) {
                                                      _selectedDishes[
                                                          dish.dishId] = quantity - 1;
                                                    } else {
                                                      _selectedDishes
                                                          .remove(dish.dishId);
                                                    }
                                                  });
                                                },
                                                color: const Color(0xFFFC8019),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32,
                                                ),
                                              ),
                                              Text(
                                                quantity.toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add, size: 16),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedDishes[
                                                        dish.dishId] = quantity + 1;
                                                  });
                                                },
                                                color: const Color(0xFFFC8019),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════════════════════
      // 🛒 BOTTOM CHECKOUT BAR
      // ═══════════════════════════════════════════════════════════
      bottomNavigationBar: _selectedDishes.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Price breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_totalItems item${_totalItems > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${_calculateSubtotal(dishesProvider.dishes).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_estimatedDeliveryCharge != null)
                              Text(
                                '+ ₹${_estimatedDeliveryCharge!.toStringAsFixed(0)} delivery',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Proceed button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _selectedAddress == null
                            ? null
                            : () {
                                // Navigate to cart or checkout
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CartScreen(),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC8019),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: Text(
                          _selectedAddress == null
                              ? 'Select Address to Continue'
                              : 'Proceed to Checkout',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
