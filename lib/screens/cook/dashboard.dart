import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../../services/fcm_service.dart';
import '../../app_router.dart';
import '../../test_cook_notification.dart';

class CookDashboardScreen extends StatefulWidget {
  const CookDashboardScreen({super.key});

  @override
  State<CookDashboardScreen> createState() => _CookDashboardScreenState();
}

class _CookDashboardScreenState extends State<CookDashboardScreen> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<OrdersProvider>(context, listen: false)
          .loadCookOrders(authProvider.currentUser!.uid);
      
      // 🔔 Save FCM token for push notifications
      FCMService().saveFCMToken();
      
      // 🔔 Listen for new order notifications
      _listenForNewOrders(authProvider.currentUser!.uid);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// 🔔 Listen for new order notifications and show popup
  void _listenForNewOrders(String cookId) {
    print('🔔 [Cook] Starting notification listener for cook: $cookId');
    
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: cookId)
        .where('type', isEqualTo: 'NEW_ORDER')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;
      
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          print('🔔 [Cook] New order notification received!');
          print('   Order ID: ${data['orderId']}');
          print('   Title: ${data['title']}');
          print('   Body: ${data['body']}');
          
          // Show popup dialog
          _showNewOrderDialog(
            orderId: data['orderId'],
            customerName: data['data']['customerName'],
            dishNames: data['data']['dishNames'],
            totalAmount: data['data']['totalAmount'],
            notificationId: doc.doc.id,
          );
        }
      }
    });
  }

  /// 🎉 Show new order dialog popup
  void _showNewOrderDialog({
    required String orderId,
    required String customerName,
    required String dishNames,
    required double totalAmount,
    required String notificationId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu, color: Colors.green, size: 30),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔔 New Order!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Order #${orderId.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.person, 'Customer', customerName),
            SizedBox(height: 12),
            _buildInfoRow(Icons.restaurant, 'Items', dishNames),
            SizedBox(height: 12),
            _buildInfoRow(Icons.currency_rupee, 'Amount', '₹${totalAmount.toStringAsFixed(0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Mark notification as read
              FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(notificationId)
                  .update({'read': true});
              Navigator.pop(context);
            },
            child: Text('Dismiss', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // Mark notification as read
              FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(notificationId)
                  .update({'read': true});
              Navigator.pop(context);
              // Refresh orders list
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              Provider.of<OrdersProvider>(context, listen: false)
                  .loadCookOrders(authProvider.currentUser!.uid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('View Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ordersProvider = Provider.of<OrdersProvider>(context);

    // Check if cook is verified
    if (authProvider.currentUser?.verified == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cook Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pending, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Verification Pending',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Your account is under review'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRouter.verificationStatus),
                child: const Text('Check Status'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit App'),
            content: Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cook Dashboard'),
        actions: [
          // 🧪 TEST Notification Button (Yellow)
          IconButton(
            icon: const Icon(Icons.science, color: Colors.yellow),
            tooltip: 'Test Notification',
            onPressed: () async {
              print('🧪 [[COOK TEST]] Button clicked!');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🧪 Creating test notification...')),
              );
              
              // Test with known rider ID
              const testRiderId = 'pCPNkvC4hqTNZqMuLlqjue9NVAF3';
              const testOrderId = 'TEST_COOK_ORDER_001';
              
              await createTestNotificationFromCook(
                riderId: testRiderId,
                orderId: testOrderId,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Test notification sent! Check rider app.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, AppRouter.profile),
          ),
        ],
      ),
      body: ordersProvider.isLoading
          ? Center(child: Lottie.asset('assets/lottie/loading_auth.json', width: 100, height: 100))
          : ordersProvider.orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/lottie/cheff_cooking.json',
                        width: 250,
                        height: 250,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No active orders',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordersProvider.orders.length,
                  itemBuilder: (context, index) {
                    final order = ordersProvider.orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order #${order.orderId.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(order.status),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Order Details
                            Text(
                              'Customer: ${order.customerName}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Amount: ₹${order.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFC8019),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Items: ${order.dishItems.map((item) => '${item.dishName} (${item.quantity})').join(', ')}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            
                            // Action Buttons based on status
                            if (order.status == OrderStatus.PLACED)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _rejectOrder(order.orderId),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _acceptOrder(order.orderId),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              )
                            else if (order.status == OrderStatus.ACCEPTED)
                              // Show "Start Preparing" button for ACCEPTED orders
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _startPreparing(order.orderId),
                                  icon: const Icon(Icons.restaurant),
                                  label: const Text('👨‍🍳 Start Preparing'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              )
                            else if (order.status == OrderStatus.PREPARING)
                              // Show "Food Ready" button for PREPARING orders
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    print('🔴 [Cook] BUTTON CLICKED! Calling _markFoodReady for ${order.orderId}');
                                    _markFoodReady(order.orderId);
                                  },
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('✅ Food Ready'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              )
                            else if (order.status == OrderStatus.RIDER_ASSIGNED)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.delivery_dining, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Rider assigned • Waiting for pickup',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (order.status == OrderStatus.RIDER_ACCEPTED ||
                                     order.status == OrderStatus.ON_THE_WAY_TO_PICKUP ||
                                     order.status == OrderStatus.PICKED_UP || 
                                     order.status == OrderStatus.ON_THE_WAY_TO_DROP)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_shipping, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Out for delivery',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (order.status == OrderStatus.DELIVERED)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Delivered successfully',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRouter.addDish),
        icon: const Icon(Icons.add),
        label: const Text('Add Dish'),
      ),
      ), // Close PopScope
    );
  }

  // 🎯 ACCEPT ORDER
  Future<void> _acceptOrder(String orderId) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.updateOrderStatus(
      orderId,
      OrderStatus.ACCEPTED,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Order accepted! Click "Start Preparing" when ready.' : 'Failed to accept order'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 👨‍🍳 START PREPARING FOOD
  Future<void> _startPreparing(String orderId) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.updateOrderStatus(
      orderId,
      OrderStatus.PREPARING,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '👨‍🍳 Started preparing! Mark as ready when done.' : 'Failed to update status'),
          backgroundColor: success ? Colors.blue : Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ❌ REJECT ORDER
  Future<void> _rejectOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order?'),
        content: const Text('Are you sure you want to reject this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      final success = await ordersProvider.updateOrderStatus(
        orderId,
        OrderStatus.CANCELLED,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Order rejected' : 'Failed to reject order'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
      }
    }
  }

  // 🍽️ MARK FOOD READY (and auto-assign rider)
  Future<void> _markFoodReady(String orderId) async {
    print('🟢 [Cook] _markFoodReady() FUNCTION CALLED for order: $orderId');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Food Ready?'),
        content: const Text(
          'Mark food as ready for pickup. Nearby riders will see this order and can accept it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Food Ready'),
          ),
        ],
      ),
    );

    print('🟡 [Cook] Dialog result: ${confirmed == true ? "CONFIRMED" : "CANCELLED/DISMISSED"}');

    if (confirmed == true && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Marking food as ready...'),
                ],
              ),
            ),
          ),
        ),
      );

      print('🔵 [Cook] _markFoodReady() called for order: $orderId');
      
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      
      // ✅ [NORMAL FOOD WORKFLOW FIX - Issue #2]
      // Mark order as READY for pickup
      // Then notify nearby riders (correct workflow)
      
      print('📝 [Cook] Updating order status to READY...');
      final success = await ordersProvider.updateOrderStatus(
        orderId,
        OrderStatus.READY,
      );
      
      print('📊 [Cook] Update status result: success=$success');

      if (success) {
        // 🔔 NOW notify nearby riders (correct timing!)
        try {
          print('🔔 [Cook] Food marked READY. Notifying nearby riders...');
          print('🔍 [Cook] Fetching order document: $orderId');
          
          // Fetch order details to get pickup location
          final orderDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();
          
          print('📄 [Cook] Order document exists: ${orderDoc.exists}');
          
          if (orderDoc.exists) {
            final orderData = orderDoc.data()!;
            final pickupLocation = orderData['pickupLocation'] as GeoPoint;
            
            print('📍 [Cook] Pickup location: ${pickupLocation.latitude}, ${pickupLocation.longitude}');
            print('🚀 [Cook] Calling FCMService().notifyNearbyRiders()...');
            
            // Send FCM notifications to nearby riders
            await FCMService().notifyNearbyRiders(
              orderId: orderId,
              pickupLat: pickupLocation.latitude,
              pickupLng: pickupLocation.longitude,
              radiusKm: 5.0,
            );
            
            print('✅ [Cook] Riders notified successfully');
          } else {
            print('❌ [Cook] Order document not found!');
          }
        } catch (e, stackTrace) {
          print('⚠️ [Cook] FCM notification failed: $e');
          print('📚 [Cook] Stack trace: $stackTrace');
          // Continue anyway - riders can still see order in dashboard
        }
      } else {
        print('❌ [Cook] Failed to update order status to READY');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? '✅ Food marked ready! Nearby riders notified.' 
                  : 'Failed to update status',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  // 🎨 GET STATUS COLOR
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return Colors.orange;
      case OrderStatus.ACCEPTED:
        return Colors.blue;
      case OrderStatus.PREPARING:
        return Colors.purple;
      case OrderStatus.READY:
        return Colors.green;
      case OrderStatus.RIDER_ASSIGNED:
        return Colors.purple;
      case OrderStatus.RIDER_ACCEPTED:
        return Colors.purple;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Colors.deepOrange;
      case OrderStatus.PICKED_UP:
        return Colors.deepOrange;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Colors.deepOrange;
      case OrderStatus.DELIVERED:
        return Colors.green;
      case OrderStatus.CANCELLED:
        return Colors.red;
    }
  }

  // 📝 GET STATUS TEXT
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return 'NEW ORDER';
      case OrderStatus.ACCEPTED:
        return 'ACCEPTED';
      case OrderStatus.PREPARING:
        return 'PREPARING';
      case OrderStatus.READY:
        return 'READY';
      case OrderStatus.RIDER_ASSIGNED:
        return 'RIDER ASSIGNED';
      case OrderStatus.RIDER_ACCEPTED:
        return 'RIDER ACCEPTED';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'GOING TO PICKUP';
      case OrderStatus.PICKED_UP:
        return 'PICKED UP';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'ON THE WAY';
      case OrderStatus.DELIVERED:
        return 'DELIVERED';
      case OrderStatus.CANCELLED:
        return 'CANCELLED';
    }
  }
}
