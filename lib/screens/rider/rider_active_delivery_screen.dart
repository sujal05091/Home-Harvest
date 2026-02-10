import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../models/order_model.dart';
import '../../models/delivery_model.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class RiderActiveDeliveryScreen extends StatefulWidget {
  final OrderModel order;

  const RiderActiveDeliveryScreen({
    super.key,
    required this.order,
  });

  @override
  State<RiderActiveDeliveryScreen> createState() => _RiderActiveDeliveryScreenState();
}

class _RiderActiveDeliveryScreenState extends State<RiderActiveDeliveryScreen> {
  String? _currentStatus;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationUpdateTimer;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    // Initialize status based on order's current status
    _currentStatus = _getLocalStatusFromOrder(widget.order.status);
    // Start tracking rider location
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    try {
      print('� [Rider] Starting location tracking...');
      
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('📱 [Rider] Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('📱 [Rider] Requested permission: $permission');
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('🚨 [Rider] Location permanently denied! Opening settings...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission required! Please enable in Settings.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Open Settings',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        print('✅ [Rider] Location permission granted, starting stream');
        
        // Get initial location immediately
        try {
          final initialPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(Duration(seconds: 10));
          
          await _updateRiderLocation(initialPosition);
          _lastPosition = initialPosition;
          print('🎯 [Rider] Set initial location successfully');
        } catch (e) {
          print('⚠️ [Rider] Could not get initial position: $e');
        }
        
        // Start listening to location updates
        _locationSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen(
          (Position position) {
            print('📍 [Rider] Location stream update: ${position.latitude}, ${position.longitude}');
            _lastPosition = position;
            _updateRiderLocation(position);
          },
          onError: (error) {
            print('❌ [Rider] Location stream error: $error');
          },
          cancelOnError: false,
        );
        
        print('🎉 [Rider] Location stream started successfully');
      } else {
        print('❌ [Rider] Location permission denied: $permission');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission required for tracking!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ [Rider] Error starting location tracking: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location tracking error: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateRiderLocation(Position position) async {
    try {
      print('📍 [Rider] Updating location: ${position.latitude}, ${position.longitude}');
      
      final deliveryRef = FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.order.orderId);
      
      // Check if delivery document exists
      final deliveryDoc = await deliveryRef.get();
      
      if (!deliveryDoc.exists) {
        print('⚠️ [Rider] Delivery document does not exist! Creating it now...');
        await deliveryRef.set({
          'orderId': widget.order.orderId,
          'riderId': widget.order.assignedRiderId,
          'currentLocation': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ [Rider] Delivery document created with location');
      } else {
        await deliveryRef.update({
          'currentLocation': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ [Rider] Location updated successfully');
      }
    } catch (e, stackTrace) {
      print('❌ [Rider] Error updating location: $e');
      print('Stack trace: $stackTrace');
    }
  }

  String _getLocalStatusFromOrder(OrderStatus orderStatus) {
    switch (orderStatus) {
      case OrderStatus.RIDER_ACCEPTED:
        return 'heading_to_pickup';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'picked_up';
      case OrderStatus.PICKED_UP:
        return 'heading_to_customer';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'ready_to_deliver';
      default:
        return 'heading_to_pickup';
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    // Use initialized status
    if (_currentStatus == null) {
      _currentStatus = 'heading_to_pickup';
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map View
          OSMMapWidget(
            center: LatLng(
              order.pickupLocation.latitude,
              order.pickupLocation.longitude,
            ),
            markers: _buildMapMarkers(order),
            polylines: [],
          ),

          // Top Info Card
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _buildTopCard(order),
          ),

          // Bottom Details Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(order),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMapMarkers(OrderModel order) {
    return [
      Marker(
        point: LatLng(order.pickupLocation.latitude, order.pickupLocation.longitude),
        width: 40,
        height: 40,
        child: Icon(Icons.restaurant, color: AppTheme.primaryOrange, size: 40),
      ),
      Marker(
        point: LatLng(order.dropLocation.latitude, order.dropLocation.longitude),
        width: 40,
        height: 40,
        child: Icon(Icons.home, color: Colors.cyan, size: 40),
      ),
    ];
  }

  Widget _buildTopCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentStatus == 'heading_to_pickup'
                  ? Icons.restaurant
                  : _currentStatus == 'picked_up'
                      ? Icons.delivery_dining
                      : Icons.home,
              color: Colors.cyan,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Status Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusSubtitle(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Navigation Button
          IconButton(
            onPressed: () => _openMapsNavigation(order),
            icon: const Icon(Icons.navigation, color: Colors.cyan),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(OrderModel order) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Number & Earnings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderId.substring(0, 8)}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '3.5 km · 15 mins',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successGreen,
                            AppTheme.successGreen.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₹${(order.total * 0.1).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Pickup Location
                _buildLocationCard(
                  icon: Icons.restaurant,
                  iconColor: AppTheme.primaryOrange,
                  title: 'Pickup from',
                  subtitle: order.pickupAddress,
                  showCallButton: true,
                  phoneNumber: '+91 98765 43210', // Cook's phone
                  isPrimary: _currentStatus == 'heading_to_pickup',
                ),
                const SizedBox(height: 12),

                // Drop Location
                _buildLocationCard(
                  icon: Icons.home,
                  iconColor: Colors.cyan,
                  title: 'Deliver to',
                  subtitle: order.dropAddress,
                  showCallButton: true,
                  phoneNumber: order.customerPhone ?? '+91 98765 43210',
                  isPrimary: _currentStatus == 'heading_to_customer',
                ),
                const SizedBox(height: 20),

                // Order Items Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${order.dishItems.length} items',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        order.paymentMethod == 'online' ? 'Prepaid' : 'COD ₹${order.total}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: order.paymentMethod == 'online'
                              ? AppTheme.successGreen
                              : AppTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                _buildActionButtons(order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool showCallButton = false,
    String? phoneNumber,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary ? iconColor.withOpacity(0.05) : Colors.white,
        border: Border.all(
          color: isPrimary ? iconColor : Colors.grey[200]!,
          width: isPrimary ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showCallButton && phoneNumber != null)
            IconButton(
              onPressed: () => _makePhoneCall(phoneNumber),
              icon: Icon(Icons.phone, color: iconColor),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel order) {
    if (_currentStatus == 'heading_to_pickup') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Update order status to ON_THE_WAY_TO_PICKUP
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(order.orderId)
                  .update({
                'status': OrderStatus.ON_THE_WAY_TO_PICKUP.name,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // Update delivery status
              await FirebaseFirestore.instance
                  .collection('deliveries')
                  .doc(order.orderId)
                  .update({
                'status': DeliveryStatus.ACCEPTED.name,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              setState(() {
                _currentStatus = 'picked_up';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('On the way to pickup location!'),
                  backgroundColor: Colors.cyan,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Start Pickup',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (_currentStatus == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Update order status to PICKED_UP
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(order.orderId)
                  .update({
                'status': OrderStatus.PICKED_UP.name,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // Update delivery status
              await FirebaseFirestore.instance
                  .collection('deliveries')
                  .doc(order.orderId)
                  .update({
                'status': DeliveryStatus.PICKED_UP.name,
                'pickedUpAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              setState(() {
                _currentStatus = 'heading_to_customer';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Food picked up successfully!'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Mark Picked Up',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (_currentStatus == 'heading_to_customer') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Update order status to ON_THE_WAY_TO_DROP
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(order.orderId)
                  .update({
                'status': OrderStatus.ON_THE_WAY_TO_DROP.name,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // Update delivery status
              await FirebaseFirestore.instance
                  .collection('deliveries')
                  .doc(order.orderId)
                  .update({
                'status': DeliveryStatus.ON_THE_WAY.name,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              setState(() {
                _currentStatus = 'ready_to_deliver';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Heading to customer location!'),
                  backgroundColor: Colors.blue,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Start Delivery',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            _showDeliveryCompletionDialog();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Mark Delivered',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case 'heading_to_pickup':
        return 'Heading to Restaurant';
      case 'picked_up':
        return 'At Pickup Location';
      case 'heading_to_customer':
        return 'Food Picked Up';
      case 'ready_to_deliver':
        return 'Heading to Customer';
      default:
        return 'Delivering...';
    }
  }

  String _getStatusSubtitle() {
    switch (_currentStatus) {
      case 'heading_to_pickup':
        return 'Navigate to restaurant and collect the food';
      case 'picked_up':
        return 'Mark when you have collected the food';
      case 'heading_to_customer':
        return 'Start heading to customer location';
      case 'ready_to_deliver':
        return 'Deliver the order to customer';
      default:
        return '';
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make phone call')),
        );
      }
    }
  }

  void _openMapsNavigation(OrderModel order) async {
    final lat = _currentStatus == 'heading_to_pickup'
        ? order.pickupLocation.latitude
        : order.dropLocation.latitude;
    final lng = _currentStatus == 'heading_to_pickup'
        ? order.pickupLocation.longitude
        : order.dropLocation.longitude;

    final Uri mapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  void _showDeliveryCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Delivery',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Have you successfully delivered the order to the customer?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Not Yet',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              try {
                // Update order status to DELIVERED
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.order.orderId)
                    .update({
                  'status': OrderStatus.DELIVERED.name,
                  'deliveredAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Update delivery status to DELIVERED
                await FirebaseFirestore.instance
                    .collection('deliveries')
                    .doc(widget.order.orderId)
                    .update({
                  'status': DeliveryStatus.DELIVERED.name,
                  'deliveredAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context); // Return to home
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order delivered successfully! ₹${((widget.order.total * 0.1).toStringAsFixed(0))} earned'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating delivery status: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
