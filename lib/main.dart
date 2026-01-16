import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'app_router.dart';
import 'theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dishes_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/rider_provider.dart';
import 'providers/favorites_provider.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

// TODO: Replace with your Firebase configuration
// Download google-services.json (Android) and GoogleService-Info.plist (iOS)
// from Firebase Console and place them in respective platform folders

/// 🔥 BACKGROUND MESSAGE HANDLER (Must be top-level function)
/// Handles push notifications when app is in background or terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Check if already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  
  print('📩 Background message received: ${message.messageId}');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');
  
  // Show local notification when app is in background
  if (message.notification != null) {
    final FlutterLocalNotificationsPlugin localNotifications = 
        FlutterLocalNotificationsPlugin();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'delivery_requests_channel',
      'Delivery Requests',
      channelDescription: 'Notifications for new delivery requests',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    
    const NotificationDetails notificationDetails = 
        NotificationDetails(android: androidDetails);
    
    await localNotifications.show(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
      notificationDetails,
      payload: message.data['orderId'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Initialize Firebase with platform-specific options
  // Check if already initialized (Android auto-initializes from google-services.json)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('⚠️ Firebase initialization: $e');
    // If already initialized, continue
  }
  
  // 🔔 Register background message handler (MUST be before runApp)
  // Skip on web - FCM background messages not supported on web
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  // 📱 Initialize local notifications (Skip on web)
  if (!kIsWeb) {
    await NotificationService().initialize();
  }
  
  // 🚀 Initialize FCM service (Skip on web)
  if (!kIsWeb) {
    await FCMService().initialize();
  }
  
  // 📲 Request notification permissions (Android 13+, Skip on web)
  if (!kIsWeb) {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }
  
  print('✅ Firebase and FCM initialized successfully');
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 🚀 Set navigator key for FCM service to enable foreground navigation
    FCMService.setNavigatorKey(MyApp.navigatorKey);
    _setupNotificationRouting();
  }
  
  void _setupNotificationRouting() {
    // 🔔 FOREGROUND: Handle notifications when app is open
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground message received');
      print('   Title: ${message.notification?.title}');
      print('   Data: ${message.data}');
      
      // Show local notification even in foreground
      if (message.notification != null) {
        _showLocalNotification(message);
      }
      
      // Auto-navigate if it's a delivery request
      if (message.data['type'] == 'NEW_DELIVERY_REQUEST') {
        _handleNotificationNavigation(message.data);
      }
    });
    
    // 🔔 BACKGROUND: Handle notification taps (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Background notification tapped');
      print('   Data: ${message.data}');
      _handleNotificationNavigation(message.data);
    });
    
    // 🔔 TERMINATED: Check if app was opened from a terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('📱 App opened from terminated state via notification');
        print('   Data: ${message.data}');
        
        // Delay navigation to ensure app is fully loaded
        Future.delayed(const Duration(seconds: 2), () {
          _handleNotificationNavigation(message.data);
        });
      }
    });
  }
  
  /// Show local notification in foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin localNotifications = 
        FlutterLocalNotificationsPlugin();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'delivery_requests_channel',
      'Delivery Requests',
      channelDescription: 'Notifications for new delivery requests',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails notificationDetails = 
        NotificationDetails(android: androidDetails);
    
    await localNotifications.show(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
      notificationDetails,
      payload: message.data['orderId'],
    );
  }
  
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final orderId = data['orderId'];
    
    if (type == 'NEW_DELIVERY_REQUEST' && orderId != null) {
      // Navigate to delivery request screen for riders
      MyApp.navigatorKey.currentState?.pushNamed(
        AppRouter.riderDeliveryRequest,
        arguments: {'orderId': orderId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DishesProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => RiderProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp(
        title: 'HomeHarvest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: MyApp.navigatorKey,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
