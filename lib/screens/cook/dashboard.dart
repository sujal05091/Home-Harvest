import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../../app_router.dart';

class CookDashboardScreen extends StatefulWidget {
  const CookDashboardScreen({super.key});

  @override
  State<CookDashboardScreen> createState() => _CookDashboardScreenState();
}

class _CookDashboardScreenState extends State<CookDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<OrdersProvider>(context, listen: false)
          .loadCookOrders(authProvider.currentUser!.uid);
    });
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
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _markFoodReady(order.orderId),
                                  icon: const Icon(Icons.restaurant_menu),
                                  label: const Text('Food Ready'),
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
          content: Text(success ? 'Order accepted! Start preparing food.' : 'Failed to accept order'),
          backgroundColor: success ? Colors.green : Colors.red,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Food Ready?'),
        content: const Text(
          'Mark food as ready for pickup. A nearby rider will be automatically assigned.',
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
                  Text('Finding nearby rider...'),
                ],
              ),
            ),
          ),
        ),
      );

      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      
      // TODO: Implement auto-assignment logic
      // For now, just update status to ASSIGNED
      // In production, this should call a Cloud Function that:
      // 1. Finds available riders nearby
      // 2. Assigns the closest one
      // 3. Sends notification to rider
      
      final success = await ordersProvider.updateOrderStatus(
        orderId,
        OrderStatus.RIDER_ASSIGNED,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? 'Food marked ready! Rider will be assigned shortly.' 
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
