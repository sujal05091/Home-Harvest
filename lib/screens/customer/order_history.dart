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

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<OrdersProvider>(context);
    
    // Separate ongoing and completed orders
    final ongoingOrders = ordersProvider.orders.where((order) => 
      order.status != OrderStatus.DELIVERED && order.status != OrderStatus.CANCELLED
    ).toList();
    
    final historyOrders = ordersProvider.orders.where((order) => 
      order.status == OrderStatus.DELIVERED || order.status == OrderStatus.CANCELLED
    ).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ──────────────────────────────────────
            // 📌 HEADER - Clean App Bar Style
            // ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'My Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            // ──────────────────────────────────────
            // 🎯 TAB BAR - Modern Segmented Control
            // ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFFC8019),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFC8019).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 15,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Ongoing'),
                  Tab(text: 'History'),
                ],
              ),
            ),

            // ──────────────────────────────────────
            // 📦 TAB VIEWS - Order Lists
            // ──────────────────────────────────────
            Expanded(
              child: ordersProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFC8019)),
                    ))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // ═══════════════════════════════════
                        // 🔴 ONGOING ORDERS TAB
                        // ═══════════════════════════════════
                        ongoingOrders.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.shopping_bag_outlined,
                                title: 'No ongoing orders',
                                subtitle: 'Your active orders will appear here',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: ongoingOrders.length,
                                itemBuilder: (context, index) {
                                  return _buildModernOrderCard(
                                    context,
                                    ongoingOrders[index],
                                    isOngoing: true,
                                  );
                                },
                              ),

                        // ═══════════════════════════════════
                        // 📜 HISTORY ORDERS TAB
                        // ═══════════════════════════════════
                        historyOrders.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.history,
                                title: 'No past orders',
                                subtitle: 'Your order history will appear here',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: historyOrders.length,
                                itemBuilder: (context, index) {
                                  return _buildModernOrderCard(
                                    context,
                                    historyOrders[index],
                                    isOngoing: false,
                                  );
                                },
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 MODERN ORDER CARD - Swiggy/Zomato Style
  // ═══════════════════════════════════════════════════════════
  Widget _buildModernOrderCard(BuildContext context, OrderModel order, {required bool isOngoing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (isOngoing) {
            Navigator.pushNamed(
              context,
              AppRouter.orderTrackingLive,
              arguments: {'orderId': order.orderId},
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────────────────
              // 📌 TOP ROW - Restaurant Name + Status Badge
              // ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.cookName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${order.orderId.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),

              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.grey[200],
              ),
              const SizedBox(height: 12),

              // ──────────────────────────────────────
              // 📅 DATE + ORDER TYPE
              // ──────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ──────────────────────────────────────
              // 🍽️ DISH ITEMS PREVIEW
              // ──────────────────────────────────────
              ...order.dishItems.take(2).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green[700]!, width: 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${item.dishName} x${item.quantity}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (order.dishItems.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 16),
                  child: Text(
                    '+${order.dishItems.length - 2} more item${order.dishItems.length > 3 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFFC8019),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.grey[200],
              ),
              const SizedBox(height: 12),

              // ──────────────────────────────────────
              // 💰 TOTAL PRICE
              // ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
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

              // ──────────────────────────────────────
              // 🎯 ACTION BUTTONS
              // ──────────────────────────────────────
              if (isOngoing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // View details
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFC8019),
                          side: const BorderSide(color: Color(0xFFFC8019), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRouter.orderTrackingLive,
                            arguments: {'orderId': order.orderId},
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC8019),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.location_on, size: 18),
                        label: const Text(
                          'Track Order',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // History actions
                if (order.status == OrderStatus.DELIVERED) ...[
                  const SizedBox(height: 16),
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFC8019),
                            side: const BorderSide(color: Color(0xFFFC8019), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.star_border, size: 18),
                          label: const Text(
                            'Rate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _reorderItems(context, order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFC8019),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text(
                            'Reorder',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ STATUS BADGE - Color Coded
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusBadge(OrderStatus status) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.PLACED:
        return 'Placed';
      case OrderStatus.ACCEPTED:
        return 'Accepted';
      case OrderStatus.PREPARING:
        return 'Preparing';
      case OrderStatus.READY:
        return 'Ready';
      case OrderStatus.RIDER_ASSIGNED:
        return 'Rider Assigned';
      case OrderStatus.RIDER_ACCEPTED:
        return 'Rider Accepted';
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
        return 'Picking Up';
      case OrderStatus.PICKED_UP:
        return 'Picked Up';
      case OrderStatus.ON_THE_WAY_TO_DROP:
        return 'On the Way';
      case OrderStatus.DELIVERED:
        return 'Delivered';
      case OrderStatus.CANCELLED:
        return 'Cancelled';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 EMPTY STATE
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
