import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../app_router.dart';
import 'add_review.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load orders after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      if (ordersProvider.orders.isEmpty && authProvider.currentUser != null) {
        ordersProvider.loadCustomerOrders(authProvider.currentUser!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<OrdersProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: ordersProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ordersProvider.orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        'No orders yet',
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
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          if (order.status != OrderStatus.DELIVERED &&
                              order.status != OrderStatus.CANCELLED) {
                            Navigator.pushNamed(
                              context,
                              AppRouter.orderTracking,
                              arguments: {'orderId': order.orderId},
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order #${order.orderId.substring(0, 8)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('MMM dd, yyyy hh:mm a')
                                            .format(order.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(order.status).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _getStatusColor(order.status)),
                                    ),
                                    child: Text(
                                      order.status.name,
                                      style: TextStyle(
                                        color: _getStatusColor(order.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              
                              Text(
                                order.cookName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              ...order.dishItems.take(2).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${item.dishName} x${item.quantity}',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                      Text(
                                        '₹${item.price * item.quantity}',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              if (order.dishItems.length > 2)
                                Text(
                                  '+${order.dishItems.length - 2} more items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              
                              const Divider(height: 24),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                              
                              if (order.status == OrderStatus.DELIVERED) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AddReviewScreen(order: order),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.star_border),
                                        label: const Text('Rate Order'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFC8019),
                                          side: const BorderSide(color: Color(0xFFFC8019)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          // Reorder functionality
                                          _reorderItems(context, order);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Reorder'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFC8019),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return Colors.blue;
      case OrderStatus.ACCEPTED:
        return Colors.green;
      case OrderStatus.RIDER_ASSIGNED:
        return Colors.orange;
      case OrderStatus.RIDER_ACCEPTED:
        return Colors.orange;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return Colors.purple;
      case OrderStatus.PICKED_UP:
        return Colors.amber;
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return Colors.purple;
      case OrderStatus.DELIVERED:
        return Colors.teal;
      case OrderStatus.CANCELLED:
        return Colors.red;
    }
  }

  void _reorderItems(BuildContext context, OrderModel order) {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    
    // Clear existing cart and add order items
    for (var item in order.dishItems) {
      // OrderItem is already compatible with cart items
      ordersProvider.cartItems.add(item);
    }
    // Provider will automatically notify listeners when cartItems is modified
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Items added to cart')),
    );
    
    Navigator.pushNamed(context, AppRouter.cart);
  }
}
