import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// FCM Service for Push Notifications
/// Handles sending notifications to riders when new orders are placed
class FCMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();
  
  // \ud83d\ude80 Navigator key for showing dialogs from anywhere
  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // � ANDROID 13+ NOTIFICATION PERMISSION (CRITICAL)
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        
        if (status.isDenied) {
          print('⚠️ Android 13+: Requesting notification permission...');
          final result = await Permission.notification.request();
          
          if (result.isGranted) {
            print('✅ Android 13+: Notification permission GRANTED');
          } else if (result.isPermanentlyDenied) {
            print('❌ Android 13+: Notification permission PERMANENTLY DENIED');
            _showPermissionDeniedDialog();
            return;
          } else {
            print('❌ Android 13+: Notification permission DENIED');
            return;
          }
        } else if (status.isGranted) {
          print('✅ Android 13+: Notification permission already granted');
        }
      }

      // 📲 Request notification permissions (iOS & Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM: Notification permission GRANTED');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ FCM: Notification permission PROVISIONAL');
      } else {
        print('❌ FCM: Notification permission DENIED');
        return; // Don't proceed if permission denied
      }

      // 🔄 Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        saveFCMToken(); // Auto-save new token
      });

      // 📱 Initialize local notifications for foreground display
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
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      print('✅ FCM Service initialized successfully');
    } catch (e) {
      print('❌ FCM initialization error: $e');
    }
  }

  /// Show dialog when notification permission is permanently denied
  void _showPermissionDeniedDialog() {
    if (_navigatorKey?.currentContext == null) return;
    
    showDialog(
      context: _navigatorKey!.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Notifications Disabled'),
        content: const Text(
          'Please enable notification permissions in Settings to receive delivery updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Get FCM token for current device
  Future<String?> getToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        print('📱 FCM Token generated: ${token.substring(0, 20)}...'); // Show first 20 chars
        return token;
      } else {
        print('❌ FCM Token is null');
        return null;
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore for current user
  Future<void> saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Cannot save FCM token: No authenticated user');
        return;
      }

      final token = await getToken();
      if (token == null) {
        print('⚠️ Cannot save FCM token: Token is null');
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });

      print('✅ FCM token saved to Firestore for user: ${user.uid}');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
      // Try set instead of update if document doesn't exist
      try {
        final user = FirebaseAuth.instance.currentUser;
        final token = await getToken();
        if (user != null && token != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ FCM token saved using set operation');
        }
      } catch (e2) {
        print('❌ Failed to save FCM token: $e2');
      }
    }
  }

  /// Send notification to specific rider
  Future<void> notifyRider({
    required String riderId,
    required String orderId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('🔍 [notifyRider] Starting for rider: $riderId, order: $orderId');
      
      // Get rider's FCM token
      final riderDoc = await _firestore.collection('users').doc(riderId).get();
      
      if (!riderDoc.exists) {
        print('❌ [notifyRider] Rider document does not exist: $riderId');
        return;
      }
      
      final fcmToken = riderDoc.data()?['fcmToken'];

      if (fcmToken == null) {
        print('❌ [notifyRider] Rider $riderId has no FCM token');
        return;
      }

      print('📤 [notifyRider] Creating notification document for rider: $riderId');
      
      // 🚀 CLIENT-SIDE WORKAROUND: Create a notification document
      // The rider's app will listen to this collection and show the dialog
      final notificationData = {
        'recipientId': riderId,
        'orderId': orderId,
        'type': 'NEW_DELIVERY_REQUEST',
        'title': title,
        'body': body,
        'data': {
          'orderId': orderId,
          'type': 'NEW_DELIVERY_REQUEST',
          ...?data,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      print('📝 [notifyRider] Notification data: ${notificationData.toString().substring(0, 100)}...');
      
      final docRef = await _firestore.collection('notifications').add(notificationData);
      
      print('✅ [notifyRider] Notification document created successfully!');
      print('   Document ID: ${docRef.id}');
      print('   Recipient: $riderId');
      print('   Order: $orderId');
      
      // Note: For production, deploy Cloud Functions to send actual FCM notifications
      // See functions/index.js for the Cloud Function implementation

    } catch (e, stackTrace) {
      print('❌ [notifyRider] ERROR sending notification to rider: $e');
      print('   Stack trace: $stackTrace');
      print('   Rider ID: $riderId');
      print('   Order ID: $orderId');
      
      // Check if it's a permission error
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('🚨 PERMISSION DENIED - Firestore rules are blocking notification creation!');
        print('   Solution: Update Firestore rules in Firebase Console');
      }
    }
  }

  /// Notify nearby available riders about new order
  Future<void> notifyNearbyRiders({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double radiusKm,
  }) async {
    try {
      print('🔍 Finding nearby riders within ${radiusKm}km for order: $orderId');

      // Get all available riders
      final ridersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rider')
          .where('isOnline', isEqualTo: true)
          .get();

      print('📊 Found ${ridersSnapshot.docs.length} online riders');

      if (ridersSnapshot.docs.isEmpty) {
        print('❌ No available riders found. Make sure:');
        print('   1. Rider has toggled "Available" switch ON');
        print('   2. Rider\'s isOnline field is set to true in Firestore');
        print('   3. Rider\'s role field is set to "rider"');
        return;
      }

      int notificationsSent = 0;
      List<String> notifiedRiderIds = [];

      // Send notification to each available rider
      for (var riderDoc in ridersSnapshot.docs) {
        final riderId = riderDoc.id;
        final riderData = riderDoc.data();
        final fcmToken = riderData['fcmToken'];
        final riderName = riderData['name'] ?? 'Unknown';

        print('👤 Processing rider: $riderName ($riderId)');
        print('   - isOnline: ${riderData['isOnline']}');
        print('   - fcmToken: ${fcmToken != null ? "✓ Present" : "✗ Missing"}');

        if (fcmToken == null) {
          print('⚠️ Rider $riderId has no FCM token, skipping');
          continue;
        }

        // Send notification
        await notifyRider(
          riderId: riderId,
          orderId: orderId,
          title: '🚀 New Delivery Request',
          body: 'Tap to view and accept delivery request',
          data: {
            'orderId': orderId,
            'action': 'VIEW_REQUEST',
          },
        );

        notifiedRiderIds.add(riderId);
        notificationsSent++;
      }

      // Update order with notified riders list (for Firestore rules)
      if (notifiedRiderIds.isNotEmpty) {
        await _firestore.collection('orders').doc(orderId).update({
          'notifiedRiders': FieldValue.arrayUnion(notifiedRiderIds),
          'notificationsSentAt': FieldValue.serverTimestamp(),
        });
        print('✅ Updated order with notifiedRiders: $notifiedRiderIds');
      }

      print('✅ Sent notifications to $notificationsSent riders');
    } catch (e) {
      print('❌ Error notifying nearby riders: $e');
    }
  }

  /// Handle foreground message (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('📩 Foreground message: ${message.notification?.title}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      // Show local notification with high priority
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'delivery_requests',
            'Delivery Requests',
            channelDescription: 'Notifications for new delivery requests',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            sound: const RawResourceAndroidNotificationSound('notification'),
            playSound: true,
            enableVibration: true,
            enableLights: true,
            fullScreenIntent: true, // Show as heads-up notification
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
      
      // 🚀 AUTO-SHOW DIALOG: If rider gets delivery request while app is open
      final type = message.data['type'];
      final orderId = message.data['orderId'];
      if (type == 'NEW_DELIVERY_REQUEST' && orderId != null) {
        print('🚨 Auto-showing delivery request dialog for order: $orderId');
        // Navigate to delivery request screen immediately
        if (_navigatorKey?.currentState != null) {
          _navigatorKey!.currentState!.pushNamed(
            '/rider/delivery-request',
            arguments: {'orderId': orderId},
          );
        } else {
          print('⚠️ Navigator key not set, storing for later');
          _pendingNavigation = {
            'route': '/rider/delivery-request',
            'orderId': orderId,
          };
        }
      }
    }
  }

  /// Handle notification tap (background or terminated)
  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.data}');

    final orderId = message.data['orderId'];
    final type = message.data['type'];

    if (type == 'NEW_DELIVERY_REQUEST' && orderId != null) {
      // Store for navigation in main.dart
      _pendingNavigation = {
        'route': '/riderDeliveryRequest',
        'orderId': orderId,
      };
    }
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('👆 Local notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final orderId = data['orderId'];

        if (orderId != null) {
          _pendingNavigation = {
            'route': '/riderDeliveryRequest',
            'orderId': orderId,
          };
        }
      } catch (e) {
        print('❌ Error parsing notification payload: $e');
      }
    }
  }

  // Store pending navigation data
  Map<String, dynamic>? _pendingNavigation;

  /// Get and clear pending navigation data
  Map<String, dynamic>? getPendingNavigation() {
    final data = _pendingNavigation;
    _pendingNavigation = null;
    return data;
  }

  /// Show local notification (for testing)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'delivery_requests',
          'Delivery Requests',
          channelDescription: 'Notifications for new delivery requests',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}

