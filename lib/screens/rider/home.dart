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
import '../../services/rider_notification_listener.dart';
import '../../main.dart';
import '../debug/debug_notifications_screen.dart';
import 'rider_normal_food_request_screen.dart';

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
    print('🚀 [RIDER HOME] initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Check if user is logged in
      if (authProvider.currentUser == null) {
        print('❌ [RIDER HOME] No current user, redirecting to login');
        Navigator.pushReplacementNamed(context, AppRouter.login);
        return;
      }
      
      print('✅ [RIDER HOME] Current user: ${authProvider.currentUser!.uid}');
      
      // ✅ CHECK FOR ACTIVE DELIVERY (NEW)
      _checkActiveDelivery(authProvider.currentUser!.uid);
      
      // 🔔 Initialize local notifications
      print('📱 [RIDER HOME] Initializing local notifications...');
      _initializeLocalNotifications();
      
      // 🔔 Initialize FCM for rider notifications
      print('📱 [RIDER HOME] Initializing FCM...');
      _initializeFCM();
      
      // 🚨 START NOTIFICATION LISTENER FOR POP-UPS (Normal Food Delivery)
      print('🔔 [RIDER HOME] Starting notification listener...');
      RiderNotificationListener().initialize(MyApp.navigatorKey);
      RiderNotificationListener().startListening();
      
      // 🚀 Listen for notification documents
      print('🎧 [RIDER HOME] Setting up notification listener...');
      _listenForNotifications(authProvider.currentUser!.uid);
      
      print('📦 [RIDER HOME] Loading rider deliveries...');
      Provider.of<RiderProvider>(context, listen: false)
          .loadRiderDeliveries(authProvider.currentUser!.uid);
      
      print('✅ [RIDER HOME] Initialization complete');
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
    
    // 🚨 Create notification channel with FULL SCREEN INTENT support (Android)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'delivery_requests', // id
      'Delivery Requests', // name
      description: 'New delivery request notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    print('✅ Local notifications initialized for rider with full-screen support');
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
    print('🎧 [RIDER] Starting notification listener for rider: $riderId');
    print('🎧 [RIDER] Listening to: notifications collection');
    print('🎧 [RIDER] Query: recipientId == $riderId AND read == false');
    
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: riderId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        print('📬 [RIDER] Notification snapshot received');
        print('   - Total docs: ${snapshot.docs.length}');
        print('   - Changes: ${snapshot.docChanges.length}');
        
        // Debug: Print all existing unread notifications
        if (snapshot.docs.isNotEmpty) {
          print('📋 [RIDER] Current unread notifications:');
          for (var doc in snapshot.docs) {
            print('   - ${doc.id}: type=${doc.data()['type']}, order=${doc.data()['orderId']}');
          }
        }
        
        for (var change in snapshot.docChanges) {
          print('📝 [RIDER] Change type: ${change.type}');
          
          if (change.type == DocumentChangeType.added) {
            final notification = change.doc.data();
            print('📨 [RIDER] New notification added:');
            print('   - Doc ID: ${change.doc.id}');
            print('   - Type: ${notification?['type']}');
            print('   - Order ID: ${notification?['orderId']}');
            print('   - Recipient: ${notification?['recipientId']}');
            
            if (notification != null && notification['type'] == 'NEW_DELIVERY_REQUEST') {
              final orderId = notification['orderId'];
              final title = notification['title'] ?? 'New Delivery Request';
              final body = notification['body'] ?? 'You have a new delivery request';
              
              print('🔔 [RIDER] New delivery request received: $orderId');
              print('🚀 [RIDER] Showing delivery request popup...');
              
              // 📱 SHOW LOCAL NOTIFICATION
              _showLocalNotification(orderId, title, body);
              
              // Mark as read
              change.doc.reference.update({'read': true}).then((_) {
                print('✅ [RIDER] Marked notification as read');
              }).catchError((e) {
                print('❌ [RIDER] Failed to mark as read: $e');
              });
              
              // 🆕 SHOW POPUP DIALOG INSTEAD OF DIRECT NAVIGATION
              _showDeliveryRequestDialog(orderId);
            }
          }
        }
      },
      onError: (error) {
        print('❌ [RIDER] Notification listener error: $error');
        print('   This might be a Firestore rules issue!');
      },
    );
    
    print('✅ [RIDER] Notification listener started successfully');
  }
  
  // 📱 Show local notification on rider's device with FULL SCREEN INTENT
  Future<void> _showLocalNotification(String orderId, String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'delivery_requests',
      'Delivery Requests',
      channelDescription: 'New delivery request notifications',
      importance: Importance.max, // ⬆️ CHANGED: Max importance
      priority: Priority.max, // ⬆️ CHANGED: Max priority
      showWhen: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // 🆕 Shows even when screen is locked
      category: AndroidNotificationCategory.call, // 🆕 Treat as incoming call
      visibility: NotificationVisibility.public, // 🆕 Show on lock screen
      ongoing: true, // 🆕 Cannot be dismissed by swiping
      autoCancel: false, // 🆕 Stays until tapped
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive, // 🆕 iOS: Break through focus modes
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
    
    print('📱 Full-screen notification shown: $title');
  }

  // 🔔 Show delivery request popup dialog
  Future<void> _showDeliveryRequestDialog(String orderId) async {
    print('🎯 [POPUP] Showing delivery request dialog for order: $orderId');
    
    // Fetch order details
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    
    if (!orderDoc.exists || !mounted) {
      print('❌ [POPUP] Order not found or widget unmounted');
      return;
    }
    
    final orderData = orderDoc.data()!;
    final pickupAddress = orderData['pickupAddress'] ?? 'N/A';
    final dropAddress = orderData['dropAddress'] ?? 'N/A';
    final distanceKm = orderData['distanceKm'] ?? 0.0;
    final deliveryFee = orderData['deliveryFee'] ?? 0.0;
    final cookName = orderData['cookName'] ?? 'Unknown Cook';
    final customerName = orderData['customerName'] ?? 'Customer';
    
    print('📦 [POPUP] Order details loaded');
    print('   - Cook: $cookName');
    print('   - Customer: $customerName');
    print('   - Fee: ₹$deliveryFee');
    print('   - Distance: $distanceKm km');
    
    // Show popup dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: Color(0xFFFC8019),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'New Delivery Request!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery Fee Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Earn ₹${deliveryFee.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Pickup Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.restaurant,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pickup from:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            cookName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pickupAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Drop Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deliver to:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dropAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Distance
                Row(
                  children: [
                    const Icon(
                      Icons.route,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Distance: ${distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            // Decline Button
            TextButton(
              onPressed: () {
                print('❌ [POPUP] Rider declined order: $orderId');
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            // Accept Button
            ElevatedButton(
              onPressed: () {
                print('✅ [POPUP] Rider accepted order: $orderId');
                Navigator.of(dialogContext).pop();
                
                // Navigate to correct screen based on order type
                final isHomeToOffice = orderData['isHomeToOffice'] ?? false;
                
                if (isHomeToOffice) {
                  // Tiffin service - use original delivery request screen
                  print('🏠 [POPUP] Navigating to Tiffin delivery request');
                  Navigator.pushNamed(
                    context,
                    AppRouter.riderDeliveryRequest,
                    arguments: {'orderId': orderId},
                  );
                } else {
                  // Normal food - use new normal food request screen
                  print('🍔 [POPUP] Navigating to Normal Food delivery request');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RiderNormalFoodRequestScreen(
                        orderId: orderId,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC8019),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Accept Order',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Build widget showing pending orders assigned to rider
  // 🍔 Build Available READY Orders (Normal Food)
  Widget _buildAvailableOrders() {
    print('🔍 [AVAILABLE ORDERS] Building available orders widget');
    print('🔍 [AVAILABLE ORDERS] Query: status=READY (both tiffin and normal food)');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'READY') // Cook marked food ready - includes both order types
          .snapshots(),
      builder: (context, snapshot) {
        print('📊 [AVAILABLE ORDERS] Snapshot state: ${snapshot.connectionState}');
        
        if (snapshot.hasError) {
          print('❌ [AVAILABLE ORDERS] Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading orders',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Trigger rebuild
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ [AVAILABLE ORDERS] Waiting for data...');
          return const Center(child: CircularProgressIndicator());
        }

        final orderCount = snapshot.data?.docs.length ?? 0;
        print('📦 [AVAILABLE ORDERS] Found $orderCount orders');
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('ℹ️ [AVAILABLE ORDERS] No orders available');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No available delivery orders',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Orders will appear here when cooks mark food ready',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;
        // Sort by createdAt in memory (since we removed orderBy to avoid index requirement)
        orders.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order (newest first)
        });
        
        print('✅ [AVAILABLE ORDERS] Displaying ${orders.length} order cards');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id;
            
            print('📋 [AVAILABLE ORDERS] Order $index: $orderId');

            final pickupAddress = orderData['pickupAddress'] ?? 'N/A';
            final dropAddress = orderData['dropAddress'] ?? 'N/A';
            final distanceKm = orderData['distanceKm'] ?? 0.0;
            final deliveryFee = orderData['deliveryFee'] ?? 0.0;
            final cookName = orderData['cookName'] ?? 'Unknown Cook';
            final customerName = orderData['customerName'] ?? 'Customer';
            final isHomeToOffice = orderData['isHomeToOffice'] ?? false;
            
            // Dynamic UI based on order type
            final orderTypeTitle = isHomeToOffice ? 'Tiffin Delivery' : 'Food Delivery';
            final orderTypeIcon = isHomeToOffice ? Icons.work : Icons.restaurant_menu;
            final orderTypeColor = isHomeToOffice ? Colors.blue : Colors.green;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  print('🔄 [AVAILABLE ORDERS] Card tapped for order: $orderId');
                  
                  // Route to correct screen based on order type
                  final isHomeToOffice = orderData['isHomeToOffice'] ?? false;
                  
                  if (isHomeToOffice) {
                    // Tiffin service
                    print('🏠 [AVAILABLE ORDERS] Opening Tiffin delivery request');
                    Navigator.pushNamed(
                      context,
                      AppRouter.riderDeliveryRequest,
                      arguments: {'orderId': orderId},
                    );
                  } else {
                    // Normal food
                    print('🍔 [AVAILABLE ORDERS] Opening Normal Food delivery request');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RiderNormalFoodRequestScreen(
                          orderId: orderId,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: orderTypeColor[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              orderTypeIcon,
                              color: orderTypeColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderTypeTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '₹${deliveryFee.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Pickup Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isHomeToOffice ? Icons.home : Icons.restaurant,
                            color: isHomeToOffice ? Colors.blue : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup from $cookName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  pickupAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
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
                      // Drop Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isHomeToOffice ? Icons.work : Icons.location_on,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Deliver to $customerName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  dropAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
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
                      // Distance and Action Button
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distanceKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.riderDeliveryRequest,
                                arguments: {'orderId': orderId},
                              );
                            },
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFC8019),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🚗 Build My Active Deliveries ListView
  Widget _buildMyDeliveries(RiderProvider riderProvider) {
    return ListView.builder(
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
    );
  }

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
          // 🐛 Debug Notifications Button
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.purple),
            tooltip: 'Debug Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DebugNotificationsScreen(),
                ),
              );
            },
          ),
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
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        // Tab bar for Available Orders vs My Deliveries
                        Container(
                          color: Colors.grey[200],
                          child: const TabBar(
                            labelColor: Color(0xFFFC8019),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Color(0xFFFC8019),
                            tabs: [
                              Tab(
                                icon: Icon(Icons.restaurant_menu),
                                text: 'Available Orders',
                              ),
                              Tab(
                                icon: Icon(Icons.delivery_dining),
                                text: 'My Deliveries',
                              ),
                            ],
                          ),
                        ),
                        // Tab views
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: Available READY orders (normal food)
                              _buildAvailableOrders(),
                              // Tab 2: Assigned/Active deliveries
                              riderProvider.activeDeliveries.isEmpty
                                  ? (authProvider.currentUser != null 
                                      ? _buildPendingOrders(authProvider.currentUser!.uid)
                                      : const Center(child: Text('Please log in')))
                                  : _buildMyDeliveries(riderProvider),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      ), // Close PopScope
    );
  }
}
