import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/order_model.dart';
import '../../models/delivery_model.dart';
import '../../services/rider_location_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/osm_map_widget.dart';
import '../../app_router.dart';

/// 🌟 Modern Full-Screen Delivery Request Page
/// Swipeable, immersive design with animations
class RiderDeliveryRequestModernScreen extends StatefulWidget {
  final String orderId;

  const RiderDeliveryRequestModernScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<RiderDeliveryRequestModernScreen> createState() =>
      _RiderDeliveryRequestModernScreenState();
}

class _RiderDeliveryRequestModernScreenState
    extends State<RiderDeliveryRequestModernScreen>
    with TickerProviderStateMixin {
  final RiderLocationService _locationService = RiderLocationService();
  bool _isLoading = false;
  bool _isAccepting = false;
  bool _isRejecting = false;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
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

    setState(() {
      _markers = [
        MarkerHelper.createPickupMarker(
          _pickupLatLng!,
          order.isHomeToOffice ? 'Home Pickup' : order.cookName,
        ),
        MarkerHelper.createDropMarker(
          _dropLatLng!,
          order.isHomeToOffice ? 'Office Drop' : 'Drop Location',
        ),
      ];

      _polylines = [
        PolylineHelper.createRoute(points: [_pickupLatLng!, _dropLatLng!]),
      ];
    });
  }

  /// 🔒 PRODUCTION-SAFE: Accept delivery with Firestore transaction
  /// Prevents multiple riders from accepting the same order
  Future<void> _acceptDelivery(OrderModel order) async {
    setState(() {
      _isAccepting = true;
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      // Get rider info
      final riderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!riderDoc.exists) throw 'Rider profile not found';

      final riderData = riderDoc.data()!;
      final riderName = riderData['name'] ?? 'Unknown';
      final riderPhone = riderData['phone'] ?? '';

      // 🔒 Use transaction to prevent race conditions
      final firestoreService = FirestoreService();
      final success = await firestoreService.acceptOrderAsRider(
        orderId: widget.orderId,
        riderId: currentUser.uid,
        riderName: riderName,
        riderPhone: riderPhone,
      );

      if (!success) {
        // Order already taken by another rider
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Order already taken by another rider'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context); // Go back to available orders
        }
        return;
      }

      // ✅ Order successfully accepted, set up tracking and delivery
      
      // Get rider's current location immediately
      GeoPoint? currentLocation;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        currentLocation = GeoPoint(position.latitude, position.longitude);
        print('📍 [Accept] Got rider location: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('⚠️ [Accept] Could not get rider location: $e');
        currentLocation = GeoPoint(0, 0);
      }
      
      // Initialize rider location tracking
      final riderLocationRef = FirebaseFirestore.instance
          .collection('rider_locations')
          .doc(currentUser.uid);

      await riderLocationRef.set({
        'riderId': currentUser.uid,
        'orderId': widget.orderId,
        'location': currentLocation,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create or update delivery document with rider's current location
      final deliveryRef = FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.orderId);

      final deliveryDoc = await deliveryRef.get();

      if (deliveryDoc.exists) {
        await deliveryRef.update({
          'status': DeliveryStatus.ACCEPTED.name,
          'riderId': currentUser.uid,
          'riderName': riderName,
          'riderPhone': riderPhone,
          'currentLocation': currentLocation,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      } else {
        await deliveryRef.set({
          'deliveryId': widget.orderId,
          'orderId': widget.orderId,
          'riderId': currentUser.uid,
          'riderName': riderName,
          'riderPhone': riderPhone,
          'customerId': order.customerId,
          'cookId': order.cookId,
          'status': DeliveryStatus.ACCEPTED.name,
          'pickupLocation': order.pickupLocation,
          'dropLocation': order.dropLocation,
          'currentLocation': currentLocation,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'deliveryFee': order.deliveryCharge ?? 40.0,
          'distanceKm': order.distanceKm ?? 0.0,
          'assignedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }

      // Start GPS tracking
      await _locationService.startTracking(
        riderId: currentUser.uid,
        orderId: widget.orderId,
        onLocationUpdate: (location) {},
      );

      print('🚀 [Rider] Order accepted successfully, navigating to active delivery screen');

      if (mounted) {
        // 🚀 Navigate to active delivery screen
        Navigator.pushReplacementNamed(
          context,
          AppRouter.riderActiveDelivery,
          arguments: {
            'order': order,
          },
        );
      }
    } catch (e) {
      print('❌ [Rider] Error accepting delivery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rejectDelivery() async {
    setState(() {
      _isRejecting = true;
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': OrderStatus.PLACED.name,
        'assignedRiderId': FieldValue.delete(),
        'assignedRiderName': FieldValue.delete(),
        'assignedRiderPhone': FieldValue.delete(),
        'assignedAt': FieldValue.delete(),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRejecting = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Order not found',
                      style: GoogleFonts.poppins(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final order = OrderModel.fromMap(orderData, widget.orderId);

          if (_markers.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMap(order);
              }
            });
          }

          final distanceKm = _locationService.calculateDistance(
            order.pickupLocation.latitude,
            order.pickupLocation.longitude,
            order.dropLocation.latitude,
            order.dropLocation.longitude,
          );

          final deliveryFee = order.riderEarning ??
              (order.deliveryCharge != null ? order.deliveryCharge! * 0.8 : 0.0);

          return Stack(
            children: [
              // Map Background (Blurred)
              if (_pickupLatLng != null && _dropLatLng != null)
                Positioned.fill(
                  child: OSMMapWidget(
                    markers: _markers,
                    polylines: _polylines,
                    center: _pickupLatLng!,
                    zoom: 13,
                  ),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFC8019),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFC8019).withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'NEW REQUEST',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Main Content Card
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Earnings Highlight
                            Container(
                              padding: const EdgeInsets.all(30),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFC8019), Color(0xFFFF9D3D)],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'You\'ll Earn',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₹${deliveryFee.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'From this delivery',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Order Details
                            Padding(
                              padding: const EdgeInsets.all(25),
                              child: Column(
                                children: [
                                  // Customer Info
                                  _buildInfoRow(
                                    Icons.person_outline,
                                    'Customer',
                                    order.customerName ?? 'Customer',
                                    const Color(0xFF2196F3),
                                  ),
                                  const SizedBox(height: 20),

                                  // Distance
                                  _buildInfoRow(
                                    Icons.social_distance_outlined,
                                    'Distance',
                                    '${distanceKm.toStringAsFixed(1)} km',
                                    const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(height: 20),

                                  // Pickup Location
                                  _buildInfoRow(
                                    Icons.location_on_outlined,
                                    'Pickup from',
                                    order.pickupAddress ??
                                        (order.isHomeToOffice
                                            ? 'Home'
                                            : order.cookName),
                                    const Color(0xFFFF9800),
                                  ),
                                  const SizedBox(height: 20),

                                  // Drop Location
                                  _buildInfoRow(
                                    Icons.place_outlined,
                                    'Drop at',
                                    order.dropAddress ??
                                        (order.isHomeToOffice ? 'Office' : 'Customer'),
                                    const Color(0xFFE91E63),
                                  ),

                                  const SizedBox(height: 30),

                                  // Action Buttons
                                  Row(
                                    children: [
                                      // Reject Button
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _rejectDelivery,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[200],
                                            foregroundColor: Colors.grey[700],
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: _isRejecting
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.grey),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.close, size: 20),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Decline',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),

                                      const SizedBox(width: 15),

                                      // Accept Button
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : () => _acceptDelivery(order),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFC8019),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 5,
                                            shadowColor:
                                                const Color(0xFFFC8019).withOpacity(0.5),
                                          ),
                                          child: _isAccepting
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.white),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.check_circle, size: 22),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Accept Delivery',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C3E50),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
