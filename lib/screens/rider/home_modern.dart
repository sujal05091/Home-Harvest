import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../models/delivery_model.dart';
import '../../models/order_model.dart';
import '../../app_router.dart';
import '../../widgets/rider_active_delivery_bar.dart';
import '../../services/fcm_service.dart';
import '../../services/wallet_service.dart';
import '../../models/rider_wallet_model.dart';
import '../../services/rider_notification_listener.dart';
import '../../main.dart';

class RiderHomeModernScreen extends StatefulWidget {
  const RiderHomeModernScreen({super.key});

  @override
  State<RiderHomeModernScreen> createState() => _RiderHomeModernScreenState();
}

class _RiderHomeModernScreenState extends State<RiderHomeModernScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _activeOrderSubscription;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // 🚚 Active order tracking
  bool _hasActiveDelivery = false;
  OrderModel? _activeOrder;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser == null) {
        Navigator.pushReplacementNamed(context, AppRouter.login);
        return;
      }

      print('✅ [RIDER HOME MODERN] Current user: ${authProvider.currentUser!.uid}');

      _checkActiveDelivery(authProvider.currentUser!.uid);
      _initializeLocalNotifications();
      _initializeFCM();
      
      // 🚨 START NOTIFICATION LISTENER FOR POP-UPS (Normal Food Delivery)
      print('🔔 [RIDER HOME MODERN] Starting notification listener...');
      RiderNotificationListener().initialize(MyApp.navigatorKey);
      RiderNotificationListener().startListening();
      
      _listenForNotifications(authProvider.currentUser!.uid);
      _listenToActiveOrders(authProvider.currentUser!.uid);

      Provider.of<RiderProvider>(context, listen: false)
          .loadRiderDeliveries(authProvider.currentUser!.uid);
    });
  }

  Future<void> _checkActiveDelivery(String riderId) async {
    try {
      final activeDeliverySnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('riderId', isEqualTo: riderId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeDeliverySnapshot.docs.isNotEmpty) {
        final deliveryDoc = activeDeliverySnapshot.docs.first;
        final orderId = deliveryDoc.data()['orderId'];

        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRouter.riderDeliveryRequest,
            arguments: {'orderId': orderId},
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          Navigator.pushNamed(
            context,
            AppRouter.riderDeliveryRequest,
            arguments: {'orderId': response.payload},
          );
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'delivery_requests',
      'Delivery Requests',
      description: 'New delivery request notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeFCM() async {
    try {
      await FCMService().initialize();
      await FCMService().saveFCMToken();
    } catch (e) {
      // Silent fail
    }
  }

  void _listenForNotifications(String riderId) {
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: riderId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final notification = change.doc.data();

            if (notification != null &&
                notification['type'] == 'NEW_DELIVERY_REQUEST') {
              final orderId = notification['orderId'];
              final title = notification['title'] ?? 'New Delivery Request';
              final body =notification['body'] ?? 'You have a new delivery request';

              _showLocalNotification(orderId, title, body);
              change.doc.reference.update({'read': true});

              Navigator.pushNamed(
                context,
                AppRouter.riderDeliveryRequest,
                arguments: {'orderId': orderId},
              );
            }
          }
        }
      },
      onError: (error) {},
    );
  }

  Future<void> _showLocalNotification(
      String orderId, String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'delivery_requests',
      'Delivery Requests',
      channelDescription: 'New delivery request notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      orderId.hashCode,
      title,
      body,
      notificationDetails,
      payload: orderId,
    );
  }

  // 🔥 Real-time listener for active deliveries
  void _listenToActiveOrders(String riderId) {
    // Cancel existing subscription if any
    _activeOrderSubscription?.cancel();
    
    // Calculate cutoff time (24 hours ago)
    final cutoffTime = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );
    
    // Listen to active orders in real-time
    _activeOrderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('assignedRiderId', isEqualTo: riderId)
        .where('isActive', isEqualTo: true)
        .where('createdAt', isGreaterThan: cutoffTime)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      // Find active delivery order (not delivered or cancelled)
      final activeOrders = snapshot.docs.where((doc) {
        final status = doc.data()['status'] as String?;
        return status != null && 
               status != 'DELIVERED' && 
               status != 'CANCELLED' &&
               status != 'PLACED' &&
               status != 'ACCEPTED' &&
               status != 'PREPARING' &&
               status != 'READY';
      }).toList();
      
      if (activeOrders.isNotEmpty) {
        final orderDoc = activeOrders.first;
        final order = OrderModel.fromFirestore(orderDoc);
        
        setState(() {
          _hasActiveDelivery = true;
          _activeOrder = order;
        });
        
        print('✅ [RIDER] Active delivery detected: ${order.orderId} | Status: ${order.status}');
      } else {
        setState(() {
          _hasActiveDelivery = false;
          _activeOrder = null;
        });
        
        print('ℹ️ [RIDER] No active delivery');
      }
    }, onError: (error) {
      print('❌ Error listening to active orders: $error');
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _activeOrderSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final riderProvider = Provider.of<RiderProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Exit App', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text('Do you want to exit the app?',
                style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Yes', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
            slivers: [
              // Modern App Bar with Gradient
              SliverAppBar(
                expandedHeight: 240,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/r-back1.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      // Overlay to ensure text readability
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
                          child: Column(
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
                                  child: const Icon(Icons.delivery_dining,
                                      color: Colors.white, size: 32),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hey Rider!',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      Text(
                                        authProvider.currentUser?.name ??
                                            'Welcome',
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
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
                            const SizedBox(height: 12),
                            // 💰 Wallet Balance Display
                            StreamBuilder<RiderWalletModel?>(
                              stream: WalletService().streamRiderWallet(authProvider.currentUser!.uid),
                              builder: (context, snapshot) {
                                final balance = snapshot.data?.walletBalance ?? 0.0;
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, AppRouter.riderEarnings),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                            size: 20,
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
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '₹${balance.toStringAsFixed(2)}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 20,
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
                      ),
                    ),
                  ),
                ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_outline, color: Colors.white),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRouter.profile),
                  ),
                ],
              ),

              // Availability Toggle Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: riderProvider.isAvailable
                            ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                            : [const Color(0xFFEF5350), const Color(0xFFE57373)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (riderProvider.isAvailable
                                  ? Colors.green
                                  : Colors.red)
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              riderProvider.isAvailable
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  riderProvider.isAvailable
                                      ? 'You\'re Online'
                                      : 'You\'re Offline',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  riderProvider.isAvailable
                                      ? 'Ready to accept deliveries'
                                      : 'Toggle to start accepting',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 1.1,
                            child: Switch(
                              value: riderProvider.isAvailable,
                              onChanged: (_) => riderProvider.toggleAvailability(),
                              activeColor: Colors.white,
                              activeTrackColor: Colors.white.withOpacity(0.5),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Active',
                          '${riderProvider.activeDeliveries.length}',
                          Icons.local_shipping_outlined,
                          const Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildStatCard(
                          'Requests',
                          '${riderProvider.availableOrders.length}',
                          Icons.notifications_active_outlined,
                          const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Deliveries Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Your Deliveries',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 15)),

              // Deliveries List
              riderProvider.isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : riderProvider.activeDeliveries.isEmpty &&
                          riderProvider.availableOrders.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyState(),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index < riderProvider.availableOrders.length) {
                                  final order = riderProvider.availableOrders[index];
                                  return _buildNewRequestCard(order);
                                } else {
                                  final delivery = riderProvider.activeDeliveries[
                                      index - riderProvider.availableOrders.length];
                                  return _buildActiveDeliveryCard(delivery);
                                }
                              },
                              childCount: riderProvider.availableOrders.length +
                                  riderProvider.activeDeliveries.length,
                            ),
                          ),
                        ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        
        // 🚚 Active Delivery Banner (positioned at bottom)
        if (_hasActiveDelivery && _activeOrder != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: RiderActiveDeliveryBar(activeOrder: _activeOrder),
          ),
      ],
    ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
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
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining,
              size: 80,
              color: const Color(0xFFFF6B35).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Active Deliveries',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Turn on availability to start\nreceiving delivery requests',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewRequestCard(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRouter.riderDeliveryRequest,
              arguments: {'orderId': order.orderId},
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.notification_important,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEW REQUEST',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.customerName ?? 'Customer',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${order.deliveryCharge?.toStringAsFixed(0) ?? '0'} • ${(order.distance ?? 0).toStringAsFixed(1)} km',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryCard(DeliveryModel delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 🚀 Navigate to modern delivery tracking screen
            Navigator.pushNamed(
              context,
              AppRouter.riderDeliveryRequest,
              arguments: {'orderId': delivery.orderId},
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: Color(0xFF2196F3), size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${delivery.orderId.substring(0, 8)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${delivery.status.name} • ${delivery.distanceKm?.toStringAsFixed(1) ?? "N/A"} km',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Color(0xFF2196F3), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
