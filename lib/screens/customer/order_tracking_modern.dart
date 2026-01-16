import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/osm_maps_service.dart';
import '../../models/order_model.dart';
import '../../models/delivery_model.dart';
import '../../widgets/osm_map_widget.dart';
import 'dart:async';

/// 🎨 MODERN ORDER TRACKING - Premium Swiggy/Zomato Style UI
/// 
/// Features:
/// - Clean CartoDB map tiles
/// - Premium custom markers with gradients
/// - Smooth route polyline with border
/// - Bottom sheet overlay (not split screen)
/// - Real-time delivery tracking
/// - Distance & ETA in gradient card
/// - Modern status indicators
class OrderTrackingModernScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingModernScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingModernScreen> createState() => _OrderTrackingModernScreenState();
}

class _OrderTrackingModernScreenState extends State<OrderTrackingModernScreen> {
  final MapController _mapController = MapController();
  final OSMMapsService _mapsService = OSMMapsService();
  final FirestoreService _firestoreService = FirestoreService();
  
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  String? _distanceText;
  String? _etaText;
  StreamSubscription<GeoPoint?>? _locationSubscription;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Update map with order and delivery data
  void _updateMap(OrderModel order, DeliveryModel? delivery) {
    final pickup = LatLng(
      order.pickupLocation.latitude,
      order.pickupLocation.longitude,
    );

    final drop = LatLng(
      order.dropLocation.latitude,
      order.dropLocation.longitude,
    );

    _markers = [
      MarkerHelper.createPickupMarker(pickup, 'Cook'),
      MarkerHelper.createDropMarker(drop, 'You'),
    ];

    // Add delivery partner marker if assigned
    if (delivery?.currentLocation != null) {
      final riderLocation = LatLng(
        delivery!.currentLocation!.latitude,
        delivery.currentLocation!.longitude,
      );
      _markers.add(MarkerHelper.createDeliveryMarker(riderLocation));

      // Calculate distance & ETA
      final distanceKm = _mapsService.calculateDistance(riderLocation, drop);
      final eta = _mapsService.calculateEstimatedTime(distanceKm);
      
      setState(() {
        _distanceText = '${distanceKm.toStringAsFixed(1)} km';
        _etaText = eta;
      });
    }

    // Create route polyline
    _polylines = [
      PolylineHelper.createRoute(
        points: [pickup, drop],
        color: const Color(0xFFFC8019),
        width: 5.0,
      ),
    ];

    // Fit map to show all markers with padding
    _fitMapBounds([pickup, drop]);

    setState(() {});
  }

  /// Smooth camera animation to fit all markers
  void _fitMapBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // Smooth move with appropriate zoom
    _mapController.move(center, 13.5);
  }

  /// Navigate to user's current location
  void _goToMyLocation() async {
    final myLocation = await _mapsService.getCurrentLocation();
    if (myLocation != null) {
      _mapController.move(myLocation, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Track Your Order',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<OrderModel?>(
        stream: _firestoreService.getOrderById(widget.orderId),
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = orderSnapshot.data!;

          return StreamBuilder<DeliveryModel?>(
            stream: _firestoreService.getDeliveryByOrderId(widget.orderId),
            builder: (context, deliverySnapshot) {
              final delivery = deliverySnapshot.data;

              // Listen to real-time location updates
              if (delivery != null && _locationSubscription == null) {
                _locationSubscription = _mapsService
                    .listenToDeliveryLocation(delivery.deliveryId)
                    .listen((geoPoint) {
                  if (geoPoint != null) {
                    _updateMap(order, delivery);
                  }
                });
              }

              // Update map when data changes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateMap(order, delivery);
              });

              return Stack(
                children: [
                  // 🗺️ FULL-SCREEN MAP
                  OSMMapWidget(
                    center: LatLng(
                      order.pickupLocation.latitude,
                      order.pickupLocation.longitude,
                    ),
                    zoom: 13.0,
                    markers: _markers,
                    polylines: _polylines,
                    mapController: _mapController,
                    showMyLocationButton: true,
                    onMyLocationPressed: _goToMyLocation,
                  ),

                  // 🎨 MODERN BOTTOM SHEET OVERLAY
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildModernBottomSheet(order),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 🎨 Build Premium Bottom Sheet with Delivery Info
  Widget _buildModernBottomSheet(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎨 Distance & ETA Card (Gradient Style)
                if (_distanceText != null && _etaText != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFC8019), Color(0xFFFF9F40)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFC8019).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _etaText!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_distanceText away',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Order Items Section
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Items List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.dishItems.length,
                  itemBuilder: (context, index) {
                    final item = order.dishItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu_rounded,
                              color: Color(0xFFFC8019),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.dishName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Qty: ${item.quantity}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${item.price * item.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFFFC8019),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 🎨 Status Badge (Modern Style)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(order.status),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStatusIcon(order.status),
                        color: _getStatusColor(order.status),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusText(order.status),
                        style: TextStyle(
                          color: _getStatusColor(order.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return Colors.blue;
      case OrderStatus.ACCEPTED:
        return Colors.orange;
      case OrderStatus.RIDER_ASSIGNED:
        return Colors.blue;
      case OrderStatus.RIDER_ACCEPTED:
        return Colors.blue;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Colors.purple;
      case OrderStatus.PICKED_UP:
        return Colors.purple;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Colors.purple;
      case OrderStatus.DELIVERED:
        return Colors.teal;
      case OrderStatus.CANCELLED:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return Icons.receipt_long_rounded;
      case OrderStatus.ACCEPTED:
        return Icons.check_circle_rounded;
      case OrderStatus.RIDER_ASSIGNED:
        return Icons.person_rounded;
      case OrderStatus.RIDER_ACCEPTED:
        return Icons.two_wheeler_rounded;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Icons.restaurant_rounded;
      case OrderStatus.PICKED_UP:
        return Icons.shopping_bag_rounded;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Icons.two_wheeler_rounded;
      case OrderStatus.DELIVERED:
        return Icons.home_rounded;
      case OrderStatus.CANCELLED:
        return Icons.cancel_rounded;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return 'Order Placed';
      case OrderStatus.ACCEPTED:
        return 'Accepted by Cook';
      case OrderStatus.RIDER_ASSIGNED:
        return 'Rider Assigned';
      case OrderStatus.RIDER_ACCEPTED:
        return 'Rider Accepted';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'Going to Pickup';
      case OrderStatus.PICKED_UP:
        return 'Picked Up';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'On the Way';
      case OrderStatus.DELIVERED:
        return 'Delivered';
      case OrderStatus.CANCELLED:
        return 'Cancelled';
    }
  }
}
