import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order_model.dart';
import '../../models/delivery_model.dart';
import '../../services/rider_location_service.dart';
import '../../widgets/osm_map_widget.dart';
import '../../app_router.dart';

/// Rider Normal Food Delivery Request Screen
/// Specifically for normal food orders (isHomeToOffice = false)
/// Shows restaurant pickup and customer delivery details
class RiderNormalFoodRequestScreen extends StatefulWidget {
  final String orderId;

  const RiderNormalFoodRequestScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<RiderNormalFoodRequestScreen> createState() =>
      _RiderNormalFoodRequestScreenState();
}

class _RiderNormalFoodRequestScreenState
    extends State<RiderNormalFoodRequestScreen> {
  final RiderLocationService _locationService = RiderLocationService();
  bool _isLoading = false;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng? _restaurantLatLng;
  LatLng? _customerLatLng;

  @override
  void dispose() {
    super.dispose();
  }

  void _updateMap(OrderModel order) {
    _restaurantLatLng = LatLng(
      order.pickupLocation.latitude,
      order.pickupLocation.longitude,
    );
    _customerLatLng = LatLng(
      order.dropLocation.latitude,
      order.dropLocation.longitude,
    );

    setState(() {
      _markers = [
        MarkerHelper.createPickupMarker(
          _restaurantLatLng!,
          order.cookName,
        ),
        MarkerHelper.createDropMarker(
          _customerLatLng!,
          order.customerName,
        ),
      ];

      _polylines = [
        PolylineHelper.createRoute(points: [_restaurantLatLng!, _customerLatLng!]),
      ];
    });
  }

  Future<void> _acceptDelivery(OrderModel order) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'Not authenticated';
      
      // ✅ CHECK: Verify order is still available (not already accepted)
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      
      if (!orderDoc.exists) {
        throw 'Order not found';
      }
      
      final currentOrderData = orderDoc.data()!;
      final currentStatus = currentOrderData['status'];
      final assignedRider = currentOrderData['assignedRiderId'];
      
      // Check if another rider has already accepted this order
      if (currentStatus == OrderStatus.RIDER_ACCEPTED.name && 
          assignedRider != null && 
          assignedRider != currentUser.uid) {
        throw 'This order has already been accepted by another rider';
      }
      
      // Check if order is in correct status to be accepted
      if (currentStatus != OrderStatus.READY.name && 
          currentStatus != OrderStatus.RIDER_ASSIGNED.name &&
          currentStatus != OrderStatus.PLACED.name) {
        throw 'Order is not available for acceptance (Status: $currentStatus)';
      }
      
      // Get rider details
      final riderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!riderDoc.exists) throw 'Rider profile not found';
      
      final riderData = riderDoc.data()!;

      // Update order status to RIDER_ACCEPTED
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': OrderStatus.RIDER_ACCEPTED.name,
        'assignedRiderId': currentUser.uid,
        'assignedRiderName': riderData['name'] ?? 'Unknown',
        'assignedRiderPhone': riderData['phone'] ?? '',
        'assignedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ [NORMAL FOOD] Order ${widget.orderId} accepted by rider');

      // Create rider location tracking document
      final riderLocationRef = FirebaseFirestore.instance
          .collection('rider_locations')
          .doc(currentUser.uid);
      
      final riderLocationDoc = await riderLocationRef.get();
      if (!riderLocationDoc.exists) {
        await riderLocationRef.set({
          'riderId': currentUser.uid,
          'orderId': widget.orderId,
          'location': GeoPoint(0, 0),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create/update delivery document
      final deliveryRef = FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.orderId);
      
      final deliveryDoc = await deliveryRef.get();
      
      if (deliveryDoc.exists) {
        await deliveryRef.update({
          'status': DeliveryStatus.ACCEPTED.name,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await deliveryRef.set({
          'deliveryId': widget.orderId,
          'orderId': widget.orderId,
          'riderId': currentUser.uid,
          'riderName': riderData['name'] ?? 'Unknown',
          'riderPhone': riderData['phone'] ?? '',
          'customerId': order.customerId,
          'cookId': order.cookId,
          'status': DeliveryStatus.ACCEPTED.name,
          'pickupLocation': order.pickupLocation,
          'dropLocation': order.dropLocation,
          'deliveryFee': order.deliveryCharge,
          'assignedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        // Navigate to active delivery tracking
        Navigator.pushReplacementNamed(
          context,
          AppRouter.riderNavigationOSM,
          arguments: {
            'deliveryId': widget.orderId,
            'orderId': widget.orderId,
          },
        );
      }
    } catch (e) {
      print('❌ [NORMAL FOOD] Error accepting delivery: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Delivery?'),
        content: const Text('Are you sure you want to decline this delivery request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Delivery Request'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
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
            return const Center(
              child: Text('Order not found'),
            );
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final order = OrderModel.fromFirestore(snapshot.data!);

          // Update map markers
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMap(order);
          });

          return SingleChildScrollView(
            child: Column(
              children: [
                // Map Preview
                Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: _restaurantLatLng != null && _customerLatLng != null
                      ? FlutterMap(
                          options: MapOptions(
                            initialCenter: _restaurantLatLng!,
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.home_harvest_app',
                            ),
                            MarkerLayer(markers: _markers),
                            PolylineLayer(polylines: _polylines),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),

                // Order Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: Colors.orange,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Normal Food Delivery',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Order #${widget.orderId.substring(0, 8)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // Earnings Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.green, Colors.lightGreen],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.currency_rupee,
                                color: Colors.white,
                                size: 28,
                              ),
                              Text(
                                order.deliveryCharge.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Earnings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),

                      // Restaurant Pickup Details
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Pickup from Restaurant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.store, size: 20, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(
                                    order.cookName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.pickupAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Note: cookPhone not available in OrderModel
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Customer Delivery Details
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Deliver to Customer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 20, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    order.customerName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.dropAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (order.customerPhone.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 20, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      order.customerPhone,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Distance & Items
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoCard(
                            Icons.route,
                            'Distance',
                            '${order.distanceKm?.toStringAsFixed(1) ?? '0.0'} km',
                            Colors.blue,
                          ),
                          _buildInfoCard(
                            Icons.shopping_bag,
                            'Items',
                            '${order.dishItems.length}',
                            Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _rejectDelivery,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _acceptDelivery(order),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFC8019),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, size: 24),
                                        SizedBox(width: 8),
                                        Text(
                                          'Accept Delivery',
                                          style: TextStyle(
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
