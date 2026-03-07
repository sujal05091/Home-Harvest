import 'package:flutter/material.dart';
import 'screens/splash.dart';
import 'screens/onboarding/onboarding_screen.dart'; // 🎨 ONBOARDING
import 'screens/role_select_modern.dart'; // 🎨 NEW MODERN UI
import 'screens/auth/login.dart';
import 'screens/auth/signup.dart';
import 'screens/auth/verification.dart';
import 'screens/customer/home.dart';
import 'screens/customer/dish_detail.dart';
import 'screens/customer/cart.dart';
import 'screens/customer/checkout.dart';
// import 'screens/customer/order_tracking.dart'; // OLD Google Maps - Removed
import 'screens/customer/add_address.dart';
import 'screens/customer/select_address.dart';
import 'screens/customer/order_history.dart';
import 'screens/customer/cooks_discovery.dart';
import 'screens/customer/tiffin_order.dart';
import 'screens/customer/favorites.dart';
import 'screens/customer/notifications.dart';
import 'screens/cook/dashboard.dart';
import 'screens/cook/add_dish.dart';
import 'screens/cook/verification_status.dart';
import 'screens/cook/cook_dashboard_modern.dart'; // 🎨 NEW MODERN COOK UI
import 'screens/cook/cook_orders_screen.dart';
import 'screens/cook/cook_earnings_screen.dart';
import 'screens/cook/cook_dishes_screen.dart';
import 'screens/cook/cook_withdraw_screen.dart'; // 💸 COOK WITHDRAW SCREEN
// import 'screens/rider/home.dart'; // OLD - NOT USED (using home_modern.dart instead)
import 'screens/rider/home_modern.dart'; // 🎨 NEW MODERN RIDER UI
import 'screens/rider/rider_earnings_screen.dart';
import 'screens/rider/rider_history_screen.dart';
import 'screens/rider/rider_active_delivery_screen.dart';
import 'screens/rider/rider_withdraw_screen.dart'; // 💸 WITHDRAW SCREEN
import 'screens/common/profile.dart';
import 'screens/common/chat.dart';
import 'screens/common/settings.dart';
import 'screens/common/edit_profile.dart';
import 'screens/common/change_password.dart';
import 'screens/common/language.dart';
import 'screens/common/notification_settings.dart';
import 'screens/common/security.dart';
import 'screens/common/help_support.dart';
import 'screens/common/legal_policies.dart';
import 'screens/common/payment_settings.dart';
import 'screens/common/coming_soon.dart';
// import 'screens/test/map_test_screen.dart'; // OLD Google Maps - Removed
import 'screens/test/osm_test_screen.dart';
import 'screens/customer/order_tracking_osm.dart'; // 🗺️ OSM TRACKING WITH TIMELINE
import 'screens/customer/select_location_map_osm.dart';
import 'screens/rider/navigation_osm.dart' as osm_navigation;

// 🚀 NEW Real-Time Tracking Screens
import 'screens/customer/finding_partner_screen.dart';
import 'screens/customer/premium_tracking_screen.dart'; // 🎨 PREMIUM SWIGGY-STYLE TRACKING
import 'screens/rider/rider_delivery_request_modern.dart'; // 🎨 NEW MODERN FULL-SCREEN DELIVERY REQUEST
import 'screens/customer/home_harvest_market_screen.dart'; // 🛒 HOMEMADE MARKET
import 'screens/customer/product_detail_screen.dart'; // 📦 PRODUCT DETAIL
import 'models/home_product_model.dart';
import 'screens/cook/cook_products_screen.dart'; // 🫙 COOK PRODUCT MANAGEMENT
import 'screens/cook/cook_service_selection_screen.dart'; // 👨‍🍳 COOK SERVICE SELECTION
import 'screens/cook/product_verification_form.dart'; // 🫙 PRODUCT VERIFICATION FORM
import 'screens/cook/product_verification_status.dart'; // 🫙 PRODUCT VERIFICATION STATUS
import 'screens/seller/seller_dashboard.dart'; // 🛍️ SELLER DASHBOARD
class AppRouter {
  // Route names
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelect = '/role-select';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verification = '/verification';
  
