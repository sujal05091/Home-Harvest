import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 🔔 FIREBASE CLOUD MESSAGING SERVICE
/// Handles push notifications even when app is closed
class FCMNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  static const AndroidNotificationChannel _highPriorityChannel =
      AndroidNotificationChannel(
    'delivery_notifications', // id
    'Delivery Notifications', // name
    description: 'High priority notifications for delivery partners',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  
  /// Initialize FCM and notification channels
  static Future<void> initialize() async {
    print('🔔 Initializing FCM...');
    
    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ FCM permission granted');
    } else {
      print('❌ FCM permission denied');
    }
    
    // Get FCM token
    final token = await _fcm.getToken();
    print('📱 FCM Token: $token');
    
    // Initialize local notifications (Android)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create high priority channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_highPriorityChannel);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle notification tap when app was terminated
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }
  
  /// Handle foreground message (app is open)
  static void _handleForegroundMessage(RemoteMessage message) {
    print('📩 Foreground message: ${message.notification?.title}');
    
    // Show local notification
    _showLocalNotification(message);
  }
  
  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.data}');
    
    // Navigate based on data payload
    final data = message.data;
    
    if (data['screen'] == 'delivery_request') {
      final orderId = data['orderId'];
      // TODO: Navigate to RiderOrderScreen
      print('🚀 Navigate to delivery request: $orderId');
    }
  }
  
  /// Handle notification tap from local notification
  static void _onNotificationTapped(NotificationResponse response) {
    print('👆 Local notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      
      if (data['screen'] == 'delivery_request') {
        final orderId = data['orderId'];
        // TODO: Navigate to RiderOrderScreen
        print('🚀 Navigate to delivery request: $orderId');
      }
    }
  }
  
  /// Show local notification (for foreground messages)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _highPriorityChannel.id,
          _highPriorityChannel.name,
          channelDescription: _highPriorityChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: json.encode(message.data),
    );
  }
  
  /// Subscribe to topic (e.g., all riders)
  static Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    print('✅ Subscribed to topic: $topic');
  }
  
  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    print('❌ Unsubscribed from topic: $topic');
  }
  
  /// Get FCM token for this device
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }
  
  /// Refresh FCM token
  static void onTokenRefresh(Function(String) callback) {
    _fcm.onTokenRefresh.listen(callback);
  }
}

/// 🔥 BACKGROUND MESSAGE HANDLER
/// Must be top-level function (not inside class)
/// Add this to main.dart BEFORE runApp()
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.notification?.title}');
  
  // Initialize Firebase if needed
  // await Firebase.initializeApp();
  
  // Handle background notification
  // This runs even when app is closed!
  
  // You can show local notification here if needed
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  
  const androidSettings = AndroidNotificationDetails(
    'delivery_notifications',
    'Delivery Notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );
  
  if (message.notification != null) {
    await localNotifications.show(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
      const NotificationDetails(android: androidSettings),
    );
  }
}

/// 📤 SAMPLE FCM PAYLOAD FOR BACKEND
/// 
/// Send this from your backend (Node.js/Firebase Functions):
/// 
/// ```json
/// {
///   "notification": {
///     "title": "New Delivery Request 🛵",
///     "body": "Pickup from HomeHarvest customer nearby"
///   },
///   "data": {
///     "orderId": "ORDER_123",
///     "screen": "delivery_request",
///     "pickupAddress": "123 Main St",
///     "distance": "2.5km"
///   },
///   "priority": "high",
///   "android": {
///     "priority": "high",
///     "notification": {
///       "channel_id": "delivery_notifications",
///       "sound": "default",
///       "defaultVibrateTimings": true
///     }
///   },
///   "token": "RIDER_FCM_TOKEN"
/// }
/// ```