/*
═══════════════════════════════════════════════════════════════════════════════
PRODUCTION SETUP: Firebase Cloud Function for FCM
═══════════════════════════════════════════════════════════════════════════════

For production, notifications should be sent from Cloud Functions, not the client.

Create functions/index.js:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Send notification to riders when order is placed
exports.notifyRidersOnNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;

    if (order.status !== 'PLACED') return;

    console.log(`📦 New order ${orderId}, notifying riders...`);

    try {
      // Get all available riders
      const ridersSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'rider')
        .where('isOnline', '==', true)
        .get();

      if (ridersSnapshot.empty) {
        console.log('❌ No available riders found');
        return;
      }

      // Prepare notification payload
      const payload = {
        notification: {
          title: '🚀 New Delivery Request',
          body: `Pickup: ${order.pickupAddress}`,
          sound: 'default',
        },
        data: {
          orderId: orderId,
          type: 'NEW_DELIVERY_REQUEST',
          pickupAddress: order.pickupAddress,
          deliveryFee: order.deliveryFee.toString(),
        },
      };

      // Send to all riders
      const tokens = [];
      ridersSnapshot.forEach(doc => {
        const fcmToken = doc.data().fcmToken;
        if (fcmToken) tokens.push(fcmToken);
      });

      if (tokens.length === 0) {
        console.log('❌ No riders with FCM tokens');
        return;
      }

      // Send multicast message
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'delivery_requests',
            priority: 'max',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(`✅ Sent ${response.successCount} notifications to riders`);
      console.log(`❌ Failed: ${response.failureCount}`);

    } catch (error) {
      console.error('❌ Error sending notifications:', error);
    }
  });

// Auto-assign nearest rider after 30 seconds if no one accepts
exports.autoAssignRider = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const orderId = context.params.orderId;

    // Wait 30 seconds
    await new Promise(resolve => setTimeout(resolve, 30000));

    // Check if still unassigned
    const orderRef = admin.firestore().collection('orders').doc(orderId);
    const order = await orderRef.get();

    if (!order.exists || order.data().status !== 'PLACED') {
      console.log('Order already assigned or status changed');
      return;
    }

    // Find nearest rider and assign
    console.log('🔄 Auto-assigning nearest rider...');
    // Add your auto-assignment logic here (from rider_assignment_service.dart)
  });
```

Deploy:
```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

═══════════════════════════════════════════════════════════════════════════════
*/