  // Customer routes
  static const String customerHome = '/customer/home';
  static const String dishDetail = '/customer/dish-detail';
  static const String cart = '/customer/cart';
  static const String checkout = '/customer/checkout';
  static const String orderTracking = '/customer/order-tracking';
  static const String addAddress = '/customer/add-address';
  static const String selectAddress = '/customer/select-address';
  static const String addReview = '/customer/add-review';
  static const String orderHistory = '/customer/order-history';
  static const String cooksDiscovery = '/customer/cooks-discovery';
  static const String tiffinOrder = '/customer/tiffin-order';
  static const String favorites = '/customer/favorites';
  static const String notifications = '/notifications';
  
  // Cook routes
  static const String cookDashboard = '/cook/dashboard';
  static const String addDish = '/cook/add-dish';
  static const String verificationStatus = '/cook/verification-status';
  // 🎨 NEW Modern Cook Routes
  static const String cookDashboardModern = '/cook/dashboard-modern';
  static const String cookOrders = '/cook/orders';
  static const String cookEarnings = '/cook/earnings';
  static const String cookDishes = '/cook/dishes';
  static const String cookWithdraw = '/cook/withdraw';
  
  // Rider routes
  static const String riderHome = '/rider/home';
  // 🎨 NEW Modern Rider Routes
  static const String riderHomeModern = '/rider/home-modern';
  static const String riderEarnings = '/rider/earnings';
  static const String riderHistory = '/rider/history';
  static const String riderActiveDelivery = '/rider/active-delivery';
  static const String riderWithdraw = '/rider/withdraw'; // 💸 WITHDRAW
  
  // Common routes
  static const String profile = '/profile';
  static const String chat = '/chat';
  static const String settingsPage = '/settings';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String language = '/language';
  static const String notificationSettings = '/notification-settings';
  static const String security = '/security';
  static const String helpSupport = '/help-support';
  static const String legalPolicies = '/legal-policies';
  static const String paymentSettings = '/payment-settings';
  static const String comingSoon = '/coming-soon';
  static const String mapTest = '/test/map'; // Old Google Maps test
  static const String osmTest = '/test/osm'; // NEW OpenStreetMap test
  
  // NEW OpenStreetMap routes (FREE!)
  static const String orderTrackingOSM = '/customer/order-tracking-osm';
  static const String selectLocationOSM = '/customer/select-location-osm';
  static const String riderNavigationOSM = '/rider/navigation-osm';
  
  // 🚀 NEW Real-Time Tracking Routes
  static const String findingPartner = '/customer/finding-partner';
  static const String premiumTracking = '/customer/premium-tracking'; // 🎨 NEW PREMIUM TRACKING
  static const String riderDeliveryRequest = '/rider/delivery-request';

  // �️ SELLER routes
  static const String sellerHome = '/seller/home';

  // �🛒 HOMEMADE MARKET Routes
  static const String harvestMarket = '/customer/harvest-market';

  static const String productDetail = '/customer/product-detail';
  static const String cookProducts = '/cook/products';
  static const String cookServiceSelection = '/cook/service-selection';
  static const String productVerificationStatus = '/cook/product-verification-status';
  static const String productVerificationForm = '/cook/product-verification-form';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      
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
      
