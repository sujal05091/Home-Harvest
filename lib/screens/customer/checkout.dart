import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dishes_provider.dart';
import '../../models/order_model.dart';
import '../../models/address_model.dart';
import '../../app_router.dart';
import '../../services/delivery_charge_service.dart';
import '../../services/pricing_service.dart';
import '../../services/route_service.dart';
import '../../services/fcm_service.dart';
import '../../widgets/select_payment_method_modal.dart';
import '../../widgets/order_success_modal.dart';
import 'select_address.dart';
import 'package:latlong2/latlong.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  AddressModel? _selectedAddress;
  GeoPoint? _pickupLocation;
  String? _sellerId;
  String? _sellerName;
  bool _isHomeProductOrder = false;
  double? _deliveryCharge;
  double? _distance;
  double? _riderEarning;
  double? _platformCommission;
  bool _isLoadingDetails = false;
  bool _isPlacingOrder = false;
  final TextEditingController _voucherController = TextEditingController();
  String _paymentMethod = 'COD';

  // ─── Scheduling state ──────────────────────────────────────────────────────
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();
    // Auto-trigger address selection when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectAddress();
    });
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<OrdersProvider>(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                          'Checkout',
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
                  padding: const EdgeInsets.only(top: 10, bottom: 24),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // Address Section
                        _buildAddressSection(),
                        const SizedBox(height: 24),
                        // Payment Method Section
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 24),
                        // Voucher Code Section
                        _buildVoucherSection(),
                        const SizedBox(height: 24),
                        // Schedule Meal Section
                        _buildScheduleSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              // Order Summary & Checkout Button
              _buildBottomSection(ordersProvider),
            ],
          ),
        ),
      ),
    );
  }

  // ADDRESS SECTION
  Widget _buildAddressSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _selectAddress,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFC8019),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedAddress != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Map Thumbnail
                Container(
                  width: 130,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Icon(
                      Icons.map,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Address Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAddress!.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedAddress!.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No address selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _selectAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC8019),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Select Address',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // PAYMENT METHOD SECTION
  Widget _buildPaymentMethodSection() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: _showPaymentMethodModal,
            child: Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getPaymentMethodIcon(),
                        color: Colors.grey[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPaymentMethodName(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getPaymentMethodDetails(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // VOUCHER SECTION
  Widget _buildVoucherSection() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Voucher Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextFormField(
            controller: _voucherController,
            decoration: InputDecoration(
              hintText: 'Enter voucher code',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.discount,
                color: Colors.grey[600],
                size: 24,
              ),
              filled: true,
              fillColor: Colors.grey[50],
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFFFC8019),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // BOTTOM SECTION (Order Summary + Checkout Button)
  Widget _buildBottomSection(OrdersProvider ordersProvider) {
    final subtotal = ordersProvider.cartTotal;
    final shipping = _deliveryCharge ?? 0.0;
    final total = subtotal + shipping;

    return Column(
      children: [
        // Shipping Cost
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping cost',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    TextSpan(
                      text: '₹ ',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFFC8019),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: shipping.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sub total
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sub total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    TextSpan(
                      text: '₹ ',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFFC8019),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: subtotal.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dashed Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CustomPaint(
            size: Size(MediaQuery.of(context).size.width - 48, 1),
            painter: DashedLinePainter(),
          ),
        ),
        const SizedBox(height: 12),
        // Total
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14),
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
                      text: total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black,
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
        // Checkout Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedAddress == null || _isPlacingOrder || _deliveryCharge == null ||
                      (_isScheduled && (_scheduledDate == null || _scheduledTime == null))
                  ? null
                  : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC8019),
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isPlacingOrder
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Checkout Now',
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
    );
  }

  // 📍 SELECT DELIVERY ADDRESS
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
      // Try regular cook dish first
      final dish = await dishesProvider.getDishById(
        ordersProvider.cartItems.first.dishId
      );

      GeoPoint pickupGeoPoint;
      String sellerId;
      String sellerName;

      if (dish != null) {
        // Regular cook dish
        pickupGeoPoint = dish.location;
        sellerId = dish.cookId;
        sellerName = dish.cookName;
      } else {
        // Home market product — fetch from home_products + seller's user profile
        _isHomeProductOrder = true;
        final productId = ordersProvider.cartItems.first.dishId;
        final productDoc = await FirebaseFirestore.instance
            .collection('home_products')
            .doc(productId)
            .get();

        if (!productDoc.exists) throw Exception('Failed to load details');

        final data = productDoc.data()!;
        sellerId = (data['sellerId'] as String?) ?? '';
        sellerName = (data['sellerName'] as String?) ?? 'Seller';
        if (sellerId.isEmpty) throw Exception('Failed to load details');

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get();

        final geoPoint = userDoc.data()?['location'] as GeoPoint?;
        if (geoPoint == null) throw Exception('Seller location not set. Ask seller to update profile.');
        pickupGeoPoint = geoPoint;
      }

      if (_selectedAddress == null) {
        throw Exception('Failed to load details');
      }

      // ⚠️ CRITICAL VALIDATION: Check coordinates BEFORE calling OSRM
      final pickupLat = pickupGeoPoint.latitude;
      final pickupLng = pickupGeoPoint.longitude;
      final dropLat = _selectedAddress!.location.latitude;
      final dropLng = _selectedAddress!.location.longitude;
      
      print('📍 [Checkout] DEBUG - Pickup GeoPoint: $pickupLat, $pickupLng');
      print('📍 [Checkout] DEBUG - Drop GeoPoint: $dropLat, $dropLng');
      
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
      
      print('✅ [Checkout] Coordinates validated successfully');

      // ✅ FIX: Calculate ACTUAL ROAD DISTANCE using OSRM (not straight line!)
      
      final pickupLocation = LatLng(
        pickupGeoPoint.latitude, 
        pickupGeoPoint.longitude,
      );
      final dropLocation = LatLng(
        _selectedAddress!.location.latitude,
        _selectedAddress!.location.longitude,
      );
      
      print('🗺️ [Checkout] Fetching route from OSRM...');
      print('   Pickup: ${pickupLocation.latitude}, ${pickupLocation.longitude}');
      print('   Drop: ${dropLocation.latitude}, ${dropLocation.longitude}');
      
      // Fetch route info with real road distance from OSRM API
      final routeInfo = await RouteService.getRouteInfo(
        start: pickupLocation,
        end: dropLocation,
      );
      
      final distanceKm = routeInfo.distanceInKm; // Use actual road distance in KM
      print('✅ [Checkout] OSRM Route Result: ${distanceKm.toStringAsFixed(2)} km (${routeInfo.distanceInMeters.toStringAsFixed(0)} meters)');
      
      // 💰 Calculate delivery pricing with rider earnings
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
        _sellerId = sellerId;
        _sellerName = sellerName;
        _pickupLocation = pickupGeoPoint;
        _distance = distanceKm;
        _deliveryCharge = pricing['deliveryCharge'];
        _riderEarning = pricing['riderEarning']; // 100% of delivery charge for Normal Food
        _platformCommission = platformCommissionFromFood; // 10% of food price
        _isLoadingDetails = false;
      });
    } catch (e) {
      print('❌ [Checkout] Error loading delivery details: $e');
      
      setState(() {
        _isLoadingDetails = false;
      });
      
      // Show user-friendly error message
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating delivery charge: $e')),
        );
      }
    }
  }

  // 💳 SHOW PAYMENT METHOD MODAL
  void _showPaymentMethodModal() async {
    // Define available payment methods
    final paymentMethods = [
      PaymentMethod(
        id: 'COD',
        name: 'Cash on Delivery',
        accountDetails: 'Pay with cash',
        icon: Icons.money,
      ),
      PaymentMethod(
        id: 'credit_card',
        name: 'Credit Card',
        accountDetails: 'Coming soon',
        icon: Icons.credit_card,
      ),
      PaymentMethod(
        id: 'upi',
        name: 'UPI',
        accountDetails: 'Pay with UPI',
        icon: Icons.account_balance_wallet,
      ),
    ];

    final selectedId = await SelectPaymentMethodModal.show(
      context,
      initialSelectedId: _paymentMethod,
      paymentMethods: paymentMethods,
      onApply: (selectedId) {
        if (selectedId != null) {
          setState(() {
            _paymentMethod = selectedId;
          });
          print('✅ Payment method updated: $selectedId');
        }
      },
      onAddPaymentMethod: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add Payment Method feature coming soon!'),
            backgroundColor: Color(0xFFFC8019),
          ),
        );
      },
    );

    // Update payment method if selection was made
    if (selectedId != null) {
      setState(() {
        _paymentMethod = selectedId;
      });
    }
  }

  // 🛒 PLACE ORDER
  Future<void> _placeOrder() async {
    print('🛒 [Checkout] _placeOrder() called');
    
    if (_selectedAddress == null || _pickupLocation == null || _sellerId == null || _deliveryCharge == null) {
      print('❌ [Checkout] Missing required data');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select delivery address')),
      );
      return;
    }

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isPlacingOrder = true);
    print('🔄 [Checkout] Loading state set to true');

    try {
      // Save food total BEFORE any operations (in case cart state changes)
      final foodTotal = ordersProvider.cartTotal;
      final cartItemsList = List<OrderItem>.from(ordersProvider.cartItems);
      
      // Fetch cook's phone number from Firestore
      String? cookPhone;
      try {
        final cookDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_sellerId!)
            .get();
        if (cookDoc.exists) {
          cookPhone = cookDoc.data()?['phone'];
          print('📞 [Checkout] Cook phone: $cookPhone');
        }
      } catch (e) {
        print('⚠️ [Checkout] Failed to fetch cook phone: $e');
      }
      
      final order = OrderModel(
        orderId: '',
        customerId: authProvider.currentUser!.uid,
        customerName: authProvider.currentUser!.name,
        customerPhone: authProvider.currentUser!.phone,
        cookId: _sellerId!,
        cookName: _sellerName!,
        cookPhone: cookPhone,
        dishItems: cartItemsList,
        total: foodTotal + _deliveryCharge!,
        paymentMethod: _paymentMethod,
        status: OrderStatus.PLACED,
        pickupAddress: '${_sellerName!}\'s Kitchen',
        pickupLocation: _pickupLocation!,
        dropAddress: _selectedAddress!.fullAddress,
        dropLocation: _selectedAddress!.location,
        createdAt: DateTime.now(),
        isActive: false,
        distanceKm: _distance!,
        deliveryCharge: _deliveryCharge!,
        riderEarning: _riderEarning!,
        platformCommission: _platformCommission!,
        cashCollected: null,
        pendingSettlement: null,
        isSettled: false,
        orderType: _isScheduled ? 'scheduled' : 'instant',
        scheduledDeliveryTime: _isScheduled ? _buildScheduledDateTime() : null,
        isProductOrder: _isHomeProductOrder,
      );

      print('📦 [Checkout] Creating order...');
      String? orderId = await ordersProvider.createOrder(order);
      print('📦 [Checkout] Order created with ID: $orderId');
      
      if (orderId != null && mounted) {
        // ✅ Notify seller / cook about new order
        try {
          final dishNames = cartItemsList
              .map((item) => item.dishName)
              .join(', ');

          if (_isHomeProductOrder) {
            // HOME MARKET product order → notify seller
            print('🔔 [Checkout] Notifying SELLER about new product order...');
            await FCMService().notifySeller(
              sellerId: _sellerId!,
              orderId: orderId,
              customerName: authProvider.currentUser!.name,
              productNames: dishNames,
              totalAmount: foodTotal,
            );
            print('✅ [Checkout] Seller notification sent with amount: ₹$foodTotal');
          } else {
            // Regular cook food order → notify cook
            print('🔔 [Checkout] Notifying COOK about new order...');
            await FCMService().notifyCook(
              cookId: _sellerId!,
              orderId: orderId,
              customerName: authProvider.currentUser!.name,
              dishNames: dishNames,
              totalAmount: foodTotal,
            );
            print('✅ [Checkout] Cook notification sent with amount: ₹$foodTotal');
          }
        } catch (e) {
          print('❌ [Checkout] Failed to notify cook: $e');
        }
        
        // ⚠️ [NORMAL FOOD] Do NOT notify riders immediately!
        // Workflow: PLACED → Cook Accepts → PREPARING → READY → Riders see order
        // Riders will see this order automatically when cook marks it READY
        // (getUnassignedOrders filters for status=READY)
        print('✅ [Checkout] Order placed. Cook must accept and prepare food.');
        print('   Riders will see order when cook marks it READY.');
        
        // Clear cart first
        ordersProvider.clearCart();
        
        print('🎉 [Checkout] Showing order success modal');
        // Show order success modal
        await OrderSuccessModal.show(
          context,
          onTrackOrder: () {
            print('🧭 [Checkout] Navigating to Finding Partner screen');
            // Navigate to Finding Partner screen
            Navigator.pushReplacementNamed(
              context,
              AppRouter.findingPartner,
              arguments: {'orderId': orderId},
            );
          },
        );
        
        print('✅ [Checkout] Order process complete!');
      } else {
        throw Exception('Failed to create order');
      }
    } catch (e, stackTrace) {
      print('❌ [Checkout] Error placing order: $e');
      print('   Stack trace: $stackTrace');
      
      setState(() => _isPlacingOrder = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
        );
      }
    }
  }

  // 💳 HELPER: Get Payment Method Icon
  IconData _getPaymentMethodIcon() {
    switch (_paymentMethod) {
      case 'COD':
        return Icons.money;
      case 'credit_card':
        return Icons.credit_card;
      case 'upi':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  // 💳 HELPER: Get Payment Method Name
  String _getPaymentMethodName() {
    switch (_paymentMethod) {
      case 'COD':
        return 'Cash on Delivery';
      case 'credit_card':
        return 'Credit Card';
      case 'upi':
        return 'UPI';
      default:
        return 'Select Payment Method';
    }
  }

  // 💳 HELPER: Get Payment Method Details
  String _getPaymentMethodDetails() {
    switch (_paymentMethod) {
      case 'COD':
        return 'Pay with cash';
      case 'credit_card':
        return 'Coming soon';
      case 'upi':
        return 'Pay with UPI';
      default:
        return '';
    }
  }

  // 🗓️ SCHEDULE MEAL SECTION
  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Delivery Time',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Deliver Now
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isScheduled = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: !_isScheduled
                          ? const Color(0xFFFC8019)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isScheduled
                            ? const Color(0xFFFC8019)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.flash_on_rounded,
                            color: !_isScheduled
                                ? Colors.white
                                : Colors.grey[500],
                            size: 22),
                        const SizedBox(height: 4),
                        Text(
                          'Deliver Now',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: !_isScheduled
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Schedule Later
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isScheduled = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          _isScheduled ? const Color(0xFFFC8019) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isScheduled
                            ? const Color(0xFFFC8019)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: _isScheduled
                                ? Colors.white
                                : Colors.grey[500],
                            size: 22),
                        const SizedBox(height: 4),
                        Text(
                          'Schedule Later',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isScheduled
                                ? Colors.white
                                : Colors.grey[600],
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
        // Date & time pickers when scheduled
        if (_isScheduled) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Date picker
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _scheduledDate ?? now.add(const Duration(hours: 1)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 7)),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFFFC8019),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _scheduledDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _scheduledDate != null
                              ? const Color(0xFFFC8019)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 18,
                              color: _scheduledDate != null
                                  ? const Color(0xFFFC8019)
                                  : Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _scheduledDate != null
                                  ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                                  : 'Pick Date',
                              style: TextStyle(
                                fontSize: 13,
                                color: _scheduledDate != null
                                    ? Colors.black87
                                    : Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Time picker
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _scheduledTime ??
                            TimeOfDay.fromDateTime(
                                DateTime.now().add(const Duration(hours: 1))),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFFFC8019),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _scheduledTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _scheduledTime != null
                              ? const Color(0xFFFC8019)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 18,
                              color: _scheduledTime != null
                                  ? const Color(0xFFFC8019)
                                  : Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _scheduledTime != null
                                  ? _scheduledTime!.format(context)
                                  : 'Pick Time',
                              style: TextStyle(
                                fontSize: 13,
                                color: _scheduledTime != null
                                    ? Colors.black87
                                    : Colors.grey[500],
                                fontWeight: FontWeight.w500,
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
          ),
          if (_scheduledDate != null && _scheduledTime != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFC8019).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFFFC8019), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Deliver on ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year} at ${_scheduledTime!.format(context)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFC8019),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  DateTime? _buildScheduledDateTime() {
    if (_scheduledDate == null || _scheduledTime == null) return null;
    return DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );
  }
}

// Custom Dashed Line Painter
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;

    const dashWidth = 5;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
