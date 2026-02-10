import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/osm_maps_service.dart';
import '../../services/rider_location_service.dart';
import '../../services/wallet_service.dart';
import '../../models/delivery_model.dart';
import '../../models/order_model.dart';
import '../../widgets/osm_map_widget.dart';
import '../../app_router.dart';
import 'dart:async';

/// 🛵 RIDER NAVIGATION with OpenStreetMap (FREE!)
/// 
/// Features:
/// - Real-time location tracking
/// - Automatic Firestore updates
/// - Shows pickup & drop locations
/// - Navigation-style view
/// - Status management
class RiderNavigationScreen extends StatefulWidget {
  final String deliveryId;
  final String orderId;

  const RiderNavigationScreen({
    super.key,
    required this.deliveryId,
    required this.orderId,
  });

  @override
  State<RiderNavigationScreen> createState() => _RiderNavigationScreenState();
}

class _RiderNavigationScreenState extends State<RiderNavigationScreen> {
  final MapController _mapController = MapController();
  final FirestoreService _firestoreService = FirestoreService();
  final OSMMapsService _mapsService = OSMMapsService();
  final RiderLocationService _locationService = RiderLocationService();
  final WalletService _walletService = WalletService();
  
  LatLng? _currentLocation;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  bool _isTracking = false;
  bool _isCompletingDelivery = false; // Prevent double completion
  String? _riderId;

  @override
  void initState() {
    super.initState();
    _riderId = FirebaseAuth.instance.currentUser?.uid;
    _startLocationTracking();
  }

  @override
  void dispose() {
    // Stop GPS tracking when screen is disposed
    if (_riderId != null) {
      _locationService.stopTracking(_riderId!);
    }
    super.dispose();
  }

