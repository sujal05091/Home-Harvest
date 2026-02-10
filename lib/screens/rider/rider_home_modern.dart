import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../services/firestore_service.dart';
import '../../app_router.dart';
import '../../theme.dart';
import '../../models/delivery_model.dart';
import '../../models/order_model.dart';
import 'rider_active_delivery_screen.dart';

class RiderHomeModernScreen extends StatefulWidget {
  const RiderHomeModernScreen({super.key});

  @override
  State<RiderHomeModernScreen> createState() => _RiderHomeModernScreenState();
}

class _RiderHomeModernScreenState extends State<RiderHomeModernScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final riderProvider = Provider.of<RiderProvider>(context, listen: false);
      
      // Load rider's assigned deliveries
      riderProvider.loadRiderDeliveries(authProvider.currentUser!.uid);
      
      // 🆕 Load available unassigned orders
      riderProvider.loadAvailableOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final riderProvider = Provider.of<RiderProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Get active deliveries (rider accepted)
    final activeDeliveries = riderProvider.activeDeliveries;
    print('🚀 [RiderHome] activeDeliveries count: ${activeDeliveries.length}');

    // 🆕 Get unassigned orders available for this rider to accept
    final newRequests = riderProvider.availableOrders;
    print('🎯 [RiderHome] newRequests count: ${newRequests.length}');
    if (newRequests.isNotEmpty) {
      print('   First request: ${newRequests.first.orderId} - ${newRequests.first.customerName}');
    }

    // Filter active deliveries by status (exclude DELIVERED only)
    final activeInProgress = activeDeliveries
        .where((delivery) => delivery.status != DeliveryStatus.DELIVERED)
        .toList();
    print('📦 [RiderHome] activeInProgress count: ${activeInProgress.length}');

    // Get delivered deliveries for history
    final deliveredDeliveries = activeDeliveries
        .where((delivery) => delivery.status == DeliveryStatus.DELIVERED)
        .toList()
      ..sort((a, b) => (b.deliveredAt ?? b.assignedAt).compareTo(a.deliveredAt ?? a.assignedAt));

    // Calculate today's earnings from deliveries
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEarnings = deliveredDeliveries
        .where((delivery) => 
            delivery.deliveredAt != null && 
            delivery.deliveredAt!.isAfter(todayStart) &&
            delivery.deliveryFee != null)
        .fold(0.0, (sum, delivery) => sum + (delivery.deliveryFee ?? 0.0) * 0.8);

    // Calculate total earnings (80% of delivery fees)
    final totalEarnings = deliveredDeliveries
        .where((delivery) => delivery.deliveryFee != null)
        .fold(0.0, (sum, delivery) => sum + (delivery.deliveryFee ?? 0.0) * 0.8);

    // Count pending deliveries (not yet delivered)
    final pendingCount = activeDeliveries
        .where((delivery) => delivery.status != DeliveryStatus.DELIVERED)
        .length;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Exit App', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes', style: TextStyle(color: AppTheme.errorColor)),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB8D96C), Color(0xFF8BC34A), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              Provider.of<RiderProvider>(context, listen: false)
                  .loadRiderDeliveries(user.uid);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeader(user, totalEarnings),
                      SizedBox(height: 16),
                      if (newRequests.isNotEmpty)
                        _buildMapSection(newRequests.first),
                      if (newRequests.isNotEmpty)
                        SizedBox(height: 16),
                      _buildStatsCards(pendingCount, todayEarnings),
                      SizedBox(height: 20),
                      if (newRequests.isNotEmpty) ...[
                        _buildNewDeliveryRequest(newRequests.first, riderProvider),
                        SizedBox(height: 20),
                      ],
                      if (activeInProgress.isNotEmpty) ...[
                        _buildActiveDeliveries(activeInProgress),
                        SizedBox(height: 20),
                      ],
                      _buildOrderHistory(deliveredDeliveries),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(user, double totalEarnings) {
    final riderProvider = Provider.of<RiderProvider>(context);
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile Photo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                  image: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(user.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.white.withOpacity(0.3),
                ),
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF9CCC65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'DELIVERY PARTNER',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Total Earnings Card
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRouter.riderEarnings),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF66BB6A).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance_wallet, 
                            color: Color(0xFF388E3C), size: 22),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '₹${totalEarnings.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, 
                      color: AppTheme.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Profile Settings Button
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRouter.profile),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.settings,
                  color: AppTheme.textPrimary,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      SizedBox(height: 16),
      // Online/Offline Toggle
      Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (riderProvider.isAvailable 
                        ? Color(0xFF66BB6A) 
                        : Colors.grey)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    riderProvider.isAvailable 
                        ? Icons.check_circle 
                        : Icons.cancel,
                    color: riderProvider.isAvailable 
                        ? Color(0xFF388E3C) 
                        : Colors.grey[600],
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riderProvider.isAvailable ? 'You are Online' : 'You are Offline',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      riderProvider.isAvailable 
                          ? 'Available for deliveries' 
                          : 'Not accepting orders',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Switch(
              value: riderProvider.isAvailable,
              onChanged: (value) => riderProvider.toggleAvailability(),
              activeColor: Color(0xFF66BB6A),
              activeTrackColor: Color(0xFF66BB6A).withOpacity(0.5),
            ),
          ],
        ),
      ),
    ],
    ),
    );
  }

  Widget _buildMapSection(delivery) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Route visualization
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pickup marker
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, 
                          color: Color(0xFFFF5722), size: 60),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'Pickup',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Connector line
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.two_wheeler, 
                          color: Color(0xFF66BB6A), size: 36),
                      SizedBox(height: 4),
                      Container(
                        width: 100,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Color(0xFF66BB6A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${delivery.distanceKm?.toStringAsFixed(1) ?? '0.0'} km',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF388E3C),
                        ),
                      ),
                    ],
                  ),
                  // Drop marker
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, 
                          color: Color(0xFF4CAF50), size: 60),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'Drop',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
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
    );
  }

  Widget _buildStatsCards(int pendingCount, double todayEarnings) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFFFF5E8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment, 
                        color: AppTheme.primaryOrange, size: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pendingCount',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Pending Deliveries',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFFFF5E8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF66BB6A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.currency_rupee, 
                        color: Color(0xFF388E3C), size: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${todayEarnings.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Today\'s Earnings',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
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
      ),
    );
  }

  Widget _buildNewDeliveryRequest(OrderModel order, RiderProvider riderProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Use address from order
    final pickupAddress = order.pickupAddress ?? 'Pickup Location';
    final dropAddress = order.dropAddress ?? 'Drop Location';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Delivery Request',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          // Pickup Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.restaurant, 
                          color: AppTheme.primaryOrange, size: 24),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.two_wheeler, 
                            color: AppTheme.primaryOrange, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.cookName ?? 'Restaurant',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      pickupAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 16),
          // Customer Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, 
                    color: Color(0xFF4CAF50), size: 28),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName ?? 'Customer',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      dropAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.two_wheeler, 
                        color: AppTheme.primaryOrange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${order.distanceKm?.toStringAsFixed(1) ?? '0.0'} km',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Delivery Fee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '₹${order.deliveryCharge?.toStringAsFixed(0) ?? '0'}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Reject delivery - just don't accept it
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delivery request ignored')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final user = authProvider.currentUser!;
                      
                      // Update order with rider assignment
                      await FirebaseFirestore.instance
                          .collection('orders')
                          .doc(order.orderId)
                          .update({
                        'status': OrderStatus.RIDER_ACCEPTED.name,
                        'assignedRiderId': user.uid,
                        'assignedRiderName': user.name,
                        'assignedRiderPhone': user.phone,
                        'assignedAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      // Get rider's current location
                      GeoPoint? initialLocation;
                      try {
                        print('📍 [Rider] Getting initial location...');
                        
                        // Check permissions first
                        LocationPermission permission = await Geolocator.checkPermission();
                        print('📱 [Rider] Current permission: $permission');
                        
                        if (permission == LocationPermission.denied || 
                            permission == LocationPermission.deniedForever) {
                          permission = await Geolocator.requestPermission();
                          print('📱 [Rider] Requested permission: $permission');
                        }
                        
                        if (permission == LocationPermission.whileInUse || 
                            permission == LocationPermission.always) {
                          final position = await Geolocator.getCurrentPosition(
                            locationSettings: const LocationSettings(
                              accuracy: LocationAccuracy.high,
                              timeLimit: Duration(seconds: 10),
                            ),
                          ).timeout(
                            Duration(seconds: 10),
                            onTimeout: () {
                              print('⏱️ [Rider] Location timeout');
                              throw TimeoutException('Location fetch timeout');
                            },
                          );
                          initialLocation = GeoPoint(position.latitude, position.longitude);
                          print('✅ [Rider] Initial location: ${position.latitude}, ${position.longitude}');
                        } else {
                          print('❌ [Rider] Location permission denied: $permission');
                        }
                      } catch (e, stackTrace) {
                        print('❌ [Rider] Could not get initial location: $e');
                        print('Stack trace: $stackTrace');
                      }

                      // Create delivery document
                      print('📦 [Rider] Creating delivery document with location: $initialLocation');
                      await FirebaseFirestore.instance
                          .collection('deliveries')
                          .doc(order.orderId)
                          .set({
                        'deliveryId': order.orderId,
                        'orderId': order.orderId,
                        'riderId': user.uid,
                        'riderName': user.name,
                        'riderPhone': user.phone,
                        'customerId': order.customerId,
                        'cookId': order.cookId,
                        'status': 'ASSIGNED',
                        'pickupLocation': order.pickupLocation,
                        'dropLocation': order.dropLocation,
                        'currentLocation': initialLocation, // Add initial rider location
                        'deliveryFee': order.deliveryCharge ?? 40.0,
                        'distanceKm': order.distanceKm,
                        'estimatedMinutes': (order.distanceKm! * 3).round(),
                        'assignedAt': FieldValue.serverTimestamp(),
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order accepted! Starting navigation...'),
                          backgroundColor: AppTheme.successGreen,
                          duration: Duration(seconds: 1),
                        ),
                      );
                      
                      // Small delay to show the snackbar
                      await Future.delayed(Duration(milliseconds: 800));
                      
                      // Reload rider deliveries to show the accepted order
                      riderProvider.loadRiderDeliveries(user.uid);
                      
                      // Navigate to Active Delivery Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiderActiveDeliveryScreen(
                            order: order,
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error accepting order: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF66BB6A),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Accept',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveries(List<DeliveryModel> deliveries) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Deliveries',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${deliveries.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...deliveries.map((delivery) => _buildActiveDeliveryCard(delivery)).toList(),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryCard(DeliveryModel delivery) {
    final statusColor = delivery.status == DeliveryStatus.ASSIGNED
        ? AppTheme.primaryOrange
        : delivery.status == DeliveryStatus.ACCEPTED
            ? Colors.blue
            : delivery.status == DeliveryStatus.PICKED_UP
                ? Color(0xFF66BB6A)
                : AppTheme.successGreen;

    final statusLabel = delivery.status == DeliveryStatus.ASSIGNED
        ? 'NEW'
        : delivery.status == DeliveryStatus.ACCEPTED
            ? 'ACCEPTED'
            : delivery.status == DeliveryStatus.PICKED_UP
                ? 'PICKED UP'
                : 'ON THE WAY';

    return GestureDetector(
      onTap: () async {
        if (delivery.orderId == null) return;
        
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );
        
        try {
          // Fetch the order from Firestore
          final order = await FirestoreService().getOrder(delivery.orderId!);
          Navigator.pop(context); // Close loading dialog
          
          if (order != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RiderActiveDeliveryScreen(order: order),
              ),
            );
          }
        } catch (e) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading order: $e')),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${delivery.orderId?.substring(0, 8) ?? 'Unknown'}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.restaurant, color: AppTheme.primaryOrange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pickup → Delivery',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.two_wheeler, color: AppTheme.primaryOrange, size: 18),
                    SizedBox(width: 4),
                    Text(
                      '${delivery.distanceKm?.toStringAsFixed(1) ?? '0.0'} km',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${delivery.deliveryFee?.toStringAsFixed(0) ?? '0'}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (delivery.orderId == null) return;
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(child: CircularProgressIndicator()),
                  );
                  
                  try {
                    // Fetch the order from Firestore
                    final order = await FirestoreService().getOrder(delivery.orderId!);
                    Navigator.pop(context); // Close loading dialog
                    
                    if (order != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiderActiveDeliveryScreen(order: order),
                        ),
                      );
                    }
                  } catch (e) {
                    Navigator.pop(context); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error loading order: $e')),
                    );
                  }
                },
                icon: Icon(Icons.navigate_next, size: 20),
                label: Text(
                  delivery.status == DeliveryStatus.ASSIGNED
                      ? 'Start Delivery'
                      : delivery.status == DeliveryStatus.ACCEPTED
                          ? 'Continue Delivery'
                          : 'Navigate to Drop',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistory(List deliveredDeliveries) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order History',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          deliveredDeliveries.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lottie/delivery motorbike.json',
                        width: 150,
                        height: 150,
                      ),
                      Text(
                        'No completed deliveries yet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: deliveredDeliveries.length > 5 ? 5 : deliveredDeliveries.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final delivery = deliveredDeliveries[index];
                    final deliveryDate = delivery.deliveredAt ?? delivery.assignedAt;
                    final monthName = _getMonthName(deliveryDate.month);
                    final earning = (delivery.deliveryFee ?? 0.0) * 0.8; // 80% rider commission
                    
                    return Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Color(0xFF66BB6A).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.restaurant_menu, 
                                color: Color(0xFF388E3C), size: 24),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer #${delivery.customerId.substring(0, 8)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  delivery.orderId.substring(0, 12),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$monthName ${deliveryDate.day}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${earning.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF66BB6A).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${delivery.distanceKm?.toStringAsFixed(1) ?? '0'} km',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF388E3C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          if (deliveredDeliveries.length > 5) ...[
            SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRouter.riderHistory),
              child: Text(
                'View All History',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF66BB6A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
