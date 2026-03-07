import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dishes_provider.dart';
import '../../models/order_model.dart';
import '../../models/address_model.dart';
import '../../models/dish_model.dart';
import '../../app_router.dart';
import '../../services/delivery_charge_service.dart';
import '../../services/pricing_service.dart';
import '../../services/fcm_service.dart';
import '../../services/route_service.dart';
import 'select_address.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  AddressModel? _selectedAddress;
  DishModel? _firstDish;
  double? _deliveryCharge;
  double? _distance;
  double? _riderEarning;
  double? _platformCommission;
  bool _isLoadingDetails = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<OrdersProvider>(context);

    if (ordersProvider.cartItems.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'My Cart',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer for alignment
                    ],
                  ),
                ),
              ),
              // Empty State
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/lottie/empty_cart.json',
                        width: 250,
                        height: 250,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your cart is empty',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC8019),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Browse Dishes', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'My Cart',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Clear Cart Button
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Clear Cart?'),
                                content: const Text('Are you sure you want to remove all items from your cart?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ordersProvider.clearCart();
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          label: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          // Discount Banner
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    // Background Image
                                    Positioned.fill(
                                      child: Image.asset(
                                        'assets/images/vocher.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // Gradient Overlay
                                    Container(
                                      width: double.infinity,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withOpacity(0),
                                            Colors.black.withOpacity(0.75),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
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
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'FoodCort Discount',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: const Color(0xFFFC8019),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.white,
                                                  ),
                                                  children: [
                                                    const TextSpan(
                                                      text: '40% discount for purchases over ',
                                                      style: TextStyle(fontWeight: FontWeight.w500),
                                                    ),
                                                    TextSpan(
                                                      text: '₹500',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: const Color(0xFFFC8019),
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const TextSpan(
                                                      text: ', valid for today only',
                                                      style: TextStyle(fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () {},
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white.withOpacity(0.01),
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                  elevation: 0,
                                                  side: BorderSide(color: Colors.grey[100]!, width: 1),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(30),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Get Discount',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Cart Items Section
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Your Order',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Text(
                                        'See All',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFC8019),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Cart Items
                              ...ordersProvider.cartItems.map((item) => _buildCartItem(item, ordersProvider)).toList(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Section (Order Total + Checkout)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order Total',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black,
          
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 16),
                              children: [
                                TextSpan(
                                  text: '₹ ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFFFC8019),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: ordersProvider.cartTotal.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _navigateToCheckout(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFC8019),
                            disabledBackgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Checkout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build Cart Item Card
  Widget _buildCartItem(OrderItem item, OrdersProvider ordersProvider) {
    final dishesProvider = Provider.of<DishesProvider>(context, listen: false);
    
    return FutureBuilder<DishModel?>(
      future: dishesProvider.getDishById(item.dishId),
      builder: (context, snapshot) {
        final dish = snapshot.data;
        
        return Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          child: Row(
            children: [
              // Item Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: dish?.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: dish!.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.restaurant, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.restaurant, color: Colors.grey),
                        ),
                ),
              ),
          const SizedBox(width: 10),
              // Item Details
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.dishName,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Show customization summary if any
                    if (item.customization != null &&
                        item.customization!.hasAnyCustomization) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.customization!.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFFC8019).withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Flexible(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 16),
                              children: [
                                TextSpan(
                                  text: '₹ ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFFFC8019),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: item.price.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Quantity Controller
                        Container(
                          width: 120,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Decrement Button
                              GestureDetector(
                                onTap: () {
                                  if (item.quantity > 1) {
                                    ordersProvider.updateCartItemQuantity(item.dishId, item.quantity - 1);
                                  } else {
                                    // Remove item from cart when quantity is 1
                                    ordersProvider.removeFromCart(item.dishId);
                                  }
                                },
                                child: Icon(
                                  item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                                  color: item.quantity > 1 ? Colors.black : Colors.red,
                                  size: 20,
                                ),
                              ),
                              // Count Display
                              Text(
                                item.quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              // Increment Button
                              GestureDetector(
                                onTap: () {
                                  ordersProvider.updateCartItemQuantity(item.dishId, item.quantity + 1);
                                },
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Customise Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => _showCustomizeBottomSheet(context, item, ordersProvider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFFC8019)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.tune_rounded, size: 14, color: Color(0xFFFC8019)),
                              SizedBox(width: 4),
                              Text(
                                'Customise',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFC8019),
                                  fontWeight: FontWeight.w600,
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
            ],
          ),
        );
      },
    );
  }

  void _showCustomizeBottomSheet(
      BuildContext context, OrderItem item, OrdersProvider ordersProvider) {
    String sugar = item.customization?.sugar ?? 'Normal';
    String spice = item.customization?.spice ?? 'Normal';
    String salt = item.customization?.salt ?? 'Normal';
    String oil = item.customization?.oil ?? 'Normal';
    final notesController =
        TextEditingController(text: item.customization?.notes ?? '');

    const options = ['Less', 'Normal', 'More'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFFFC8019)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customise ${item.dishName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Sugar
                _buildSheetChipRow(
                  label: '🍬 Sugar',
                  selected: sugar,
                  options: options,
                  onChanged: (val) => setModalState(() => sugar = val),
                ),
                const SizedBox(height: 12),

                // Spice
                _buildSheetChipRow(
                  label: '🌶️ Spice',
                  selected: spice,
                  options: options,
                  onChanged: (val) => setModalState(() => spice = val),
                ),
                const SizedBox(height: 12),

                // Salt
                _buildSheetChipRow(
                  label: '🧂 Salt',
                  selected: salt,
                  options: options,
                  onChanged: (val) => setModalState(() => salt = val),
                ),
                const SizedBox(height: 12),

                // Oil
                _buildSheetChipRow(
                  label: '🫒 Oil',
                  selected: oil,
                  options: options,
                  onChanged: (val) => setModalState(() => oil = val),
                ),
                const SizedBox(height: 16),

                // Notes
                Text(
                  'Special Instructions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'E.g. no onions, extra sauce...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final customization = FoodCustomization(
                        sugar: sugar,
                        spice: spice,
                        salt: salt,
                        oil: oil,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );
                      ordersProvider.updateCartItemCustomization(
                          item.dishId, customization);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC8019),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Customisation',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetChipRow({
    required String label,
    required String selected,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: options.map((opt) {
            final isSelected = selected == opt;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
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
                    opt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // � NAVIGATE TO CHECKOUT
  void _navigateToCheckout() {
    Navigator.pushNamed(context, AppRouter.checkout);
  }

  // �📍 SELECT DELIVERY ADDRESS
  Future<void> _selectAddress() async {
    final address = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectAddressScreen(),
      ),
    );

    if (address != null) {
      setState(() {
        _selectedAddress = address;
        _isLoadingDetails = true;
      });

      // Load dish details and calculate delivery charge
      await _loadDeliveryDetails();
    }
  }

  // 📦 LOAD DISH DETAILS AND CALCULATE DELIVERY CHARGE
  Future<void> _loadDeliveryDetails() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final dishesProvider = Provider.of<DishesProvider>(context, listen: false);

    try {
      // Get first dish details (cook location)
      final dish = await dishesProvider.getDishById(
        ordersProvider.cartItems.first.dishId
      );

      if (dish == null || _selectedAddress == null) {
        throw Exception('Failed to load details');
      }

      // ⚠️ CRITICAL VALIDATION: Check coordinates BEFORE calling OSRM
      final pickupLat = dish.location.latitude;
      final pickupLng = dish.location.longitude;
      final dropLat = _selectedAddress!.location.latitude;
      final dropLng = _selectedAddress!.location.longitude;
      
      print('📍 [Cart] DEBUG - Pickup GeoPoint: $pickupLat, $pickupLng');
      print('📍 [Cart] DEBUG - Drop GeoPoint: $dropLat, $dropLng');
      
      // Validate coordinates are not null, zero, or out of range
      if (pickupLat == 0 || pickupLng == 0 || dropLat == 0 || dropLng == 0) {
        throw Exception('⚠️ Invalid coordinates detected! Pickup or Drop location has 0,0 coordinates');
      }
      
      if (pickupLat < -90 || pickupLat > 90 || dropLat < -90 || dropLat > 90) {
        throw Exception('⚠️ Invalid latitude! Must be between -90 and 90');
      }
      
      if (pickupLng < -180 || pickupLng > 180 || dropLng < -180 || dropLng > 180) {
        throw Exception('⚠️ Invalid longitude! Must be between -180 and 180');
      }
      
      print('✅ [Cart] Coordinates validated successfully');

      // ✅ FIX: Calculate ACTUAL ROAD DISTANCE using OSRM (not straight line!)
      
      final pickupLocation = LatLng(
        dish.location.latitude, 
        dish.location.longitude,
      );
      final dropLocation = LatLng(
        _selectedAddress!.location.latitude,
        _selectedAddress!.location.longitude,
      );
      
      print('🗺️ [Cart] Fetching route from OSRM...');
      print('   Start: ${pickupLocation.latitude}, ${pickupLocation.longitude}');
      print('   End: ${dropLocation.latitude}, ${dropLocation.longitude}');
      
      // Fetch route info with real road distance from OSRM API
      final routeInfo = await RouteService.getRouteInfo(
        start: pickupLocation,
        end: dropLocation,
      );
      
      print('✅ [Cart] OSRM Route Result: ${routeInfo.distanceInKm.toStringAsFixed(2)} km (${routeInfo.distanceInMeters.toStringAsFixed(0)} meters)');
      
      final distanceKm = routeInfo.distanceInKm; // Use actual road distance in KM
      
      // 💰 Calculate delivery pricing with rider earnings (using ROAD distance)
      // Normal food order: distanceKm × ₹8
      final pricingService = PricingService();
      final pricing = await pricingService.calculateDeliveryCharge(
        distanceKm,
        orderType: OrderType.NORMAL_FOOD,
      );

      // For NORMAL FOOD: Platform commission = 10% of food price
      // Food price = cart total (before adding delivery charge)
      final foodPrice = ordersProvider.cartTotal;
      final platformCommissionFromFood = foodPrice * 0.10; // 10% of food price

      setState(() {
        _firstDish = dish;
        _distance = distanceKm; // Store road distance in kilometers
        _deliveryCharge = pricing['deliveryCharge'];
        _riderEarning = pricing['riderEarning']; // 100% of delivery charge for Normal Food
        _platformCommission = platformCommissionFromFood; // 10% of food price
        _isLoadingDetails = false;
      });
    } catch (e) {
      print('❌ [Cart] Error loading delivery details: $e');
      
      setState(() {
        _isLoadingDetails = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('0,0 coordinates')
                  ? '⚠️ Invalid dish location! Cook needs to update restaurant address.'
                  : '❌ Error calculating delivery: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // 🛒 PLACE ORDER
  Future<void> _placeOrder() async {
    print('🛒 [Cart] _placeOrder() called');
    
    if (_selectedAddress == null || _firstDish == null || _deliveryCharge == null) {
      print('❌ [Cart] Missing required data: address=${_selectedAddress != null}, dish=${_firstDish != null}, delivery=${_deliveryCharge != null}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select delivery address')),
      );
      return;
    }

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoadingDetails = true);
    print('🔄 [Cart] Loading state set to true');

    try {
      // Save food total BEFORE any operations (in case cart state changes)
      final foodTotal = ordersProvider.cartTotal;
      final cartItemsList = List<OrderItem>.from(ordersProvider.cartItems);
      
      // Fetch cook's phone number from Firestore
      String? cookPhone;
      try {
        final cookDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_firstDish!.cookId)
            .get();
        if (cookDoc.exists) {
          cookPhone = cookDoc.data()?['phone'];
          print('📞 [Cart] Cook phone: $cookPhone');
        }
      } catch (e) {
        print('⚠️ [Cart] Failed to fetch cook phone: $e');
      }
      
      final order = OrderModel(
        orderId: '',
        customerId: authProvider.currentUser!.uid,
        customerName: authProvider.currentUser!.name,
        customerPhone: authProvider.currentUser!.phone,
        cookId: _firstDish!.cookId,
        cookName: _firstDish!.cookName,
        cookPhone: cookPhone,
        dishItems: cartItemsList,
        total: foodTotal + _deliveryCharge!,
        paymentMethod: 'COD',
        status: OrderStatus.PLACED,
        pickupAddress: '${_firstDish!.cookName}\'s Kitchen',
        pickupLocation: _firstDish!.location,
        dropAddress: _selectedAddress!.fullAddress,
        dropLocation: _selectedAddress!.location,
        createdAt: DateTime.now(),
        // 💰 NEW PRODUCTION FIELDS
        isActive: false, // Will be set true when rider accepts
        distanceKm: _distance!,
        deliveryCharge: _deliveryCharge!,
        riderEarning: _riderEarning!,
        platformCommission: _platformCommission!,
        cashCollected: null,
        pendingSettlement: null,
        isSettled: false,
      );

      print('📦 [Cart] Creating order...');
      String? orderId = await ordersProvider.createOrder(order);
      print('📦 [Cart] Order created with ID: $orderId');
      
      if (orderId != null && mounted) {
        // ✅ Notify cook about new order
        try {
          print('🔔 [Cart] Notifying cook about new order...');
          final dishNames = cartItemsList
              .map((item) => item.dishName)
              .join(', ');
          
          await FCMService().notifyCook(
            cookId: _firstDish!.cookId,
            orderId: orderId,
            customerName: authProvider.currentUser!.name,
            dishNames: dishNames,
            totalAmount: foodTotal,  // ✅ Using saved food total
          );
          print('✅ [Cart] Cook notification sent with amount: ₹$foodTotal');
        } catch (e) {
          print('❌ [Cart] Failed to notify cook: $e');
        }
        
        // ✅ [NORMAL FOOD WORKFLOW FIX - Issue #2]
        // DO NOT notify riders immediately!
        // Correct flow: PLACED → Cook Accepts → PREPARING → READY → Riders notified
        // Riders will ONLY see orders when cook marks them READY
        print('✅ [Cart] Order placed with status=PLACED');
        print('   ⏳ Waiting for cook to accept and prepare food');
        print('   🔔 Riders will be notified when cook marks food READY');
        
        print('🧭 [Cart] Navigating to Finding Partner screen...');
        // Navigate to Finding Partner screen for real-time tracking
        Navigator.pushReplacementNamed(
          context,
          AppRouter.findingPartner,
          arguments: {'orderId': orderId},
        );
        
        // Clear cart after successful order placement
        ordersProvider.clearCart();
        print('✅ [Cart] Order process complete!');
      } else {
        throw Exception('Failed to create order');
      }
    } catch (e, stackTrace) {
      print('❌ [Cart] Error placing order: $e');
      print('   Stack trace: $stackTrace');
      
      setState(() => _isLoadingDetails = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
        );
      }
    }
  }
}
