import 'package:flutter/material.dart';
import 'screens/splash.dart';
import 'screens/role_select.dart';
import 'screens/auth/login.dart';
import 'screens/auth/signup.dart';
import 'screens/customer/home.dart';
import 'screens/customer/dish_detail.dart';
import 'screens/customer/cart.dart';
// import 'screens/customer/order_tracking.dart'; // OLD Google Maps - Removed
import 'screens/customer/add_address.dart';
import 'screens/customer/select_address.dart';
import 'screens/customer/order_history.dart';
import 'screens/customer/cooks_discovery.dart';
import 'screens/customer/tiffin_order.dart';
import 'screens/cook/dashboard.dart';
import 'screens/cook/add_dish.dart';
import 'screens/cook/verification_status.dart';
import 'screens/rider/home.dart';
import 'screens/common/profile.dart';
import 'screens/common/chat.dart';
// import 'screens/test/map_test_screen.dart'; // OLD Google Maps - Removed
import 'screens/test/osm_test_screen.dart';
import 'screens/customer/order_tracking_modern.dart' as modern_tracking; // 🎨 NEW MODERN UI
import 'screens/customer/order_tracking_osm.dart'; // 🗺️ OSM TRACKING WITH TIMELINE
import 'screens/customer/select_location_map_osm.dart';
import 'screens/rider/navigation_osm.dart' as osm_navigation;

// 🚀 NEW Real-Time Tracking Screens
import 'screens/customer/finding_partner_screen.dart';
import 'screens/customer/live_tracking_screen.dart';
import 'screens/customer/order_tracking_live.dart'; // 📱 NEW COMPREHENSIVE LIVE TRACKING
import 'screens/rider/rider_delivery_request_screen.dart';

class AppRouter {
  // Route names
  static const String splash = '/';
  static const String roleSelect = '/role-select';
  static const String login = '/login';
  static const String signup = '/signup';
  
  // Customer routes
  static const String customerHome = '/customer/home';
  static const String dishDetail = '/customer/dish-detail';
  static const String cart = '/customer/cart';
  static const String orderTracking = '/customer/order-tracking';
  static const String addAddress = '/customer/add-address';
  static const String selectAddress = '/customer/select-address';
  static const String addReview = '/customer/add-review';
  static const String orderHistory = '/customer/order-history';
  static const String cooksDiscovery = '/customer/cooks-discovery';
  static const String tiffinOrder = '/customer/tiffin-order';
  
  // Cook routes
  static const String cookDashboard = '/cook/dashboard';
  static const String addDish = '/cook/add-dish';
  static const String verificationStatus = '/cook/verification-status';
  
  // Rider routes
  static const String riderHome = '/rider/home';
  
  // Common routes
  static const String profile = '/profile';
  static const String chat = '/chat';
  static const String mapTest = '/test/map'; // Old Google Maps test
  static const String osmTest = '/test/osm'; // NEW OpenStreetMap test
  
  // NEW OpenStreetMap routes (FREE!)
  static const String orderTrackingOSM = '/customer/order-tracking-osm';
  static const String selectLocationOSM = '/customer/select-location-osm';
  static const String riderNavigationOSM = '/rider/navigation-osm';
  
  // 🚀 NEW Real-Time Tracking Routes
  static const String findingPartner = '/customer/finding-partner';
  static const String liveTracking = '/customer/live-tracking';
  static const String riderDeliveryRequest = '/rider/delivery-request';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case roleSelect:
        return MaterialPageRoute(builder: (_) => const RoleSelectScreen());
      
      case mapTest:
        // OLD Google Maps test - Use osmTest instead
        return MaterialPageRoute(builder: (_) => const OSMTestScreen());
      
      case osmTest:
        return MaterialPageRoute(builder: (_) => const OSMTestScreen());
      
      // 🎨 NEW OpenStreetMap Routes (FREE - MODERN UI!)
      case orderTrackingOSM:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: args['orderId']),
        );
      
      case selectLocationOSM:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SelectLocationMapScreen(
            initialLocation: args?['initialLocation'],
            initialAddress: args?['initialAddress'],
          ),
        );
      
      case riderNavigationOSM:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => osm_navigation.RiderNavigationScreen(
            deliveryId: args['deliveryId'],
            orderId: args['orderId'],
          ),
        );
      
      // 🚀 NEW Real-Time Tracking Routes
      case findingPartner:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => FindingPartnerScreen(orderId: args['orderId']),
        );
      
      case liveTracking:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => LiveTrackingScreen(orderId: args['orderId']),
        );
      
      case riderDeliveryRequest:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RiderDeliveryRequestScreen(orderId: args['orderId']),
        );
      
      case login:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => LoginScreen(role: args?['role']),
        );
      
      case signup:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SignupScreen(role: args?['role']),
        );
      
      // Customer routes
      case customerHome:
        return MaterialPageRoute(builder: (_) => const CustomerHomeScreen());
      
      case dishDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => DishDetailScreen(dishId: args['dishId']),
        );
      
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      
      case orderTracking:
        // Use OSM tracking screen with timeline
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: args['orderId']),
        );
      
      case addAddress:
        return MaterialPageRoute(builder: (_) => const AddAddressScreen());
      
      case selectAddress:
        return MaterialPageRoute(builder: (_) => const SelectAddressScreen());
      
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistoryScreen());
      
      case cooksDiscovery:
        return MaterialPageRoute(builder: (_) => const CooksDiscoveryScreen());
      
      case tiffinOrder:
        return MaterialPageRoute(builder: (_) => const TiffinOrderScreen());
      
      // Cook routes
      case cookDashboard:
        return MaterialPageRoute(builder: (_) => const CookDashboardScreen());
      
      case addDish:
        return MaterialPageRoute(builder: (_) => const AddDishScreen());
      
      case verificationStatus:
        return MaterialPageRoute(builder: (_) => const VerificationStatusScreen());
      
      // Rider routes
      case riderHome:
        return MaterialPageRoute(builder: (_) => const RiderHomeScreen());
      
      // Common routes
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            orderId: args['orderId'],
            otherUserId: args['otherUserId'],
            otherUserName: args['otherUserName'],
          ),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