  /// Start tracking rider's location and update Firestore
  void _startLocationTracking() {
    if (_isTracking || _riderId == null) return;
    _isTracking = true;

    // Start GPS streaming with RiderLocationService
    _locationService.startTracking(
      riderId: _riderId!,
      orderId: widget.orderId,
      onLocationUpdate: (location) {
        if (mounted) {
          final newLocation = LatLng(location.latitude, location.longitude);
          setState(() {
            _currentLocation = newLocation;
            _updateMarkers();
          });

          // Move map camera to follow rider (only if map is ready)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(newLocation, currentZoom);
            } catch (e) {
              // Map not ready yet, skip camera movement
              debugPrint('Map not ready for camera movement: $e');
            }
          });
        }
      },
    );
  }

  /// Update markers on map
  void _updateMarkers() {
    _markers = [];

    // Add pickup marker
    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          point: _pickupLocation!,
          width: 60,
          height: 60,
          child: const Column(
            children: [
              Icon(Icons.location_on, color: Color(0xFFFC8019), size: 40),
              Text(
                'Pickup',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFC8019),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add drop marker
    if (_dropLocation != null) {
      _markers.add(
        Marker(
          point: _dropLocation!,
          width: 60,
          height: 60,
          child: const Column(
            children: [
              Icon(Icons.home, color: Colors.green, size: 40),
              Text(
                'Drop',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add rider's current location
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          point: _currentLocation!,
          width: 50,
          height: 50,
          child: const Column(
            children: [
              Icon(
                Icons.navigation,
                color: Colors.blue,
                size: 40,
              ),
              Text(
                'You',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Draw route polyline
    if (_pickupLocation != null && _dropLocation != null) {
      _polylines = [
        Polyline(
          points: [_pickupLocation!, _dropLocation!],
          color: const Color(0xFFFC8019),
          strokeWidth: 4.0,
        ),
      ];
    }
  }

  /// Update delivery status
  Future<void> _updateDeliveryStatus(DeliveryStatus status) async {
    // 🛡️ Prevent double completion
    if (status == DeliveryStatus.DELIVERED && _isCompletingDelivery) {
      debugPrint('⚠️ Delivery already being completed, ignoring duplicate request');
      return;
    }
    
    if (status == DeliveryStatus.DELIVERED) {
      _isCompletingDelivery = true;
    }
    
    try {
      // Update delivery status
      await _firestoreService.updateDeliveryStatus(widget.deliveryId, status);
      
      // Also update order status for customer to see real-time updates
      OrderStatus orderStatus;
      DateTime? timestamp;
      
      switch (status) {
        case DeliveryStatus.ACCEPTED:
          orderStatus = OrderStatus.ON_THE_WAY_TO_PICKUP;
          timestamp = DateTime.now();
          break;
        case DeliveryStatus.PICKED_UP:
          orderStatus = OrderStatus.PICKED_UP;
          timestamp = DateTime.now();
          break;
        case DeliveryStatus.ON_THE_WAY:
          orderStatus = OrderStatus.ON_THE_WAY_TO_DROP;
          timestamp = DateTime.now();
          break;
        case DeliveryStatus.DELIVERED:
          orderStatus = OrderStatus.DELIVERED;
          timestamp = DateTime.now();
          break;
        default:
          orderStatus = OrderStatus.RIDER_ACCEPTED;
      }
      
      // Update order status in Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': orderStatus.name,
        if (status == DeliveryStatus.PICKED_UP) 'pickedUpAt': Timestamp.fromDate(timestamp!),
        if (status == DeliveryStatus.DELIVERED) ...{
          'deliveredAt': Timestamp.fromDate(timestamp!),
          'isActive': false, // 🔥 Mark delivery as inactive
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Delivery ${widget.deliveryId} status updated to ${status.name}');
      debugPrint('✅ Order ${widget.orderId} status updated to ${orderStatus.name}');
      
      // 🎯 DELIVERY COMPLETION FLOW
      if (status == DeliveryStatus.DELIVERED && mounted) {
        await _completeDelivery();
      }
    } catch (e) {
      _isCompletingDelivery = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 🎯 Complete delivery: Stop tracking, update earnings, navigate home
  Future<void> _completeDelivery() async {
    try {
      debugPrint('🎉 [Delivery] Starting completion flow');
      
      // A. STOP TRACKING (both services)
      debugPrint('🛑 [Delivery] Stopping location tracking');
      _mapsService.stopLocationUpdates();
      if (_riderId != null) {
        await _locationService.stopTracking(_riderId!);
      }
      
      // B. GET ORDER DATA & UPDATE RIDER EARNINGS
      debugPrint('💰 [Delivery] Fetching order data for earnings');
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      
      if (orderDoc.exists && _riderId != null) {
        final orderData = orderDoc.data()!;
        final riderEarning = (orderData['riderEarning'] as num?)?.toDouble() ?? 0.0;
        
        if (riderEarning > 0) {
          debugPrint('💵 [Delivery] Adding ₹$riderEarning to rider wallet');
          
          // C. UPDATE RIDER WALLET (totalEarnings, todayEarnings)
          await _walletService.creditWallet(
            riderId: _riderId!,
            amount: riderEarning,
            orderId: widget.orderId,
            description: 'Delivery completed - Order #${widget.orderId.substring(0, 8)}',
          );
          
          debugPrint('✅ [Delivery] Rider earnings updated successfully');
        }
      }
      
      // D. SHOW SUCCESS MESSAGE
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delivery completed successfully! 🎉\nEarnings updated',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // E. AUTO NAVIGATION TO HOME (clear navigation stack)
      debugPrint('🏠 [Delivery] Navigating to rider home');
      await Future.delayed(const Duration(milliseconds: 500)); // Let snackbar show
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.riderHome,
          (route) => false, // Remove all previous routes
        );
      }
      
      debugPrint('✅ [Delivery] Completion flow finished');
    } catch (e) {
      debugPrint('❌ [Delivery] Error in completion flow: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Still navigate home even if earnings update fails
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.riderHome,
          (route) => false,
        );
      }
    } finally {
      _isCompletingDelivery = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery #${widget.deliveryId.substring(0, 8)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Call Customer',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling customer...')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DeliveryModel?>(
        stream: _firestoreService.getDeliveryById(widget.deliveryId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final delivery = snapshot.data!;
          _pickupLocation = LatLng(
            delivery.pickupLocation.latitude,
            delivery.pickupLocation.longitude,
          );
          _dropLocation = LatLng(
            delivery.dropLocation.latitude,
            delivery.dropLocation.longitude,
          );

          // Update markers
          _updateMarkers();

          return Column(
            children: [
              // 🗺️ OpenStreetMap View (FREE!)
              Expanded(
                flex: 2,
                child: OSMMapWidget(
                  center: _currentLocation ?? _pickupLocation!,
                  zoom: 15.0,
                  markers: _markers,
                  polylines: _polylines,
                  mapController: _mapController,
                  showMyLocationButton: true,
                  onMyLocationPressed: () {
                    if (_currentLocation != null) {
                      _mapController.move(_currentLocation!, 16.0);
                    }
                  },
                ),
              ),

              // Action Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current location indicator
                    if (_currentLocation != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gps_fixed, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}, '
                                'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Status indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(delivery.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delivery_dining, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            delivery.status.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Action buttons based on status
                    if (delivery.status == DeliveryStatus.ASSIGNED)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateDeliveryStatus(
                            DeliveryStatus.ACCEPTED,
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Start Pickup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                    if (delivery.status == DeliveryStatus.ACCEPTED)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateDeliveryStatus(
                            DeliveryStatus.PICKED_UP,
                          ),
                          icon: const Icon(Icons.shopping_bag),
                          label: const Text('Picked Up - Start Delivery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFC8019),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                    if (delivery.status == DeliveryStatus.PICKED_UP)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateDeliveryStatus(
                            DeliveryStatus.DELIVERED,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Delivered'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                    // Earnings info
                    if (delivery.deliveryFee != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Earnings: ₹${delivery.deliveryFee}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFC8019),
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

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.ASSIGNED:
        return Colors.blue;
      case DeliveryStatus.ACCEPTED:
        return Colors.orange;
      case DeliveryStatus.PICKED_UP:
        return Colors.purple;
      case DeliveryStatus.DELIVERED:
        return Colors.green;
      case DeliveryStatus.ON_THE_WAY:
        return Colors.purple;
    }
  }
}
