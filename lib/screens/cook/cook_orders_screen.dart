import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../../app_router.dart';
import '../../theme.dart';

class CookOrdersScreen extends StatefulWidget {
  const CookOrdersScreen({super.key});

  @override
  State<CookOrdersScreen> createState() => _CookOrdersScreenState();
}

class _CookOrdersScreenState extends State<CookOrdersScreen> {
  String _selectedFilter = 'All';

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
    final ordersProvider = Provider.of<OrdersProvider>(context);
    final filteredOrders = _filterOrders(ordersProvider.orders);

    return Scaffold(
      appBar: AppBar(
        title: Text('Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: ordersProvider.isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          ordersProvider.loadCookOrders(authProvider.currentUser!.uid);
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(filteredOrders[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'New', 'Accepted', 'Preparing', 'Ready'];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              labelStyle: GoogleFonts.poppins(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: Colors.white,
              selectedColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order.orderId.substring(0, 8)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                      child: Text(
                        order.customerName[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '₹${order.total.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      ...order.dishItems.map((item) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${item.dishName} x${item.quantity}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (order.status == OrderStatus.PLACED)
            _buildActionButtons(order.orderId, 'placed')
          else if (order.status == OrderStatus.ACCEPTED)
            _buildActionButtons(order.orderId, 'accepted')
          else if (order.status == OrderStatus.PREPARING)
            _buildActionButtons(order.orderId, 'preparing'),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    String text;

    switch (status) {
      case OrderStatus.PLACED:
        color = Colors.orange;
        text = 'New Order';
        break;
      case OrderStatus.ACCEPTED:
        color = Colors.blue;
        text = 'Accepted';
        break;
      case OrderStatus.PREPARING:
        color = Colors.purple;
        text = 'Preparing';
        break;
      case OrderStatus.READY:
        color = AppTheme.successGreen;
        text = 'Ready';
        break;
      case OrderStatus.DELIVERED:
        color = AppTheme.successGreen;
        text = 'Delivered';
        break;
      default:
        color = Colors.grey;
        text = status.name;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButtons(String orderId, String orderStatus) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (orderStatus == 'placed') ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectOrder(orderId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _acceptOrder(orderId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Accept', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          if (orderStatus == 'accepted')
            Expanded(
              child: ElevatedButton(
                onPressed: () => _markPreparing(orderId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Start Preparing', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          if (orderStatus == 'preparing')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _markReady(orderId),
                icon: Icon(Icons.restaurant_menu),
                label: Text('Food Ready', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/lottie/cheff_cooking.json', width: 250, height: 250),
          SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    if (_selectedFilter == 'All') return orders;

    return orders.where((order) {
      switch (_selectedFilter) {
        case 'New':
          return order.status == OrderStatus.PLACED;
        case 'Accepted':
          return order.status == OrderStatus.ACCEPTED;
        case 'Preparing':
          return order.status == OrderStatus.PREPARING;
        case 'Ready':
          return order.status == OrderStatus.READY;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _acceptOrder(String orderId) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.updateOrderStatus(orderId, OrderStatus.ACCEPTED);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order accepted'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.updateOrderStatus(orderId, OrderStatus.CANCELLED);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order rejected'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markPreparing(String orderId) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.updateOrderStatus(orderId, OrderStatus.PREPARING);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked as preparing'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  Future<void> _markReady(String orderId) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.updateOrderStatus(orderId, OrderStatus.READY);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Food is ready!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }
}
