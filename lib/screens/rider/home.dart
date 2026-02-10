import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../models/delivery_model.dart';
import '../../app_router.dart';
import '../../services/fcm_service.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Check if user is logged in
      if (authProvider.currentUser == null) {
        print('❌ No current user, redirecting to login');
        Navigator.pushReplacementNamed(context, AppRouter.login);
        return;
      }
      
      // � CHECK FOR ACTIVE DELIVERY (NEW)
      _checkActiveDelivery(authProvider.currentUser!.uid);
      
      // 🔔 Initialize local notifications
      _initializeLocalNotifications();
      
      // 🔔 Initialize FCM for rider notifications
      _initializeFCM();
      
      // 🚀 Listen for notification documents
      _listenForNotifications(authProvider.currentUser!.uid);
      
      Provider.of<RiderProvider>(context, listen: false)
          .loadRiderDeliveries(authProvider.currentUser!.uid);
    });
  }
  
  // 🚀 Check for active delivery on app launch
  Future<void> _checkActiveDelivery(String riderId) async {
    try {
      print('🔍 Checking for active delivery for rider: $riderId');
      
      final activeOrderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('assignedRiderId', isEqualTo: riderId)
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: ['RIDER_ACCEPTED', 'ON_THE_WAY_TO_PICKUP', 'PICKED_UP', 'ON_THE_WAY_TO_DROP'])
          .limit(1)
          .get();
      
      if (activeOrderSnapshot.docs.isNotEmpty) {
        final orderDoc = activeOrderSnapshot.docs.first;
        final orderId = orderDoc.id;
        
        print('✅ Active delivery found: $orderId');
        
        // Auto-navigate to delivery screen
        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRouter.riderDeliveryRequest,
            arguments: {'orderId': orderId},
          );
        }
      } else {
        print('ℹ️ No active delivery found');
      }
    } catch (e) {
      print('❌ Error checking active delivery: $e');
    }
  }
  
  // 🔔 Initialize Local Notifications
  Future<void> _initializeLocalNotifications() async {
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
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // When notification is tapped, navigate to delivery request
        if (response.payload != null) {
          Navigator.pushNamed(
            context,
            AppRouter.riderDeliveryRequest,
            arguments: {'orderId': response.payload},
          );
        }
      },
    );
    
    print('✅ Local notifications initialized for rider');
  }
  
  // 🚀 Initialize FCM and save token
  Future<void> _initializeFCM() async {
    try {
      await FCMService().initialize();
      await FCMService().saveFCMToken();
      print('✅ Rider FCM initialized and token saved');
    } catch (e) {
      print('⚠️ FCM initialization failed: $e');
    }
  }

  // 📩 Listen for new notification documents in Firestore
  void _listenForNotifications(String riderId) {
    print('🎧 Starting notification listener for rider: $riderId');
    
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: riderId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        print('📬 Notification snapshot received: ${snapshot.docChanges.length} changes');
        
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final notification = change.doc.data();
            print('📨 New notification: ${notification?['type']}');
            
            if (notification != null && notification['type'] == 'NEW_DELIVERY_REQUEST') {
              final orderId = notification['orderId'];
              final title = notification['title'] ?? 'New Delivery Request';
              final body = notification['body'] ?? 'You have a new delivery request';
              
              print('🔔 New delivery request received: $orderId');
              
              // 📱 SHOW LOCAL NOTIFICATION
              _showLocalNotification(orderId, title, body);
              
              // Mark as read
              change.doc.reference.update({'read': true});
              
              // Show the delivery request dialog
              Navigator.pushNamed(
                context,
                AppRouter.riderDeliveryRequest,
                arguments: {'orderId': orderId},
              );
            }
          }
        }
      },
      onError: (error) {
        print('❌ Notification listener error: $error');
      },
    );
  }
  
  // 📱 Show local notification on rider's device
  Future<void> _showLocalNotification(String orderId, String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'delivery_requests',
      'Delivery Requests',
      channelDescription: 'New delivery request notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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
    
    print('📱 Local notification shown: $title');
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Build widget showing pending orders assigned to rider
  Widget _buildPendingOrders(String riderId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('assignedRiderId', isEqualTo: riderId)
          .where('status', isEqualTo: 'RIDER_ASSIGNED')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending delivery requests',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'You will be notified when new orders are assigned',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFC8019),
                  child: Icon(Icons.shopping_bag, color: Colors.white),
                ),
                title: Text('Order #${orderId.substring(0, 8)}'),
                subtitle: Text(
                  'Customer: ${orderData['customerName'] ?? 'Unknown'}\n'
                  'From: ${orderData['pickupAddress'] ?? 'N/A'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.riderDeliveryRequest,
                      arguments: {'orderId': orderId},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC8019),
                  ),
                  child: const Text('View'),
                ),
              ),
            );
          },
        );
      },
    );
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
          title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, AppRouter.profile),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: riderProvider.isAvailable ? Colors.green : Colors.red,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  riderProvider.isAvailable ? 'Available' : 'Offline',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Switch(
                  value: riderProvider.isAvailable,
                  onChanged: (_) => riderProvider.toggleAvailability(),
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),
          Expanded(
            child: riderProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : riderProvider.activeDeliveries.isEmpty
                    ? (authProvider.currentUser != null 
                        ? _buildPendingOrders(authProvider.currentUser!.uid)
                        : const Center(child: Text('Please log in')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: riderProvider.activeDeliveries.length,
                        itemBuilder: (context, index) {
                          final delivery = riderProvider.activeDeliveries[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              title: Text('Delivery #${delivery.deliveryId.substring(0, 8)}'),
                              subtitle: Text(
                                'Status: ${delivery.status.name}\n'
                                'Distance: ${delivery.distanceKm?.toStringAsFixed(1) ?? "N/A"} km',
                              ),
                              trailing: delivery.status.name == 'ASSIGNED'
                                  ? ElevatedButton(
                                      onPressed: () {
                                        // Navigate to delivery request details
                                        Navigator.pushNamed(
                                          context,
                                          AppRouter.riderDeliveryRequest,
                                          arguments: {
                                            'orderId': delivery.orderId,
                                          },
                                        );
                                      },
                                      child: const Text('View Request'),
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        // Navigate to active navigation
                                        Navigator.pushNamed(
                                          context,
                                          AppRouter.riderNavigationOSM,
                                          arguments: {
                                            'deliveryId': delivery.deliveryId,
                                            'orderId': delivery.orderId,
                                          },
                                        );
                                      },
                                      child: const Text('Navigate'),
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      ), // Close PopScope
    );
  }
}
