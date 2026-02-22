import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;
import '../../models/order_model.dart';
import '../../widgets/osm_map_widget.dart';
import '../../app_router.dart';
import 'premium_tracking_screen.dart';

/// Finding Delivery Partner Screen
/// Shows a loading state while backend searches for available riders
/// Auto-navigates to live tracking once rider accepts (RIDER_ACCEPTED status)
class FindingPartnerScreen extends StatefulWidget {
  final String orderId;

  const FindingPartnerScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<FindingPartnerScreen> createState() => _FindingPartnerScreenState();
}

class _FindingPartnerScreenState extends State<FindingPartnerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<Marker> _markers = [];
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  bool _showTimeoutMessage = false;
  int _elapsedSeconds = 0;
  bool _hasNavigated = false; // Prevent multiple navigation calls

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Start timeout timer (2 minutes = 120 seconds)
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    Future.delayed(const Duration(seconds: 5), () {  // Changed from 1s to 5s
      if (!mounted) return;
      
      setState(() {
        _elapsedSeconds += 5;  // Increment by 5
      });

      // Show timeout message after 2 minutes (120 seconds)
      if (_elapsedSeconds >= 120) {
        if (mounted) {
          setState(() {
            _showTimeoutMessage = true;
          });
        }
      } else {
        _startTimeoutTimer();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateMap(OrderModel order) {
    _pickupLatLng = LatLng(
      order.pickupLocation.latitude,
      order.pickupLocation.longitude,
    );
    _dropLatLng = LatLng(
      order.dropLocation.latitude,
      order.dropLocation.longitude,
    );

    // Update markers without setState - StreamBuilder will rebuild automatically
    _markers = [
      MarkerHelper.createPickupMarker(
        _pickupLatLng!,
        order.isHomeToOffice ? 'Home Pickup' : order.cookName,
      ),
      MarkerHelper.createDropMarker(
        _dropLatLng!,
        order.isHomeToOffice ? 'Office Drop' : 'Delivery Location',
      ),
    ];
  }

  void _navigateToLiveTracking() {
    // Navigate to PREMIUM live tracking screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PremiumTrackingScreen(orderId: widget.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots()
            .distinct((prev, next) {
              // Only rebuild if status or rider assignment changes
              if (!prev.exists || !next.exists) return false;
              final prevData = prev.data() as Map<String, dynamic>?;
              final nextData = next.data() as Map<String, dynamic>?;
              if (prevData == null || nextData == null) return false;
              return prevData['status'] != nextData['status'] || 
                     prevData['assignedRiderId'] != nextData['assignedRiderId'];
            }),
        builder: (context, snapshot) {
          // Log stream connection state
          print('🌊 [FindingPartner] StreamBuilder state: ${snapshot.connectionState}');
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('❌ [FindingPartner] Stream error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            print('❌ [FindingPartner] No data or document does not exist');
            return const Center(child: Text('Order not found'));
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          
          // Log raw status from Firestore
          print('📄 [FindingPartner] Raw Firestore status: ${orderData['status']}');
          print('📄 [FindingPartner] Raw data: $orderData');
          
          final order = OrderModel.fromMap(orderData, widget.orderId);

          // Debug log parsed order
          print('🔍 [FindingPartner] Order ID: ${widget.orderId}');
          print('🔍 [FindingPartner] Parsed status: ${order.status.name}');
          print('🔍 [FindingPartner] Status index: ${order.status.index}');
          print('🔍 [FindingPartner] Assigned Rider: ${order.assignedRiderId}');
          print('🔍 [FindingPartner] Rider Name: ${order.assignedRiderName}');
          print('🔍 [FindingPartner] Has navigated: $_hasNavigated');

          // Update map markers
          if (_markers.isEmpty) {
            _updateMap(order);
          }

          // Auto-navigate when rider accepts (only once)
          if (!_hasNavigated && 
              (order.status == OrderStatus.RIDER_ASSIGNED ||
               order.status == OrderStatus.RIDER_ACCEPTED ||
               order.status == OrderStatus.ON_THE_WAY_TO_PICKUP ||
               order.status == OrderStatus.PICKED_UP ||
               order.status == OrderStatus.ON_THE_WAY_TO_DROP)) {
            print('✅ [FindingPartner] Status changed to ${order.status.name}!');
            print('✅ [FindingPartner] Navigating to live tracking screen...');
            _hasNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _navigateToLiveTracking();
              }
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Rider Accepted! Loading tracking...', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          // Show cancelled state
          if (order.status == OrderStatus.CANCELLED) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, size: 80, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Order Cancelled',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.cancellationReason ?? 'No reason provided',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            );
          }

          // 🍕 NORMAL FOOD WORKFLOW STAGES - Show different UI based on status
          // isHomeToOffice = true means Tiffin, false means Normal Food
          final isNormalFood = !order.isHomeToOffice;
          String stageTitle = '';
          String stageDescription = '';
          String lottieAsset = 'assets/lottie/delivery motorbike.json';
          Color stageColor = const Color(0xFFFF6B35);

          if (isNormalFood) {
            if (order.status == OrderStatus.PLACED) {
              // Stage 1: Waiting for cook to accept
              stageTitle = 'Waiting for Cook';
              stageDescription = 'Cook will accept your order soon...';
              lottieAsset = 'assets/lottie/cooking.json';
              stageColor = Colors.orange;
            } else if (order.status == OrderStatus.ACCEPTED) {
              // Stage 2: Cook accepted, starting to prepare
              stageTitle = '✅ Cook Accepted!';
              stageDescription = 'Cook is getting ready to prepare your food';
              lottieAsset = 'assets/lottie/cooking.json';
              stageColor = Colors.green;
            } else if (order.status == OrderStatus.PREPARING) {
              // Stage 3: Cook is preparing
              stageTitle = '👨‍🍳 Cook is Preparing';
              stageDescription = 'Your delicious food is being prepared with care';
              lottieAsset = 'assets/lottie/cooking.json';
              stageColor = Colors.blue;
            } else if (order.status == OrderStatus.READY) {
              // Stage 4: Food ready, finding rider
              stageTitle = 'Finding Delivery Partner';
              stageDescription = 'Searching for nearest rider to deliver your food';
              lottieAsset = 'assets/lottie/delivery motorbike.json';
              stageColor = const Color(0xFFFF6B35);
            } else {
              // Fallback for other statuses
              stageTitle = 'Processing Order';
              stageDescription = 'Please wait...';
            }
          } else {
            // TIFFIN orders: directly find rider (no cook involved)
            stageTitle = 'Finding Delivery Partner';
            stageDescription = 'Searching for nearest rider for your tiffin';
            lottieAsset = 'assets/lottie/delivery motorbike.json';
            stageColor = const Color(0xFFFF6B35);
          }

          return Stack(
            children: [
              // Map showing pickup and drop locations (Isolated to prevent rebuilds)
              if (_pickupLatLng != null && _dropLatLng != null)
                RepaintBoundary(
                  child: OSMMapWidget(
                    key: ValueKey('${_pickupLatLng?.latitude}_${_pickupLatLng?.longitude}'),
                    markers: _markers,
                    polylines: [],
                    center: _pickupLatLng!,
                    zoom: 13,
                  ),
                ),

              // Dark overlay
              Container(
                color: Colors.black.withOpacity(0.5),
              ),

              // Finding partner UI
              SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Finding Delivery Partner',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Center content
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lottie animation (dynamic based on stage)
                          SizedBox(
                            height: 150,
                            child: Lottie.asset(
                              lottieAsset,
                              controller: _animationController,
                              fit: BoxFit.contain,
                              onWarning: (warning) {
                                print('⚠️ Lottie warning: $warning');
                              },
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to delivery animation if cooking.json not available
                                return Lottie.asset(
                                  'assets/lottie/delivery motorbike.json',
                                  controller: _animationController,
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Status text (dynamic based on stage)
                          Text(
                            stageTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: stageColor,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            stageDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Loading indicator (stateless - no setState rebuild)
                          TweenAnimationBuilder<double>(
                            key: ValueKey(_elapsedSeconds),  // Force rebuild when counter changes
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(seconds: 5),  // Match timer duration
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.orange[100],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF6B35),
                                ),
                              );
                            },
                            // Removed onEnd - let timer handle rebuilds
                          ),

                          const SizedBox(height: 24),

                          // Timeout message (shown after 2 minutes)
                          if (_showTimeoutMessage)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Still finding partner...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'High demand right now. We\'re trying our best!',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Order details
                          _buildInfoRow(
                            Icons.restaurant,
                            'From',
                            order.isHomeToOffice ? 'Home' : order.cookName,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.location_on,
                            'To',
                            order.isHomeToOffice
                                ? 'Office'
                                : order.dropAddress.split(',').first,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.shopping_bag,
                            'Items',
                            '${order.dishItems.length} items',
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Bottom info
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Estimated wait time: 2-3 minutes',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFF6B35)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3142),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
