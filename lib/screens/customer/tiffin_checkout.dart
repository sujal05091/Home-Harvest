import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/delivery_charge_service.dart';
import '../../services/fcm_service.dart';
import '../../services/pricing_service.dart';
import '../../services/route_service.dart';
import '../../models/address_model.dart';
import '../../models/order_model.dart';
import '../../app_router.dart';
import '../../widgets/select_payment_method_modal.dart';
import '../../widgets/order_success_modal.dart';
import 'package:uuid/uuid.dart';

class TiffinCheckoutScreen extends StatefulWidget {
  final AddressModel homeAddress;
  final AddressModel officeAddress;

  const TiffinCheckoutScreen({
    super.key,
    required this.homeAddress,
    required this.officeAddress,
  });

  @override
  State<TiffinCheckoutScreen> createState() => _TiffinCheckoutScreenState();
}

class _TiffinCheckoutScreenState extends State<TiffinCheckoutScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _paymentMethod = 'COD';
  bool _isPlacingOrder = false;
  double? _deliveryCharge;
  double? _distance;
  double? _riderEarning;
  double? _platformCommission;

  @override
  void initState() {
    super.initState();
    _calculateDeliveryCharge();
  }

  Future<void> _calculateDeliveryCharge() async {
    try {
      // 🗺️ Calculate ACTUAL ROAD DISTANCE using OSRM (not straight line!)
      final pickupLocation = LatLng(
        widget.homeAddress.location.latitude,
        widget.homeAddress.location.longitude,
      );
      final dropLocation = LatLng(
        widget.officeAddress.location.latitude,
        widget.officeAddress.location.longitude,
      );
      
      // Fetch route info with real road distance from OSRM API
      final routeInfo = await RouteService.getRouteInfo(
        start: pickupLocation,
        end: dropLocation,
      );
      
      print('🚗 [Tiffin] OSRM Route: ${routeInfo.distanceInKm.toStringAsFixed(2)} km (${routeInfo.distanceInMeters.toStringAsFixed(0)} meters)');
      
      final distanceKm = routeInfo.distanceInKm; // Use actual road distance in KM
      
      // Calculate delivery pricing with rider earnings (using ROAD distance)
      // Tiffin order: FLAT ₹20
      final pricingService = PricingService();
      final pricing = await pricingService.calculateDeliveryCharge(
        distanceKm,
        orderType: OrderType.TIFFIN,
      );

      setState(() {
        _distance = distanceKm; // Store road distance in kilometers
        _deliveryCharge = pricing['deliveryCharge']!;
        _riderEarning = pricing['riderEarning']!;
        _platformCommission = pricing['platformCommission']!;
      });
    } catch (e) {
      debugPrint('Error calculating delivery charge: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        'Tiffin Checkout',
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

                      // Pickup Address Section
                      _buildAddressSection(
                        'Pickup Location',
                        widget.homeAddress,
                        Icons.home_outlined,
                        Colors.green,
                      ),

                      const SizedBox(height: 24),

                      // Delivery Address Section
                      _buildAddressSection(
                        'Delivery Location',
                        widget.officeAddress,
                        Icons.business_outlined,
                        Colors.blue,
                      ),

                      const SizedBox(height: 24),

                      // Payment Method Section
                      _buildPaymentMethodSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Order Summary & Checkout Button
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  // ADDRESS SECTION
  Widget _buildAddressSection(
    String title,
    AddressModel address,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
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
          child: Row(
            children: [
              // Map Thumbnail
              Container(
                width: 130,
                height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(
                    icon,
                    size: 40,
                    color: iconColor,
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
                      address.fullAddress,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  // BOTTOM SECTION (Order Summary + Checkout Button)
  Widget _buildBottomSection() {
    final shipping = _deliveryCharge ?? 0.0;
    final total = shipping;

    return Column(
      children: [
        // Shipping Cost
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery charge',
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
        // Total
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 18),
                  children: [
                    const TextSpan(
                      text: '₹ ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFFC8019),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: _deliveryCharge != null && !_isPlacingOrder
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFC8019)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _deliveryCharge == null || _isPlacingOrder
                  ? Colors.grey[300]
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _deliveryCharge != null && !_isPlacingOrder
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFC8019).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _deliveryCharge == null || _isPlacingOrder
                    ? null
                    : _placeOrder,
                child: Center(
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Place Order',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _deliveryCharge != null && !_isPlacingOrder
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                            if (_deliveryCharge != null && !_isPlacingOrder) ...[
                              const SizedBox(width: 8),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(value * 10, 0),
                                    child: Opacity(
                                      opacity: value,
                                      child: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 💳 SHOW PAYMENT METHOD MODAL
  void _showPaymentMethodModal() async {
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
        }
      },
      onAddPaymentMethod: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add payment method coming soon!')),
        );
      },
    );
  }

  // 📦 PLACE TIFFIN ORDER
  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Create Home-to-Office Order
      final order = OrderModel(
        orderId: const Uuid().v4(),
        customerId: authProvider.currentUser!.uid,
        customerName: authProvider.currentUser!.name,
        customerPhone: authProvider.currentUser!.phone,
        cookId: authProvider.currentUser!.uid,
        cookName: '${authProvider.currentUser!.name}\'s Family',
        dishItems: [
          OrderItem(
            dishId: 'tiffin',
            dishName: 'Home-Cooked Tiffin (${DeliveryChargeService.getFormattedDistance(_distance!)})',
            price: 0.0,
            quantity: 1,
          ),
        ],
        total: _deliveryCharge!,
        paymentMethod: _paymentMethod,
        status: OrderStatus.PLACED,
        isHomeToOffice: true,
        pickupAddress: widget.homeAddress.fullAddress,
        pickupLocation: widget.homeAddress.location,
        dropAddress: widget.officeAddress.fullAddress,
        dropLocation: widget.officeAddress.location,
        preferredTime: null,
        createdAt: DateTime.now(),
        isActive: false,
        distanceKm: _distance!,
        deliveryCharge: _deliveryCharge!,
        riderEarning: _riderEarning!,
        platformCommission: _platformCommission!,
        cashCollected: null,
        pendingSettlement: null,
        isSettled: false,
      );

      final savedOrderId = await _firestoreService.createOrder(order);

      if (savedOrderId != null) {
        try {
          await FCMService().notifyNearbyRiders(
            orderId: savedOrderId,
            pickupLat: widget.homeAddress.location.latitude,
            pickupLng: widget.homeAddress.location.longitude,
            radiusKm: 5.0,
          );
        } catch (e) {
          debugPrint('FCM notification failed: $e');
        }

        if (mounted) {
          setState(() => _isPlacingOrder = false);
          
          // Show order success modal
          await OrderSuccessModal.show(
            context,
            onTrackOrder: () {
              Navigator.pushReplacementNamed(
                context,
                AppRouter.findingPartner,
                arguments: {'orderId': savedOrderId},
              );
            },
          );
        }
      } else {
        throw Exception('Failed to create order');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
}
