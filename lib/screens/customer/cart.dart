import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dishes_provider.dart';
import '../../models/order_model.dart';
import '../../models/address_model.dart';
import '../../models/dish_model.dart';
import '../../app_router.dart';
import '../../services/delivery_charge_service.dart';
import '../../services/fcm_service.dart';
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
  bool _isLoadingDetails = false;

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<OrdersProvider>(context);

    if (ordersProvider.cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
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
                child: const Text('Browse Dishes'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: ordersProvider.cartItems.length,
              itemBuilder: (context, index) {
                final item = ordersProvider.cartItems[index];
                return ListTile(
                  title: Text(item.dishName),
                  subtitle: Text('₹${item.price} x ${item.quantity}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => ordersProvider.removeFromCart(item.dishId),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.grey.shade300, blurRadius: 5)
              ],
            ),
            child: Column(
              children: [
                // Item Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Item Total:', style: TextStyle(fontSize: 16)),
                    Text(
                      '₹${ordersProvider.cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                
                // Delivery Charge (if address selected)
                if (_deliveryCharge != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Delivery Charge:', style: TextStyle(fontSize: 16)),
                          if (_distance != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${DeliveryChargeService.getFormattedDistance(_distance!)})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '₹${_deliveryCharge!.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total to Pay:',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${(ordersProvider.cartTotal + _deliveryCharge!).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFC8019),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress == null
                        ? 'Select address to see delivery charge'
                        : 'Calculating delivery charge...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Select Address Button (if no address selected)
                if (_selectedAddress == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.location_on),
                      label: const Text('Select Delivery Address'),
                      onPressed: _selectAddress,
                    ),
                  )
                else ...[
                  // Show selected address
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedAddress!.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                _selectedAddress!.fullAddress,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _selectAddress,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingDetails || _deliveryCharge == null
                          ? null
                          : _placeOrder,
                      child: _isLoadingDetails
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Place Order'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
      // Get first dish details (cook location)
      final dish = await dishesProvider.getDishById(
        ordersProvider.cartItems.first.dishId
      );

      if (dish == null || _selectedAddress == null) {
        throw Exception('Failed to load details');
      }

      // Calculate delivery distance and charge
      final deliveryDetails = DeliveryChargeService.calculateDeliveryDetails(
        dish.location, // Cook's location (pickup)
        _selectedAddress!.location, // Customer's address (drop)
      );

      setState(() {
        _firstDish = dish;
        _distance = deliveryDetails['distance'];
        _deliveryCharge = deliveryDetails['charge'];
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
      } else {
        print('❌ [Cart] Order ID is null or widget not mounted!');
      }
    } catch (e) {
      setState(() => _isLoadingDetails = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    }
  }
}
