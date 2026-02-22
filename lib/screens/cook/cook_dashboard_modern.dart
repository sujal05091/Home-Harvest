import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/dishes_provider.dart';
import '../../models/order_model.dart';
import '../../models/cook_wallet_model.dart';
import '../../services/cook_wallet_service.dart';
import '../../app_router.dart';
import '../../theme.dart';
import '../../test_cook_notification.dart';
import '../../services/fcm_service.dart';

class CookDashboardModernScreen extends StatefulWidget {
  const CookDashboardModernScreen({super.key});

  @override
  State<CookDashboardModernScreen> createState() => _CookDashboardModernScreenState();
}

class _CookDashboardModernScreenState extends State<CookDashboardModernScreen> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final CookWalletService cookWalletService = CookWalletService();
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<OrdersProvider>(context, listen: false)
          .loadCookOrders(authProvider.currentUser!.uid);
      Provider.of<DishesProvider>(context, listen: false)
          .loadCookDishes(authProvider.currentUser!.uid);
      
      // 🔔 Save FCM token for push notifications
      FCMService().saveFCMToken();
      
      // 🔔 Listen for new order notifications
      _listenForNewOrders(authProvider.currentUser!.uid);
    });
  }
  
  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(initSettings);
    print('✅ [Cook] Local notifications initialized');
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// 🔔 Listen for new order notifications and show popup
  void _listenForNewOrders(String cookId) {
    print('🔔 [Cook] Starting notification listener for cook: $cookId');
    print('   Listening for: recipientId=$cookId, type=NEW_ORDER, read=false');
    
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: cookId)
        .where('type', isEqualTo: 'NEW_ORDER')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        print('📬 [Cook] Notification snapshot received: ${snapshot.docs.length} docs');
        
        if (snapshot.docs.isEmpty) {
          print('   ℹ️ No unread NEW_ORDER notifications found');
        }
        
        for (var doc in snapshot.docChanges) {
          print('   Change type: ${doc.type}');
          
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data() as Map<String, dynamic>;
            print('🔔 [Cook] New order notification received!');
            print('   Document ID: ${doc.doc.id}');
            print('   Order ID: ${data['orderId']}');
            print('   Title: ${data['title']}');
            print('   Body: ${data['body']}');
            print('   🎉 Showing notification and popup...');
            
            // 🔔 Show system notification in notification bar (don't wait)
            _showSystemNotification(
              title: data['title'] ?? '🔔 New Order!',
              body: data['body'] ?? 'New order received',
              orderId: data['orderId'] ?? '',
            );
            
            // 🎉 Show popup dialog IMMEDIATELY (in parallel)
            print('🎉 Showing popup dialog NOW...');
            _showNewOrderDialog(
              orderId: data['orderId'] ?? '',
              customerName: data['data']?['customerName'] ?? 'Customer',
              dishNames: data['data']?['dishNames'] ?? 'Food items',
              totalAmount: (data['data']?['totalAmount'] ?? 0).toDouble(),
              notificationId: doc.doc.id,
            );
          }
        }
      },
      onError: (error) {
        print('❌ [Cook] Notification listener error: $error');
      },
    );
    
    print('✅ [Cook] Notification listener set up successfully');
    print('   Waiting for notifications...');
  }

  /// 🔔 Show system notification in Android notification bar
  Future<void> _showSystemNotification({
    required String title,
    required String body,
    required String orderId,
  }) async {
    try {
      print('📲 [SystemNotification] Showing in notification bar...');
      print('   Title: $title');
      print('   Body: $body');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'cook_orders',
        'Cook Orders',
        channelDescription: 'Notifications for new cook orders',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true, // Shows as heads-up notification
        color: Color(0xFFFF6B35),
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Use order ID hash as notification ID to avoid duplicates
      final notificationId = orderId.hashCode;
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformDetails,
      );
      
      print('✅ [SystemNotification] Shown successfully with ID: $notificationId');
    } catch (e) {
      print('❌ [SystemNotification] Error: $e');
    }
  }

  /// 🎉 Show new order dialog popup
  void _showNewOrderDialog({
    required String orderId,
    required String customerName,
    required String dishNames,
    required double totalAmount,
    required String notificationId,
  }) {
    print('📱 [Dialog] _showNewOrderDialog called');
    print('   mounted: $mounted');
    
    if (!mounted) {
      print('❌ [Dialog] Widget not mounted, cannot show dialog');
      return;
    }
    
    // Add haptic feedback for extra attention
    HapticFeedback.vibrate();
    
    print('✅ [Dialog] Showing dialog NOW (no delay)...');
    
    // Show dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87, // Dark background to make dialog stand out
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false, // Prevent back button from closing
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_menu, color: AppTheme.primaryColor, size: 30),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔔 New Order!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      'Order #${orderId.substring(0, 8)}',
                      style: GoogleFonts.poppins(
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
                Navigator.pop(dialogContext);
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
                Navigator.pop(dialogContext);
                // Refresh orders list
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                Provider.of<OrdersProvider>(context, listen: false)
                    .loadCookOrders(authProvider.currentUser!.uid);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('View Order', style: TextStyle(color: Colors.white)),
            ),
          ],
            ), // Close AlertDialog
          ), // Close WillPopScope
    ).then((value) => print('✅ [Dialog] Dialog closed'));
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
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
    final dishesProvider = Provider.of<DishesProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) return SizedBox();

    final pendingOrders = ordersProvider.orders
        .where((o) => o.status == OrderStatus.PLACED || o.status == OrderStatus.ACCEPTED)
        .length;
    // Remove local todayEarnings calculation - now using wallet
    final newOrders = ordersProvider.orders
        .where((o) => o.status == OrderStatus.PLACED || o.status == OrderStatus.ACCEPTED || o.status == OrderStatus.PREPARING)
        .take(5)
        .toList();
    
    final cookWalletService = CookWalletService();

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
        backgroundColor: Color(0xFFF5F5F5),
        body: RefreshIndicator(
          onRefresh: () async {
            ordersProvider.loadCookOrders(user.uid);
            dishesProvider.loadCookDishes(user.uid);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user),
                // Real-time wallet balance
                StreamBuilder<CookWalletModel?>(
                  stream: cookWalletService.streamCookWallet(user.uid),
                  builder: (context, snapshot) {
                    final wallet = snapshot.data ?? CookWalletModel.initial(user.uid);
                    return _buildStatsCards(
                      pendingOrders,
                      wallet.walletBalance,
                      wallet.todayEarnings,
                      user.verified,
                    );
                  },
                ),
                _buildNewOrders(newOrders, ordersProvider),
                _buildManageDishes(dishesProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(user) {
    return Container(
      width: double.infinity,
      height: 340,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/c_back.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        // Overlay for better text readability
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.restaurant_menu,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hey Cook!',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              Text(
                                user.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // Wallet Balance Display
                    StreamBuilder<CookWalletModel?>(
                  stream: cookWalletService.streamCookWallet(user.uid),
                  builder: (context, snapshot) {
                    final wallet = snapshot.data ?? CookWalletModel.initial(user.uid);
                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRouter.cookWithdraw),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF4CAF50),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available Balance',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '₹${wallet.walletBalance.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            // Profile icon positioned at top right
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.person_outline, color: Colors.white, size: 28),
                onPressed: () => Navigator.pushNamed(context, AppRouter.profile),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(int pending, double balance, double todayEarnings, bool verified) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '$pending',
              'Pending Orders',
              Icons.assignment_outlined,
              Color(0xFFFFE5D4),
              AppTheme.primaryOrange,
              null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRouter.cookEarnings),
              child: _buildStatCard(
                '₹${todayEarnings.toStringAsFixed(0)}',
                'Today\'s Earnings',
                Icons.currency_rupee,
                Color(0xFFFFF9E5),
                Color(0xFFDAA520),
                Icons.arrow_forward_ios,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              verified ? 'Verified' : 'In Review',
              'Verification',
              Icons.verified_user_outlined,
              Color(0xFFE5F5E5),
              AppTheme.successGreen,
              null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color bgColor, Color iconColor, IconData? actionIcon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              if (actionIcon != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(actionIcon, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionIcon != null) ...[
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: iconColor, size: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewOrders(List<OrderModel> orders, OrdersProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Orders',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          orders.isEmpty
              ? Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                        SizedBox(height: 12),
                        Text(
                          'No new orders',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: orders.map((order) => _buildNewOrderCard(order, provider)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildNewOrderCard(OrderModel order, OrdersProvider provider) {
    final isAccepted = order.status == OrderStatus.ACCEPTED || order.status == OrderStatus.PREPARING;
    final preparingTime = order.status == OrderStatus.PREPARING ? 'Preparing' : '5 mins';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      order.dropAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRouter.cookOrders);
                },
                icon: Icon(Icons.arrow_forward, size: 18),
                label: Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAccepted ? AppTheme.successGreen : AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Dish ready in: ',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status == OrderStatus.PREPARING 
                      ? Colors.purple.shade50 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  preparingTime,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: order.status == OrderStatus.PREPARING 
                        ? Colors.purple 
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (order.status == OrderStatus.PLACED) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await provider.updateOrderStatus(order.orderId, OrderStatus.ACCEPTED);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successGreen,
                      side: BorderSide(color: AppTheme.successGreen),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Accept', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await provider.updateOrderStatus(order.orderId, OrderStatus.CANCELLED);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.ACCEPTED) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  print('🟡 [Cook] Start Preparing clicked for ${order.orderId}');
                  await provider.updateOrderStatus(order.orderId, OrderStatus.PREPARING);
                },
                icon: Icon(Icons.restaurant_menu),
                label: Text('👨‍🍳 Start Preparing', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (order.status == OrderStatus.PREPARING) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markFoodReady(order.orderId),
                icon: Icon(Icons.check_circle),
                label: Text('✅ Food Ready', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManageDishes(DishesProvider provider) {
    final dishes = provider.dishes.take(3).toList();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Dishes',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (dishes.isNotEmpty)
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.cookDishes),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    'View All',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          dishes.isEmpty
              ? Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.restaurant_menu, size: 48, color: Colors.grey.shade300),
                        SizedBox(height: 12),
                        Text(
                          'No dishes added yet',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: dishes.length,
                  itemBuilder: (context, index) {
                    final dish = dishes[index];
                    return _buildDishCard(dish);
                  },
                ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.addDish),
                  icon: Icon(Icons.add),
                  label: Text('Add Dish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (dishes.isNotEmpty) ...[
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.cookDishes),
                    icon: Icon(Icons.edit),
                    label: Text('Manage All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOrange,
                      side: BorderSide(color: AppTheme.primaryOrange),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(dish) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: dish.imageUrl.isNotEmpty
                    ? Image.network(
                        dish.imageUrl,
                        height: 80,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          color: Colors.grey.shade200,
                          child: Icon(Icons.restaurant, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 80,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.restaurant, color: Colors.grey),
                      ),
              ),
              if (!dish.isAvailable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OUT OF STOCK',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '₹${dish.price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTodayEarnings(List orders) {
    final today = DateTime.now();
    return orders
        .where((o) =>
            o.createdAt != null &&
            o.createdAt.year == today.year &&
            o.createdAt.month == today.month &&
            o.createdAt.day == today.day &&
            o.status == OrderStatus.DELIVERED)
        .fold(0.0, (sum, o) => sum + o.total);
  }

  Future<void> _markFoodReady(String orderId) async {
    print('🔴 [Cook] BUTTON CLICKED! Calling _markFoodReady for $orderId');
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark Food Ready?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will notify nearby riders to pick up the order.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Mark Ready', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('🟢 [Cook] Confirmation received, updating order status...');
      
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Update order status to READY
        final provider = Provider.of<OrdersProvider>(context, listen: false);
        final success = await provider.updateOrderStatus(
          orderId,
          OrderStatus.READY,
        );

        if (success) {
          print('✅ [Cook] Order status updated to READY');
          
          // Fetch order document to get location
          final orderDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();

          if (orderDoc.exists) {
            final orderData = orderDoc.data()!;
            final pickupLocation = orderData['pickupLocation'] as GeoPoint;
            
            print('🚀 [Cook] Calling FCMService().notifyNearbyRiders()');
            print('   Order ID: $orderId');
            print('   Pickup Lat: ${pickupLocation.latitude}');
            print('   Pickup Lng: ${pickupLocation.longitude}');

            // Notify nearby riders
            await FCMService().notifyNearbyRiders(
              orderId: orderId,
              pickupLat: pickupLocation.latitude,
              pickupLng: pickupLocation.longitude,
              radiusKm: 5.0,
            );

            print('✅ [Cook] FCMService completed successfully!');
          } else {
            print('❌ [Cook] Order document not found: $orderId');
          }
        } else {
          print('❌ [Cook] Failed to update order status');
        }
      } catch (e) {
        print('❌ [Cook] Error in _markFoodReady: $e');
      } finally {
        // Close loading dialog
        if (mounted) Navigator.pop(context);
      }
    } else {
      print('🟡 [Cook] User cancelled marking food ready');
    }
  }
}
