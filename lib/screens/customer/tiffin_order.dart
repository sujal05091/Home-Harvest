import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/address_model.dart';
import '../../app_router.dart';
import 'tiffin_checkout.dart';
import 'select_address.dart';

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
  
  AddressModel? _pickupAddress;
  AddressModel? _deliveryAddress;
  
  bool _isLoading = false;
  List<AddressModel> _savedAddresses = [];
  bool _isHowItWorksExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  /// Navigate to Tiffin Checkout
  void _proceedToCheckout() {
    if (_pickupAddress == null || _deliveryAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both addresses')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TiffinCheckoutScreen(
          homeAddress: _pickupAddress!,
          officeAddress: _deliveryAddress!,
        ),
      ),
    );
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
          
          // Auto-select first two addresses if available
          if (addresses.isNotEmpty && _pickupAddress == null) {
            _pickupAddress = addresses.first;
          }
          if (addresses.length > 1 && _deliveryAddress == null) {
            _deliveryAddress = addresses[1];
          }
        }
        setState(() {});
      });
    } catch (e) {
      // Removed print statement for production
      debugPrint('Error loading addresses: $e');
    }
  }



  /// Navigate to address selection screen
  Future<void> _showAddressSelection(String type) async {
    final selected = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectAddressScreen(),
      ),
    );

    if (selected != null) {
      setState(() {
        if (type == 'Pickup') {
          _pickupAddress = selected;
        } else {
          _deliveryAddress = selected;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Lottie.asset('assets/lottie/loading_auth.json', height: 150),
              )
            : Column(
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
                              'Home-to-Office Tiffin',
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
                            const SizedBox(height: 10),

                            // Lottie Animation
                            Center(
                              child: Lottie.asset(
                                'assets/lottie/home-to-tiffin.json',
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // PICKUP LOCATION BUTTON
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: GestureDetector(
                                onTap: () => _showAddressSelection('Pickup'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: _pickupAddress != null
                                        ? const LinearGradient(
                                            colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: _pickupAddress == null ? Colors.grey[200] : null,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: _pickupAddress != null
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: _pickupAddress != null
                                              ? Colors.white.withOpacity(0.3)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.home_rounded,
                                          size: 32,
                                          color: _pickupAddress != null ? Colors.white : const Color(0xFF4CAF50),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Location Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Pickup Location',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: _pickupAddress != null ? Colors.white : Colors.grey[800],
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                if (_pickupAddress != null) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      '\u2713',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _pickupAddress?.fullAddress ?? 'Tap to select your home address',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _pickupAddress != null 
                                                    ? Colors.white.withOpacity(0.85) 
                                                    : Colors.grey[600],
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 20,
                                        color: _pickupAddress != null ? Colors.white : Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // DELIVERY LOCATION BUTTON
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: GestureDetector(
                                onTap: () => _showAddressSelection('Delivery'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: _deliveryAddress != null
                                        ? const LinearGradient(
                                            colors: [Color(0xFFFF6B35), Color(0xFFFC8019)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: _deliveryAddress == null ? Colors.grey[200] : null,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: _deliveryAddress != null
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFC8019).withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: _deliveryAddress != null
                                              ? Colors.white.withOpacity(0.3)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.work_rounded,
                                          size: 32,
                                          color: _deliveryAddress != null ? Colors.white : const Color(0xFFFC8019),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Location Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Delivery Location',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: _deliveryAddress != null ? Colors.white : Colors.grey[800],
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                if (_deliveryAddress != null) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.25),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      '\u2713',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _deliveryAddress?.fullAddress ?? 'Tap to select your office address',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _deliveryAddress != null 
                                                    ? Colors.white.withOpacity(0.85) 
                                                    : Colors.grey[600],
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 20,
                                        color: _deliveryAddress != null ? Colors.white : Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // How it works Section (Collapsible)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    // Header - Always visible with dropdown arrow
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          setState(() {
                                            _isHowItWorksExpanded = !_isHowItWorksExpanded;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                color: Colors.orange[600],
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              const Expanded(
                                                child: Text(
                                                  'How it works',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              AnimatedRotation(
                                                turns: _isHowItWorksExpanded ? 0.5 : 0,
                                                duration: const Duration(milliseconds: 300),
                                                child: Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Colors.grey[600],
                                                  size: 28,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Content - Collapsible
                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                        child: Column(
                                          children: [
                                            _buildHowItWorksStep(
                                              Icons.restaurant_menu,
                                              'Your family prepares fresh food at home',
                                            ),
                                            const SizedBox(height: 12),
                                            _buildHowItWorksStep(
                                              Icons.two_wheeler,
                                              'Rider picks up packed tiffin from home',
                                            ),
                                            const SizedBox(height: 12),
                                            _buildHowItWorksStep(
                                              Icons.business,
                                              'Delivered to your office',
                                            ),
                                            const SizedBox(height: 12),
                                            _buildHowItWorksStep(
                                              Icons.track_changes,
                                              'Track rider in real-time',
                                            ),
                                          ],
                                        ),
                                      ),
                                      crossFadeState: _isHowItWorksExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 300),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Continue to Checkout Button (Fixed at bottom)
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _pickupAddress != null && _deliveryAddress != null
                            ? const LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFC8019)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _pickupAddress == null || _deliveryAddress == null
                            ? Colors.grey[300]
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _pickupAddress != null && _deliveryAddress != null
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
                          onTap: _pickupAddress == null || _deliveryAddress == null
                              ? null
                              : _proceedToCheckout,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Proceed to Checkout',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _pickupAddress != null && _deliveryAddress != null
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (_pickupAddress != null && _deliveryAddress != null) ...[
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
                                            Icons.arrow_forward_rounded,
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
              ),
      ),
    );
  }

  Widget _buildHowItWorksStep(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.green,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}
