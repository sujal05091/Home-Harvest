import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order_model.dart';
import '../../models/rider_location_model.dart';
import '../../services/rider_location_service.dart';
import '../../widgets/osm_map_widget.dart';

/// Live Tracking Screen for Customer
/// Shows real-time rider location with smooth animations
/// Only accessible when order status is RIDER_ACCEPTED or later
/// Auto-updates ETA based on rider's current location and speed
class LiveTrackingScreen extends StatefulWidget {
  final String orderId;

  const LiveTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final RiderLocationService _locationService = RiderLocationService();
  final MapController _mapController = MapController();
  
  StreamSubscription<RiderLocationModel?>? _riderLocationSubscription;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  LatLng? _riderLatLng;
  
  String _eta = 'Calculating...';
  String _distance = 'Calculating...';
  bool _autoFollow = true;

  @override
  void dispose() {
    _riderLocationSubscription?.cancel();
    super.dispose();
  }

  void _startListeningToRider(String riderId) {
    _riderLocationSubscription?.cancel();
    
    _riderLocationSubscription = _locationService
        .listenToRiderLocation(riderId)
        .listen((riderLocation) {
      if (riderLocation != null && mounted) {
        setState(() {
          _riderLatLng = LatLng(
            riderLocation.latitude,
            riderLocation.longitude,
          );
        });
        
        _updateMap();
        
        // Auto-follow rider if enabled
        if (_autoFollow && _riderLatLng != null) {
          _mapController.move(_riderLatLng!, _mapController.camera.zoom);
        }
      }
    });
  }

  void _updateMap() {
    if (_pickupLatLng == null || _dropLatLng == null) return;

    List<Marker> newMarkers = [
      MarkerHelper.createPickupMarker(_pickupLatLng!, 'Pickup Location'),
      MarkerHelper.createDropMarker(_dropLatLng!, 'Drop Location'),
    ];

    // Add rider marker if location is available
    if (_riderLatLng != null) {
      newMarkers.add(
        MarkerHelper.createDeliveryMarker(_riderLatLng!),
      );
    }

    // Create route polyline
    List<LatLng> routePoints = [];
    if (_riderLatLng != null) {
      routePoints = [_pickupLatLng!, _riderLatLng!, _dropLatLng!];
    } else {
      routePoints = [_pickupLatLng!, _dropLatLng!];
    }

    setState(() {
      _markers = newMarkers;
      _polylines = [PolylineHelper.createRoute(points: routePoints)];
    });

    // Calculate ETA and distance
    if (_riderLatLng != null) {
      final distanceKm = _locationService.calculateDistance(
        _riderLatLng!.latitude,
        _riderLatLng!.longitude,
        _dropLatLng!.latitude,
        _dropLatLng!.longitude,
      );

      setState(() {
        _distance = '${distanceKm.toStringAsFixed(1)} km';
        _eta = _locationService.calculateETA(distanceKm);
      });
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.RIDER_ACCEPTED:
        return 'Rider on the way to pickup';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'Rider heading to restaurant';
      case OrderStatus.PICKED_UP:
        return 'Food picked up! Coming to you';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'Rider arriving soon';
      case OrderStatus.DELIVERED:
        return 'Order delivered';
      default:
        return 'Tracking rider...';
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.RIDER_ACCEPTED:
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Icons.restaurant;
      case OrderStatus.PICKED_UP:
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Icons.delivery_dining;
      case OrderStatus.DELIVERED:
        return Icons.check_circle;
      default:
        return Icons.location_on;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.RIDER_ACCEPTED:
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Colors.orange;
      case OrderStatus.PICKED_UP:
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Colors.blue;
      case OrderStatus.DELIVERED:
        return Colors.green;
      default:
        return Colors.grey;
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
            return const Center(child: Text('Order not found'));
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final order = OrderModel.fromMap(orderData, widget.orderId);

          // Initialize locations
          if (_pickupLatLng == null) {
            _pickupLatLng = LatLng(
              order.pickupLocation.latitude,
              order.pickupLocation.longitude,
            );
            _dropLatLng = LatLng(
              order.dropLocation.latitude,
              order.dropLocation.longitude,
            );
            _updateMap();
          }

          // Start listening to rider location
          if (order.assignedRiderId != null &&
              _riderLocationSubscription == null) {
            _startListeningToRider(order.assignedRiderId!);
          }

          // Show delivered state
          if (order.status == OrderStatus.DELIVERED) {
            return _buildDeliveredScreen(order);
          }

          return Stack(
            children: [
              // Map
              if (_pickupLatLng != null && _dropLatLng != null)
                OSMMapWidget(
                  mapController: _mapController,
                  markers: _markers,
                  polylines: _polylines,
                  center: _pickupLatLng!,
                  zoom: 14,
                ),

              // Top bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(order.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Auto-follow toggle
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                right: 16,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() => _autoFollow = !_autoFollow);
                      if (_autoFollow && _riderLatLng != null) {
                        _mapController.move(
                          _riderLatLng!,
                          _mapController.camera.zoom,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _autoFollow
                            ? const Color(0xFFFF6B35)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: _autoFollow ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom sheet
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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

                      // ETA card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(order.status),
                              _getStatusColor(order.status).withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estimated Time',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _eta,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Distance',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _distance,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Rider info
                      if (order.assignedRiderName != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: _getStatusColor(order.status)
                                    .withOpacity(0.1),
                                child: Icon(
                                  Icons.delivery_dining,
                                  color: _getStatusColor(order.status),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.assignedRiderName!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D3142),
                                      ),
                                    ),
                                    const Text(
                                      'Delivery Partner',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.phone),
                                color: const Color(0xFFFF6B35),
                                onPressed: () {
                                  // TODO: Implement call functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Call ${order.assignedRiderPhone}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 32, indent: 20, endIndent: 20),
                      ],

                      // Order summary
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getStatusIcon(order.status),
                                  size: 20,
                                  color: _getStatusColor(order.status),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${order.dishItems.length} items • ₹${order.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3142),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Tiffin badge
                            if (order.isHomeToOffice) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.home_work,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tiffin Delivery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeliveredScreen(OrderModel order) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Order Delivered!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Delivered at ${order.deliveredAt?.toString().substring(11, 16) ?? ""}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
