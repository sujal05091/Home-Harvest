import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
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
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                      ),
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
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
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
                                    // Background Image (placeholder gradient)
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFFC8019).withOpacity(0.7),
                                            const Color(0xFFFC8019).withOpacity(0.3),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
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
                                                      text: '\$30',
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
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 16),
                              children: [
                                TextSpan(
                                  text: '\$ ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFFFC8019),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: ordersProvider.cartTotal.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 22,
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
                                  text: '\$ ',
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
                                  }
                                },
                                child: Icon(
                                  Icons.remove,
                                  color: item.quantity > 1 ? Colors.black : Colors.grey[400],
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

      // 🗺️ Calculate ACTUAL ROAD DISTANCE using OSRM (not straight line!)
      final pickupLocation = LatLng(
        dish.location.latitude, 
        dish.location.longitude,
      );
      final dropLocation = LatLng(
        _selectedAddress!.location.latitude,
        _selectedAddress!.location.longitude,
      );
      
      // Fetch route info with real road distance from OSRM API
      final routeInfo = await RouteService.getRouteInfo(
        start: pickupLocation,
        end: dropLocation,
      );
      
      print('🚗 [Cart] OSRM Route: ${routeInfo.distanceInKm.toStringAsFixed(2)} km (${routeInfo.distanceInMeters.toStringAsFixed(0)} meters)');
      
      final distanceKm = routeInfo.distanceInKm; // Use actual road distance in KM
      
      // 💰 Calculate delivery pricing with rider earnings (using ROAD distance)
      // Normal food order: distanceKm × ₹8
      final pricingService = PricingService();
      final pricing = await pricingService.calculateDeliveryCharge(
        distanceKm,
        orderType: OrderType.NORMAL_FOOD,
      );

      setState(() {
        _firstDish = dish;
        _distance = distanceKm; // Store road distance in kilometers
        _deliveryCharge = pricing['deliveryCharge'];
        _riderEarning = pricing['riderEarning'];
        _platformCommission = pricing['platformCommission'];
        _isLoadingDetails = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating delivery charge: $e')),
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
      final order = OrderModel(
        orderId: '',
        customerId: authProvider.currentUser!.uid,
        customerName: authProvider.currentUser!.name,
        customerPhone: authProvider.currentUser!.phone,
        cookId: _firstDish!.cookId,
        cookName: _firstDish!.cookName,
        dishItems: ordersProvider.cartItems,
        total: ordersProvider.cartTotal + _deliveryCharge!,
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
        print('🚀 [Cart] Starting FCM notification process for order: $orderId');
        
        // 🚀 Send FCM notifications to nearby riders
        try {
          print('📍 [Cart] Pickup location: ${_firstDish!.location.latitude}, ${_firstDish!.location.longitude}');
          
          await FCMService().notifyNearbyRiders(
            orderId: orderId,
            pickupLat: _firstDish!.location.latitude,
            pickupLng: _firstDish!.location.longitude,
            radiusKm: 5.0,
          );
          print('✅ [Cart] FCM notifications sent to nearby riders');
        } catch (e, stackTrace) {
          print('⚠️ [Cart] FCM notification failed: $e');
          print('   Stack trace: $stackTrace');
          // Continue anyway - riders can still see orders in their dashboard
        }
        
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
