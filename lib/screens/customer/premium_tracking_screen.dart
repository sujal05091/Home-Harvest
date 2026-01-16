import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../models/delivery_model.dart';
import '../../widgets/animated_rider_marker.dart';
import '../../widgets/animated_status_card.dart';
import '../../services/route_service.dart';

/// 🚀 PREMIUM CUSTOMER TRACKING SCREEN
/// Swiggy-level quality with smooth animations, modern UI
class PremiumTrackingScreen extends StatefulWidget {
  final String orderId;

  const PremiumTrackingScreen({super.key, required this.orderId});

  @override
  State<PremiumTrackingScreen> createState() => _PremiumTrackingScreenState();
}

class _PremiumTrackingScreenState extends State<PremiumTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  // Rider tracking
  LatLng? _riderPosition;
  LatLng? _previousRiderPosition;
  double _riderBearing = 0;
  
  // Locations
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  
  // Route points (Phase A: dotted, Phase B: road-based)
  List<LatLng> _routePoints = [];
  bool _isRiderAccepted = false;
  bool _isLoadingRoute = false;
  OrderStatus? _lastLoadedStatus;  // Track last loaded status to prevent duplicate loads
  
  // Animation controllers
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;
  late AnimationController _routeAnimationController;
  late Animation<double> _routeAnimation;
  
  // Auto-update timer
  Timer? _mapUpdateTimer;
  
  // Bottom sheet state
  bool _isBottomSheetExpanded = false;

  @override
  void initState() {
    super.initState();
    
    // Bottom sheet animation
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation = Tween<double>(begin: 0.25, end: 0.6).animate(
      CurvedAnimation(parent: _bottomSheetController, curve: Curves.easeInOut),
    );
    
    // Route drawing animation
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _routeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Auto-adjust map view every 5 seconds (performance optimized)
    _mapUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _adjustMapView();
    });
  }

  @override
  void dispose() {
    _bottomSheetController.dispose();
    _routeAnimationController.dispose();
    _mapUpdateTimer?.cancel();
    super.dispose();
  }

  /// Load route based on order status
  /// Phase A: Curved dotted line (before rider accepts)
  /// Phase B: Road-based solid line (after rider accepts)
  Future<void> _loadRoute(OrderStatus status) async {
    if (_pickupLocation == null || _dropLocation == null) return;
    
    // Skip if already loading or if we already loaded this status
    if (_isLoadingRoute) return;
    if (_lastLoadedStatus == status) return;  // Prevent duplicate loads for same status
    if (status.index < OrderStatus.RIDER_ACCEPTED.index && _routePoints.isNotEmpty && !_isRiderAccepted) return;
    if (status.index >= OrderStatus.RIDER_ACCEPTED.index && _isRiderAccepted && _routePoints.isNotEmpty) return;
    
    setState(() {
      _isLoadingRoute = true;
      _lastLoadedStatus = status;  // Mark this status as loaded
    });
    
    try {
      // PHASE A: Before rider accepts - show curved dotted line
      if (status.index < OrderStatus.RIDER_ACCEPTED.index) {
        if (_routePoints.isEmpty) {
          final curvedRoute = RouteService.generateCurvedRoute(
            start: _pickupLocation!,
            end: _dropLocation!,
            segments: 50,
          );
          
          setState(() {
            _routePoints = curvedRoute;
            _isRiderAccepted = false;
          });
          
          // Animate route drawing
          _routeAnimationController.forward(from: 0);
        }
      }
      // PHASE B: After rider accepts - fetch road-based route
      else {
        if (!_isRiderAccepted && _riderPosition != null) {
          // Fetch road route: Rider → Pickup → Drop
          final roadRoute = await RouteService.getMultiWaypointRoute(
            riderLocation: _riderPosition!,
            pickupLocation: _pickupLocation!,
            dropLocation: _dropLocation!,
          );
          
          setState(() {
            _routePoints = roadRoute;
            _isRiderAccepted = true;
          });
          
          // Animate route drawing
          _routeAnimationController.forward(from: 0);
        }
      }
    } catch (e) {
      print('❌ Route loading error: $e');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  /// Calculate distance between two coordinates (in km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * (pi / 180);
    final lat2 = to.latitude * (pi / 180);
    final dLng = (to.longitude - from.longitude) * (pi / 180);

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    
    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360;
  }

  /// Auto-adjust map to show all markers
  void _adjustMapView() {
    if (_riderPosition == null || _dropLocation == null) return;

    final bounds = LatLngBounds.fromPoints([
      _riderPosition!,
      _dropLocation!,
      if (_pickupLocation != null) _pickupLocation!,
    ]);

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (e) {
      print('Error adjusting map: $e');
    }
  }

  /// Call rider
  Future<void> _callRider(String? phone) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            'Order #${widget.orderId.substring(0, 8)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots()
            .distinct((prev, next) => 
              prev.data().toString() == next.data().toString()),  // Prevent duplicate rebuilds
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orderData = orderSnapshot.data!.data() as Map<String, dynamic>?;
          if (orderData == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = OrderModel.fromMap(orderData, widget.orderId);
          
          // Update locations
          if (order.pickupLocation != null) {
            _pickupLocation = LatLng(
              order.pickupLocation!.latitude,
              order.pickupLocation!.longitude,
            );
          }
          if (order.dropLocation != null) {
            _dropLocation = LatLng(
              order.dropLocation!.latitude,
              order.dropLocation!.longitude,
            );
          }
          
          // Load route based on order status (ONLY if status changed)
          if (_lastLoadedStatus != order.status) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadRoute(order.status);
            });
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('deliveries')
                .doc(widget.orderId)
                .snapshots()
                .distinct((prev, next) {
                  // Only rebuild if location actually changed (optimization)
                  if (!prev.exists || !next.exists) return false;
                  final prevData = prev.data() as Map<String, dynamic>?;
                  final nextData = next.data() as Map<String, dynamic>?;
                  if (prevData == null || nextData == null) return false;
                  final prevLoc = prevData['currentLocation'] as GeoPoint?;
                  final nextLoc = nextData['currentLocation'] as GeoPoint?;
                  if (prevLoc == null || nextLoc == null) return true;
                  // Consider locations same if within 5 meters
                  final distance = _calculateDistance(
                    prevLoc.latitude, prevLoc.longitude,
                    nextLoc.latitude, nextLoc.longitude,
                  );
                  return distance > 0.005; // ~5 meters
                }),
            builder: (context, deliverySnapshot) {
              DeliveryModel? delivery;
              if (deliverySnapshot.hasData && deliverySnapshot.data!.exists) {
                final deliveryData = deliverySnapshot.data!.data() as Map<String, dynamic>;
                delivery = DeliveryModel.fromMap(deliveryData, widget.orderId);
                
                // Update rider position
                if (delivery.currentLocation != null) {
                  final newPosition = LatLng(
                    delivery.currentLocation!.latitude,
                    delivery.currentLocation!.longitude,
                  );
                  
                  // Calculate bearing if position changed
                  if (_riderPosition != null) {
                    _riderBearing = _calculateBearing(_riderPosition!, newPosition);
                    _previousRiderPosition = _riderPosition;
                  }
                  
                  _riderPosition = newPosition;
                }
              }

              return Stack(
                children: [
                  // 🗺️ FULL-SCREEN MAP (Isolated with RepaintBoundary)
                  RepaintBoundary(
                    child: _buildMap(order, delivery),
                  ),
                  
                  // 📊 STATUS CARD (Top)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: AnimatedStatusCard(
                      status: order.status,
                      riderId: order.assignedRiderId,
                      riderName: order.assignedRiderName,
                      etaMinutes: delivery?.estimatedMinutes,
                      onCallRider: () => _callRider(order.assignedRiderPhone),
                    ),
                  ),
                  
                  // 📱 BOTTOM SHEET
                  _buildBottomSheet(order, delivery),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Build map widget
  Widget _buildMap(OrderModel order, DeliveryModel? delivery) {
    List<Marker> markers = [];
    
    // Add pickup marker
    if (_pickupLocation != null) {
      markers.add(CustomMapMarkers.createHomeMarker(
        _pickupLocation!,
        order.isHomeToOffice ? 'Home' : order.cookName,
      ));
    }
    
    // Add drop marker
    if (_dropLocation != null) {
      markers.add(CustomMapMarkers.createCustomerMarker(
        _dropLocation!,
        order.isHomeToOffice ? 'Office' : 'Delivery',
      ));
    }
    
    // Add animated rider marker
    if (_riderPosition != null &&
        order.status.index >= OrderStatus.RIDER_ACCEPTED.index) {
      markers.add(
        AnimatedRiderMarker.create(
          currentPosition: _riderPosition!,
          targetPosition: _previousRiderPosition,
          bearing: _riderBearing,
          riderId: order.assignedRiderId ?? '',
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _riderPosition ?? _pickupLocation ?? const LatLng(0, 0),
        initialZoom: 14,
        minZoom: 10,
        maxZoom: 18,
        // Performance optimizations
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Disable rotation for performance
        ),
      ),
      children: [
        // Modern tile layer (CartoDB Positron - Clean style)
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.home_harvest_app',
          // Performance optimizations
          keepBuffer: 2,  // Reduce buffer to save memory
          panBuffer: 1,   // Reduce pan buffer
          maxNativeZoom: 18,
        ),
        
        // TWO-PHASE ROUTE POLYLINE
        if (_routePoints.isNotEmpty)
          AnimatedBuilder(
            animation: _routeAnimation,
            builder: (context, child) {
              // Calculate visible points based on animation progress
              final visiblePoints = (_routePoints.length * _routeAnimation.value).round();
              final animatedPoints = _routePoints.take(visiblePoints.clamp(2, _routePoints.length)).toList();
              
              if (animatedPoints.length < 2) {
                return const SizedBox.shrink();
              }
              
              return PolylineLayer(
                polylines: [
                  Polyline(
                    points: animatedPoints,
                    strokeWidth: _isRiderAccepted ? 4.0 : 3.0,
                    // PHASE A: Orange color (before rider accepts)
                    // PHASE B: Gradient color (after rider accepts)
                    color: const Color(0xFFFF7A00),
                    gradientColors: _isRiderAccepted 
                        ? [const Color(0xFFFF7A00), Colors.green]
                        : null,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white.withOpacity(0.8),
                  ),
                ],
              );
            },
          ),
        
        // Markers
        MarkerLayer(markers: markers),
      ],
    );
  }

  /// Build bottom sheet
  Widget _buildBottomSheet(OrderModel order, DeliveryModel? delivery) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < -5 && !_isBottomSheetExpanded) {
            setState(() => _isBottomSheetExpanded = true);
            _bottomSheetController.forward();
          } else if (details.primaryDelta! > 5 && _isBottomSheetExpanded) {
            setState(() => _isBottomSheetExpanded = false);
            _bottomSheetController.reverse();
          }
        },
        child: AnimatedBuilder(
          animation: _bottomSheetAnimation,
          builder: (context, child) {
            return Container(
              height: MediaQuery.of(context).size.height * _bottomSheetAnimation.value,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rider info
                          if (order.assignedRiderName != null) ...[
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFFFC8019),
                                  child: Text(
                                    order.assignedRiderName![0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.assignedRiderName!,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Your Delivery Partner',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (order.assignedRiderPhone != null)
                                  IconButton(
                                    icon: const Icon(Icons.phone, color: Color(0xFFFC8019)),
                                    onPressed: () => _callRider(order.assignedRiderPhone),
                                  ),
                              ],
                            ),
                            const Divider(height: 32),
                          ],
                          
                          // ETA
                          if (delivery?.estimatedMinutes != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFC8019).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: Color(0xFFFC8019),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Estimated Time',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${delivery!.estimatedMinutes} mins',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFC8019),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // Timeline
                          const Text(
                            'Order Progress',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OrderTimeline(currentStatus: order.status),
                          
                          // Order details
                          const SizedBox(height: 20),
                          const Text(
                            'Delivery Addresses',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildAddressCard(
                            'Pickup',
                            order.pickupAddress,
                            Icons.home,
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                          _buildAddressCard(
                            'Drop',
                            order.dropAddress,
                            Icons.location_on,
                            const Color(0xFFFC8019),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    String label,
    String address,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
