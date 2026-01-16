import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/delivery_charge_service.dart';
import '../../services/fcm_service.dart';
import '../../models/address_model.dart';
import '../../models/order_model.dart';
import '../../app_router.dart';
import 'package:uuid/uuid.dart';

/// 🏠→🏢 HOME-TO-OFFICE TIFFIN DELIVERY SCREEN
/// 
/// SPECIAL FEATURE: Family member prepares food at home, rider picks up and delivers to office
/// 
/// Flow:
/// 1. Customer selects HOME address (where food is prepared)
/// 2. Customer selects OFFICE address (delivery destination)
/// 3. Customer selects preferred delivery time
/// 4. Order placed with isHomeToOffice = true
/// 5. Rider is ASSIGNED IMMEDIATELY (no cook involved)
/// 6. Rider goes to Home → picks up packed food → delivers to Office

class TiffinOrderScreen extends StatefulWidget {
  const TiffinOrderScreen({super.key});

  @override
  State<TiffinOrderScreen> createState() => _TiffinOrderScreenState();
}

class _TiffinOrderScreenState extends State<TiffinOrderScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  AddressModel? _homeAddress;
  AddressModel? _officeAddress;
  TimeOfDay? _selectedTime;
  
  bool _isLoading = false;
  List<AddressModel> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  /// Load customer's saved addresses
  Future<void> _loadAddresses() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      // getUserAddresses returns a Stream, listen to it
      final subscription = _firestoreService.getUserAddresses(
        authProvider.currentUser!.uid,
      ).listen((addresses) {
        if (mounted) {
          setState(() => _savedAddresses = addresses);
          
          // Auto-select if addresses exist
          for (var addr in addresses) {
            if (addr.label == 'Home' && _homeAddress == null) {
              _homeAddress = addr;
            }
            if (addr.label == 'Office' && _officeAddress == null) {
              _officeAddress = addr;
            }
          }
        }
        setState(() {});
      });
    } catch (e) {
      // Removed print statement for production
      debugPrint('Error loading addresses: $e');
    }
  }

  /// Select Time picker
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFC8019),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  /// Show address selection dialog
  Future<void> _showAddressSelection(String type) async {
    final selected = await showModalBottomSheet<AddressModel>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final typeAddresses = _savedAddresses.where((a) => a.label == type).toList();
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select $type Address',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFFC8019)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRouter.addAddress);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (typeAddresses.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.location_off, size: 60, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text('No $type address saved'),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.addAddress);
                        },
                        child: const Text('Add Address'),
                      ),
                    ],
                  ),
                )
              else
                ...typeAddresses.map((addr) => ListTile(
                      leading: const Icon(Icons.location_on, color: Color(0xFFFC8019)),
                      title: Text(addr.label),
                      subtitle: Text(addr.fullAddress),
                      onTap: () => Navigator.pop(context, addr),
                    )),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        if (type == 'Home') {
          _homeAddress = selected;
        } else {
          _officeAddress = selected;
        }
      });
    }
  }

  /// Place Home-to-Office Tiffin Order
  Future<void> _placeTiffinOrder() async {
    print('🏠 [TiffinOrder] _placeTiffinOrder() called');
    
    // Validation
    if (_homeAddress == null) {
      print('❌ [TiffinOrder] Missing home address');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Home address')),
      );
      return;
    }

    if (_officeAddress == null) {
      print('❌ [TiffinOrder] Missing office address');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Office address')),
      );
      return;
    }

    if (_selectedTime == null) {
      print('❌ [TiffinOrder] Missing delivery time');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select delivery time')),
      );
      return;
    }

    print('🔄 [TiffinOrder] Validation passed, creating order...');
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Calculate delivery charge based on distance
      final deliveryDetails = DeliveryChargeService.calculateDeliveryDetails(
        _homeAddress!.location, // Pickup (home)
        _officeAddress!.location, // Drop (office)
      );

      final deliveryCharge = deliveryDetails['charge']!;
      final distance = deliveryDetails['distance']!;

      // Create preferred time (today with selected time)
      final now = DateTime.now();
      final preferredTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Create Home-to-Office Order
      final order = OrderModel(
        orderId: const Uuid().v4(),
        customerId: authProvider.currentUser!.uid,
        customerName: authProvider.currentUser!.name,
        customerPhone: authProvider.currentUser!.phone,
        cookId: authProvider.currentUser!.uid, // Self (family member)
        cookName: '${authProvider.currentUser!.name}\'s Family',
        dishItems: [
          // No specific dishes - it's home-cooked by family
          OrderItem(
            dishId: 'tiffin',
            dishName: 'Home-Cooked Tiffin (${DeliveryChargeService.getFormattedDistance(distance)})',
            price: 0.0, // No charge for food (family made)
            quantity: 1,
          ),
        ],
        total: deliveryCharge, // Distance-based delivery fee only
        paymentMethod: 'COD',
        status: OrderStatus.PLACED,
        isHomeToOffice: true, // 🔥 KEY FLAG
        pickupAddress: _homeAddress!.fullAddress,
        pickupLocation: _homeAddress!.location,
        dropAddress: _officeAddress!.fullAddress,
        dropLocation: _officeAddress!.location,
        preferredTime: preferredTime,
        createdAt: DateTime.now(),
      );

      // Save order to Firestore
      print('📦 [TiffinOrder] Creating order...');
      final savedOrderId = await _firestoreService.createOrder(order);
      print('📦 [TiffinOrder] Order created with ID: $savedOrderId');

      // 🚀 NOTIFY NEARBY RIDERS VIA FCM
      if (savedOrderId != null) {
        try {
          print('🚀 [TiffinOrder] Starting FCM notification process for order: $savedOrderId');
          print('📍 [TiffinOrder] Pickup location (Home): ${_homeAddress!.location.latitude}, ${_homeAddress!.location.longitude}');
          
          await FCMService().notifyNearbyRiders(
            orderId: savedOrderId,
            pickupLat: _homeAddress!.location.latitude,
            pickupLng: _homeAddress!.location.longitude,
            radiusKm: 5.0,
          );
          
          print('✅ [TiffinOrder] FCM notifications sent to nearby riders');
        } catch (e, stackTrace) {
          print('⚠️ [TiffinOrder] FCM notification failed: $e');
          print('📋 [TiffinOrder] Stack trace: $stackTrace');
        }
      } else {
        print('❌ [TiffinOrder] Order ID is null, cannot send notifications');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        
        // Show success dialog briefly, then auto-navigate to tracking
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/lottie/order_placed.json', height: 150),
                const SizedBox(height: 16),
                const Text(
                  'Tiffin Order Placed!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivery at ${_selectedTime!.format(context)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Finding delivery partner...',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ),
        );

        // Auto-navigate to finding partner screen after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context); // Close dialog
            Navigator.pushReplacementNamed(
              context,
              AppRouter.findingPartner,  // Fixed: Use proper route constant
              arguments: {'orderId': savedOrderId},
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home-to-Office Tiffin'),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: _isLoading
          ? Center(
              child: Lottie.asset('assets/lottie/loading_auth.json', height: 150),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Lottie.asset(
                          'assets/lottie/delivery motorbike.json',
                          height: 80,
                          width: 80,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🏠 → 🏢 Tiffin Delivery',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your family prepares, we deliver to your office!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🏠 HOME ADDRESS SELECTION
                  const Text(
                    '1️⃣ Pickup Location (Home)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.home, color: Colors.green),
                      title: Text(
                        _homeAddress?.label ?? 'Select Home Address',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _homeAddress != null
                          ? Text(_homeAddress!.fullAddress)
                          : const Text('Where food will be picked up'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showAddressSelection('Home'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🏢 OFFICE ADDRESS SELECTION
                  const Text(
                    '2️⃣ Delivery Location (Office)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.business, color: Colors.blue),
                      title: Text(
                        _officeAddress?.label ?? 'Select Office Address',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _officeAddress != null
                          ? Text(_officeAddress!.fullAddress)
                          : const Text('Where you want it delivered'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showAddressSelection('Office'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ⏰ TIME SELECTION
                  const Text(
                    '3️⃣ Preferred Delivery Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFFFC8019)),
                      title: Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Select Time',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text('When do you want it delivered?'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectTime,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Delivery Fee Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Fee: ₹50',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No food charges - it\'s home-cooked by your family!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _placeTiffinOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFC8019),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Place Tiffin Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // How it works
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Your family prepares fresh food at home'),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Rider picks up packed tiffin from your home'),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Delivered to your office on time'),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Track rider in real-time'),
                              ),
                            ],
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
}
