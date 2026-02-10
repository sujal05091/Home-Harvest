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

/// 📦 ORDER TRACKING with OpenStreetMap (FREE!)
/// 
/// Real-time Features:
/// - Shows pickup location (cook)
/// - Shows drop location (customer)
/// - Shows delivery partner live location
/// - Draws route polyline
/// - Auto-updates when rider moves
/// - Calculates distance & ETA
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  final OSMMapsService _mapsService = OSMMapsService();
  
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  String _estimatedTime = '';
  String _distance = '';
  StreamSubscription<GeoPoint?>? _locationSubscription;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Update map with order and delivery data
  void _updateMap(OrderModel order, DeliveryModel? delivery) {
    // Create pickup marker (cook location)
    final LatLng pickup = LatLng(
      order.pickupLocation.latitude,
      order.pickupLocation.longitude,
    );

    // Create drop marker (customer location)
    final LatLng drop = LatLng(
      order.dropLocation.latitude,
      order.dropLocation.longitude,
    );

    _markers = [
      MarkerHelper.createPickupMarker(pickup, 'Pickup'),
      MarkerHelper.createDropMarker(drop, 'Delivery'),
    ];

    // Add delivery partner marker if available
    if (delivery?.currentLocation != null) {
      final LatLng riderLocation = LatLng(
        delivery!.currentLocation!.latitude,
        delivery.currentLocation!.longitude,
      );
      _markers.add(MarkerHelper.createDeliveryMarker(riderLocation));
    }

    // Create route polyline (straight line for simplicity)
    _polylines = [
      PolylineHelper.createRoute(
        points: [pickup, drop],
        color: const Color(0xFFFC8019),
        width: 4.0,
      ),
    ];

    // Calculate distance and ETA
    final double distanceKm = _mapsService.calculateDistance(pickup, drop);
    _distance = '${distanceKm.toStringAsFixed(1)} km';
    _estimatedTime = _mapsService.calculateEstimatedTime(distanceKm);

    // Auto-fit map to show all markers
    _fitMapBounds([pickup, drop]);

    setState(() {});
  }

  /// Fit map to show all points
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

    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    double zoom = 13.0;
    if (maxDiff > 0.1) zoom = 11.0;
    if (maxDiff > 0.5) zoom = 9.0;
    if (maxDiff < 0.05) zoom = 14.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(center, zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Chat with Cook',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'orderId': widget.orderId,
                  'otherUserId': 'cook_id',
                  'otherUserName': 'Cook',
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<OrderModel?>(
        stream: firestoreService.getOrderById(widget.orderId),
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = orderSnapshot.data;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          return StreamBuilder<DeliveryModel?>(
            stream: firestoreService.getDeliveryByOrderId(widget.orderId),
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

              return Column(
                children: [
                  // 🗺️ OpenStreetMap View (FREE!)
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: OSMMapWidget(
                        center: LatLng(
                          order.pickupLocation.latitude,
                          order.pickupLocation.longitude,
                        ),
                        zoom: 13.0,
                        markers: _markers,
                        polylines: _polylines,
                        mapController: _mapController,
                        showMyLocationButton: true,
                        onMyLocationPressed: () async {
                          final myLocation = await _mapsService.getCurrentLocation();
                          if (myLocation != null) {
                            _mapController.move(myLocation, 15.0);
                          }
                        },
                      ),
                    ),
                  ),

                  // Order Details Card
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order.orderId.substring(0, 8)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(order.status),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      order.status.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '₹${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFC8019),
                                ),
                              ),
                            ],
                          ),
                          // Delivery Status Timeline
                          const SizedBox(height: 16),
                          _buildStatusTimeline(order, delivery),
                          // Distance & ETA Card
                          if (_distance.isNotEmpty && _estimatedTime.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Card(
                              color: Colors.orange.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(Icons.timer, color: Color(0xFFFC8019)),
                                        const SizedBox(height: 4),
                                        Text(
                                          _estimatedTime,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const Text('ETA', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        const Icon(Icons.directions, color: Color(0xFFFC8019)),
                                        const SizedBox(height: 4),
                                        Text(
                                          _distance,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const Text('Distance', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Order Items
                          const SizedBox(height: 16),
                          const Text(
                            'Items:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...order.dishItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${item.dishName} x${item.quantity}'),
                                  Text('₹${item.price * item.quantity}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusTimeline(OrderModel order, DeliveryModel? delivery) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Order Placed',
              true,
              order.status.index >= OrderStatus.PLACED.index,
              Icons.receipt,
            ),
            _buildTimelineItem(
              'Cook Accepted',
              order.status.index >= OrderStatus.ACCEPTED.index,
              order.status.index > OrderStatus.ACCEPTED.index,
              Icons.restaurant,
            ),
            _buildTimelineItem(
              'Rider Assigned',
              order.status.index >= OrderStatus.RIDER_ASSIGNED.index,
              order.status.index > OrderStatus.RIDER_ASSIGNED.index,
              Icons.delivery_dining,
            ),
            _buildTimelineItem(
              'On the way to pickup',
              order.status.index >= OrderStatus.ON_THE_WAY_TO_PICKUP.index,
              order.status.index > OrderStatus.ON_THE_WAY_TO_PICKUP.index,
              Icons.directions_bike,
            ),
            _buildTimelineItem(
              'Order Picked Up',
              order.status.index >= OrderStatus.PICKED_UP.index,
              order.status.index > OrderStatus.PICKED_UP.index,
              Icons.shopping_bag,
            ),
            _buildTimelineItem(
              'On the way to you',
              order.status.index >= OrderStatus.ON_THE_WAY_TO_DROP.index,
              order.status.index > OrderStatus.ON_THE_WAY_TO_DROP.index,
              Icons.location_on,
            ),
            _buildTimelineItem(
              'Delivered',
              order.status == OrderStatus.DELIVERED,
              false,
              Icons.check_circle,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    bool isCompleted,
    bool isPast,
    IconData icon, {
    bool isLast = false,
  }) {
    final bool isActive = isCompleted && !isPast;
    
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? (isActive ? const Color(0xFFFC8019) : Colors.green)
                    : Colors.grey.shade300,
              ),
              child: Icon(
                icon,
                color: isCompleted ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.black : Colors.grey,
                ),
              ),
              if (isActive)
                const Text(
                  'In Progress...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFC8019),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return Colors.blue;
      case OrderStatus.ACCEPTED:
        return Colors.green;
      case OrderStatus.PREPARING:
        return Colors.purple;
      case OrderStatus.READY:
        return Colors.teal;
      case OrderStatus.RIDER_ASSIGNED:
        return Colors.orange;
      case OrderStatus.RIDER_ACCEPTED:
        return Colors.orange.shade700;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Colors.purple;
      case OrderStatus.PICKED_UP:
        return Colors.amber;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Colors.purple.shade700;
      case OrderStatus.DELIVERED:
        return Colors.teal;
      case OrderStatus.CANCELLED:
        return Colors.red;
    }
  }
}
