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

/// Rider Tiffin Delivery Request Screen
/// Specifically for tiffin service orders (isHomeToOffice = true)
/// Shown when order.status == RIDER_ASSIGNED or READY
/// Rider can accept or reject the tiffin delivery request
/// On accept: Update status to RIDER_ACCEPTED and start GPS tracking for home-to-office delivery
class RiderDeliveryRequestScreen extends StatefulWidget {
  final String orderId;

  const RiderDeliveryRequestScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<RiderDeliveryRequestScreen> createState() =>
      _RiderDeliveryRequestScreenState();
}

class _RiderDeliveryRequestScreenState
    extends State<RiderDeliveryRequestScreen> {
  final RiderLocationService _locationService = RiderLocationService();
  bool _isLoading = false;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  @override
  void dispose() {
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
      
      // Get rider details from users collection
      final riderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!riderDoc.exists) throw 'Rider profile not found';
      
      final riderData = riderDoc.data()!;

      // Update order status to RIDER_ACCEPTED and assign rider
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
      
      debugPrint('✅ Order ${widget.orderId} status updated to RIDER_ACCEPTED');

      // Create rider_locations document if it doesn't exist
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

      // Check if delivery document exists
      final deliveryRef = FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.orderId);
      
      final deliveryDoc = await deliveryRef.get();
      
      if (deliveryDoc.exists) {
        // Update existing delivery document
        await deliveryRef.update({
          'status': DeliveryStatus.ACCEPTED.name,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create delivery document (for backward compatibility with old orders)
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
          'deliveryFee': 40.0,
          'assignedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Start GPS tracking
      await _locationService.startTracking(
        riderId: currentUser.uid,
        orderId: widget.orderId,
        onLocationUpdate: (location) {
          // Location updates are automatically saved to Firestore
          debugPrint('Rider location updated: ${location.latitude}, ${location.longitude}');
        },
      );

      // Navigate to rider navigation screen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRouter.riderNavigationOSM,
          arguments: {
            'orderId': widget.orderId,
            'deliveryId': widget.orderId,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept delivery: $e'),
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
    setState(() => _isLoading = true);

    try {
      // Remove rider assignment and set status back to PLACED
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

      // Go back to rider home screen
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject delivery: $e'),
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

  @override
  Widget build(BuildContext context) {
    print('🔍 [DeliveryRequest] Loading order: ${widget.orderId}');
    
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          print('📦 [DeliveryRequest] Snapshot state: ${snapshot.connectionState}');
          print('📦 [DeliveryRequest] Has data: ${snapshot.hasData}');
          print('📦 [DeliveryRequest] Data exists: ${snapshot.data?.exists}');
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            print('❌ [DeliveryRequest] Order not found in Firestore!');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Order not found'),
                  const SizedBox(height: 8),
                  Text('Order ID: ${widget.orderId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          print('✅ [DeliveryRequest] Order data loaded successfully');
          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          print('📋 [DeliveryRequest] Order data: ${orderData.keys.toList()}');
          
          final order = OrderModel.fromMap(orderData, widget.orderId);

          // Update map - use post-frame callback to avoid setState during build
          if (_markers.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMap(order);
              }
            });
          }

          // Calculate distance
          final distanceKm = _locationService.calculateDistance(
            order.pickupLocation.latitude,
            order.pickupLocation.longitude,
            order.dropLocation.latitude,
            order.dropLocation.longitude,
          );

          // Calculate delivery fee (₹10 per km + ₹20 base)
          final deliveryFee = 20 + (distanceKm * 10);

          return Stack(
            children: [
              // Map background
              if (_pickupLatLng != null && _dropLatLng != null)
                OSMMapWidget(
                  markers: _markers,
                  polylines: _polylines,
                  center: _pickupLatLng!,
                  zoom: 13,
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
                          child: const Text(
                            'New Delivery Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom sheet with order details
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
                      // Delivery fee highlight
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Delivery Fee',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₹${deliveryFee.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Order details
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Distance
                            _buildInfoRow(
                              Icons.straighten,
                              'Distance',
                              '${distanceKm.toStringAsFixed(1)} km',
                            ),
                            const Divider(height: 24),

                            // Pickup
                            _buildLocationRow(
                              Icons.restaurant,
                              'Pickup',
                              order.isHomeToOffice
                                  ? order.pickupAddress
                                  : '${order.cookName}\n${order.pickupAddress}',
                              Colors.green,
                            ),
                            const SizedBox(height: 16),

                            // Drop
                            _buildLocationRow(
                              Icons.location_on,
                              'Drop',
                              order.dropAddress,
                              Colors.orange,
                            ),
                            const Divider(height: 24),

                            // Customer info
                            _buildInfoRow(
                              Icons.person,
                              'Customer',
                              order.customerName,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.phone,
                              'Phone',
                              order.customerPhone,
                            ),
                            const Divider(height: 24),

                            // Order items
                            Row(
                              children: [
                                const Icon(
                                  Icons.shopping_bag,
                                  size: 20,
                                  color: Color(0xFFFF6B35),
                                ),
                                const SizedBox(width: 12),
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
                                      'Home-to-Office Tiffin Delivery',
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

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          children: [
                            // Reject button
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _rejectDelivery,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Reject',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Accept button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : () => _acceptDelivery(order),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: const Color(0xFFFF6B35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Accept & Start',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
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

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String address,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
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
