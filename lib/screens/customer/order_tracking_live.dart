import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order_model.dart';
import '../../models/delivery_model.dart';
import '../../widgets/osm_map_widget.dart';

/// Comprehensive Live Order Tracking Screen
/// Shows real-time updates, rider location, status timeline, and delivery details
class OrderTrackingLiveScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingLiveScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingLiveScreen> createState() => _OrderTrackingLiveScreenState();
}

class _OrderTrackingLiveScreenState extends State<OrderTrackingLiveScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  LatLng? _riderLatLng;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Order Tracking'),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orderData = orderSnapshot.data!.data() as Map<String, dynamic>?;
          if (orderData == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = OrderModel.fromMap(orderData, widget.orderId);
          
          print('📱 [CustomerTracking] Order Status: ${order.status.name}');

          // Get rider location from delivery document
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('deliveries')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, deliverySnapshot) {
              DeliveryModel? delivery;
              if (deliverySnapshot.hasData && deliverySnapshot.data!.exists) {
                final deliveryData = deliverySnapshot.data!.data() as Map<String, dynamic>;
                delivery = DeliveryModel.fromMap(deliveryData, widget.orderId);
                
                // Update rider location
                if (delivery.currentLocation != null) {
                  _riderLatLng = LatLng(
                    delivery.currentLocation!.latitude,
                    delivery.currentLocation!.longitude,
                  );
                  print('📍 [CustomerTracking] Rider at: ${_riderLatLng!.latitude}, ${_riderLatLng!.longitude}');
                }
              }

              // Update map markers
              _updateMarkers(order, _riderLatLng);

              return Column(
                children: [
                  // 1. STATUS BANNER
                  _buildStatusBanner(order, delivery),

                  // 2. MAP (if rider assigned)
                  if (order.status.index >= OrderStatus.RIDER_ASSIGNED.index)
                    Expanded(
                      flex: 3,
                      child: _buildMap(),
                    ),

                  // 3. STATUS TIMELINE
                  Expanded(
                    flex: 4,
                    child: _buildStatusTimeline(order, delivery),
                  ),

                  // 4. ORDER DETAILS
                  _buildOrderDetails(order),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(OrderModel order, DeliveryModel? delivery) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (order.status) {
      case OrderStatus.PLACED:
        statusText = 'Finding Delivery Partner...';
        statusColor = Colors.orange;
        statusIcon = Icons.search;
        break;
      case OrderStatus.RIDER_ASSIGNED:
        statusText = 'Rider Assigned - Waiting for acceptance';
        statusColor = Colors.blue;
        statusIcon = Icons.person_search;
        break;
      case OrderStatus.RIDER_ACCEPTED:
        statusText = 'Rider Accepted!';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        statusText = 'Rider on the way to pickup';
        statusColor = Colors.purple;
        statusIcon = Icons.two_wheeler;
        break;
      case OrderStatus.PICKED_UP:
        statusText = 'Order Picked Up!';
        statusColor = Colors.teal;
        statusIcon = Icons.shopping_bag;
        break;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        statusText = 'On the way to you!';
        statusColor = Colors.indigo;
        statusIcon = Icons.delivery_dining;
        break;
      case OrderStatus.DELIVERED:
        statusText = '✅ Delivered Successfully!';
        statusColor = Colors.green[700]!;
        statusIcon = Icons.done_all;
        break;
      default:
        statusText = order.status.name;
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (delivery?.estimatedMinutes != null && 
                    order.status.index >= OrderStatus.RIDER_ACCEPTED.index &&
                    order.status != OrderStatus.DELIVERED)
                  Text(
                    'ETA: ${delivery!.estimatedMinutes} mins',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_markers.isEmpty) {
      return const Center(child: Text('Loading map...'));
    }

    return OSMMapWidget(
      markers: _markers,
      polylines: [],
      center: _riderLatLng ?? _pickupLatLng ?? const LatLng(0, 0),
      zoom: 14,
    );
  }

  Widget _buildStatusTimeline(OrderModel order, DeliveryModel? delivery) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTimelineItem(
            '📦 Order Placed',
            true,
            _formatTime(order.createdAt),
            isFirst: true,
          ),
          _buildTimelineItem(
            '👨‍🍳 Cook Preparing',
            order.status.index >= OrderStatus.ACCEPTED.index,
            order.acceptedAt != null ? _formatTime(order.acceptedAt!) : null,
          ),
          _buildTimelineItem(
            '🏍️ Rider Assigned',
            order.status.index >= OrderStatus.RIDER_ASSIGNED.index,
            order.assignedAt != null ? _formatTime(order.assignedAt!) : null,
          ),
          _buildTimelineItem(
            '✅ Rider Accepted',
            order.status.index >= OrderStatus.RIDER_ACCEPTED.index,
            null,
          ),
          _buildTimelineItem(
            '🚗 On the way to Pickup',
            order.status.index >= OrderStatus.ON_THE_WAY_TO_PICKUP.index,
            null,
          ),
          _buildTimelineItem(
            '📍 Order Picked Up',
            order.status.index >= OrderStatus.PICKED_UP.index,
            order.pickedUpAt != null ? _formatTime(order.pickedUpAt!) : null,
          ),
          _buildTimelineItem(
            '🚚 On the way to You',
            order.status.index >= OrderStatus.ON_THE_WAY_TO_DROP.index,
            null,
          ),
          _buildTimelineItem(
            '🎉 Delivered',
            order.status == OrderStatus.DELIVERED,
            order.deliveredAt != null ? _formatTime(order.deliveredAt!) : null,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    bool isCompleted,
    String? time, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 20,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey[300],
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.black : Colors.grey,
                ),
              ),
              if (time != null)
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFC8019),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (order.assignedRiderName != null) ...[
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Rider: ${order.assignedRiderName}'),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (order.assignedRiderPhone != null) ...[
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(order.assignedRiderPhone!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _updateMarkers(OrderModel order, LatLng? riderLocation) {
    _markers.clear();

    // Pickup marker
    if (order.pickupLocation != null) {
      _pickupLatLng = LatLng(
        order.pickupLocation!.latitude,
        order.pickupLocation!.longitude,
      );
      _markers.add(MarkerHelper.createPickupMarker(_pickupLatLng!, 'Pickup'));
    }

    // Drop marker
    if (order.dropLocation != null) {
      _dropLatLng = LatLng(
        order.dropLocation!.latitude,
        order.dropLocation!.longitude,
      );
      _markers.add(MarkerHelper.createDropMarker(_dropLatLng!, 'Drop'));
    }

    // Rider marker (if location available)
    if (riderLocation != null) {
      _markers.add(
        Marker(
          point: riderLocation,
          child: const Icon(
            Icons.delivery_dining,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
    }

    // Don't call setState during build - StreamBuilder will rebuild automatically
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