      case premiumTracking: // 🎨 NEW PREMIUM SWIGGY-STYLE TRACKING
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PremiumTrackingScreen(orderId: args['orderId']),
        );
      
      case riderDeliveryRequest: // 🎨 NOW USING MODERN FULL-SCREEN UI
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RiderDeliveryRequestModernScreen(orderId: args['orderId']),
        );

      // 🛒 HOMEMADE MARKET
      case harvestMarket:
        return MaterialPageRoute(
          builder: (_) => const HomeHarvestMarketScreen(),
        );

      case productDetail:
        final product = settings.arguments as HomeProductModel;
        return MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        );

      case cookProducts:
        return MaterialPageRoute(
          builder: (_) => const CookProductsScreen(),
        );

      case cookServiceSelection:
        return MaterialPageRoute(
          builder: (_) => const CookServiceSelectionScreen(),
        );

      case productVerificationStatus:
        return MaterialPageRoute(
          builder: (_) => const ProductVerificationStatusScreen(),
        );

      case productVerificationForm:
        return MaterialPageRoute(
          builder: (_) => const ProductVerificationFormScreen(),
        );

      // 🛍️ SELLER
      case sellerHome:
        return MaterialPageRoute(
          builder: (_) => const SellerDashboardScreen(),
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
      case verification:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VerificationScreen(
            email: args?['email'] as String?,
            phone: args?['phone'] as String?,
            role: args?['role'] as String?,
          ),
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
      
      case checkout:
        return MaterialPageRoute(builder: (_) => const CheckoutScreen());
      
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
      
      case favorites:
        return MaterialPageRoute(builder: (_) => const FavoritesScreen());
      
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsWidget());
      
      // Cook routes
      case cookDashboard:
        return MaterialPageRoute(builder: (_) => const CookDashboardScreen());
      
      // 🎨 NEW Modern Cook Routes
      case cookDashboardModern:
        return MaterialPageRoute(builder: (_) => const CookDashboardModernScreen());
      
      case cookOrders:
        return MaterialPageRoute(builder: (_) => const CookOrdersScreen());
      
      case cookEarnings:
        return MaterialPageRoute(builder: (_) => const CookEarningsScreen());
      
      case cookDishes:
        return MaterialPageRoute(builder: (_) => const CookDishesScreen());
      
      case cookWithdraw:
        return MaterialPageRoute(builder: (_) => const CookWithdrawScreen());
      
      case addDish:
        return MaterialPageRoute(builder: (_) => const AddDishScreen());
      
      case verificationStatus:
        return MaterialPageRoute(builder: (_) => const VerificationStatusScreen());
      
      // Rider routes (🎨 NOW USING MODERN UI BY DEFAULT)
      case riderHome:
        return MaterialPageRoute(builder: (_) => const RiderHomeModernScreen());
      
      // 🎨 Modern Rider Routes
      case riderHomeModern:
        return MaterialPageRoute(builder: (_) => const RiderHomeModernScreen());
      
      case riderEarnings:
        return MaterialPageRoute(builder: (_) => const RiderEarningsScreen());
      
      case riderHistory:
        return MaterialPageRoute(builder: (_) => const RiderHistoryScreen());
      
      case riderWithdraw:
        return MaterialPageRoute(builder: (_) => const RiderWithdrawScreen());
      
      case riderActiveDelivery:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RiderActiveDeliveryScreen(order: args['order']),
        );
      
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
      
      case settingsPage:
        return MaterialPageRoute(builder: (_) => const SettingScreen());
      
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      
      case language:
        return MaterialPageRoute(builder: (_) => const LanguageScreen());
      
      case notificationSettings:
        return MaterialPageRoute(builder: (_) => const NotificationSettingsScreen());
      
      case security:
        return MaterialPageRoute(builder: (_) => const SecurityScreen());
      
      case helpSupport:
        return MaterialPageRoute(builder: (_) => const HelpSupportScreen());
      
      case legalPolicies:
        return MaterialPageRoute(builder: (_) => const LegalPoliciesScreen());
      
      case paymentSettings:
        return MaterialPageRoute(builder: (_) => const PaymentSettingsScreen());
      
      case comingSoon:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ComingSoonScreen(
            title: args?['title'] ?? 'Coming Soon',
            message: args?['message'] ?? 'This feature is currently under development and will be available soon!',
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
