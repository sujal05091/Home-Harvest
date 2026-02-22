import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/dishes_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../app_router.dart';
import '../../models/dish_model.dart';
import '../../models/order_model.dart';
import '../../models/cook_section_model.dart';
import '../../widgets/filter_popup.dart';
import '../../widgets/cook_section_card.dart';
import '../../widgets/cart_summary_bar.dart';
import '../../widgets/active_delivery_bar.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'Breakfast';
  bool _hasActiveDelivery = false;
  OrderModel? _activeOrder;
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  String _currentLocation = 'Fetching location...';
  bool _isLoadingLocation = true;
  StreamSubscription<QuerySnapshot>? _activeOrderSubscription; // Real-time listener
  
  // Filter state
  String _sortBy = 'recommended';
  List<String> _selectedFilterCategories = [];
  double _maxPrice = 1000.0;
  
  @override
  void initState() {
    super.initState();
    // Start at a high page number for infinite forward scrolling
    _pageController = PageController(initialPage: 10000);
    _currentPage = 10000;
    _startAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid;
      
      // Load cook sections with grouped dishes
      Provider.of<DishesProvider>(context, listen: false).loadCooksWithDishes();
      
      // Load favorites if user is logged in
      if (userId != null) {
        Provider.of<FavoritesProvider>(context, listen: false).loadFavorites(userId);
      }
      
      _checkActiveOrder();
      _listenToActiveOrders(); // Start real-time listener
      _getCurrentLocation();
    });
  }
  
  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _activeOrderSubscription?.cancel(); // Cancel real-time listener
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Always scroll forward to next page
      final nextPage = _currentPage + 1;
      
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }
  
  // 🚀 Check for active delivery on app launch
  Future<void> _checkActiveOrder() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final activeOrderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: ['PLACED', 'ACCEPTED', 'RIDER_ASSIGNED', 'RIDER_ACCEPTED', 'ON_THE_WAY_TO_PICKUP', 'PICKED_UP', 'ON_THE_WAY_TO_DROP'])
          .limit(1)
          .get();
      
      if (activeOrderSnapshot.docs.isNotEmpty && mounted) {
        final orderDoc = activeOrderSnapshot.docs.first;
        final order = OrderModel.fromFirestore(orderDoc);
        
        setState(() {
          _hasActiveDelivery = true;
          _activeOrder = order;
        });
      }
    } catch (e) {
      print('❌ Error checking active order: $e');
    }
  }

  // � Real-time listener for active orders (updates when user comes back from tracking)
  void _listenToActiveOrders() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    // Cancel existing subscription if any
    _activeOrderSubscription?.cancel();
    
    // Calculate cutoff time (24 hours ago) to ignore old test data
    final cutoffTime = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );
    
    // Listen to active orders in real-time (only from last 24 hours)
    _activeOrderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
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
               status != 'CANCELLED';
      }).toList();
      
      if (activeOrders.isNotEmpty) {
        final orderDoc = activeOrders.first;
        final order = OrderModel.fromFirestore(orderDoc);
        
        setState(() {
          _hasActiveDelivery = true;
          _activeOrder = order;
        });
        
        print('✅ Active delivery detected: ${order.orderId} | Status: ${order.status}');
      } else {
        setState(() {
          _hasActiveDelivery = false;
          _activeOrder = null;
        });
        
        print('ℹ️ No active delivery');
      }
    }, onError: (error) {
      print('❌ Error listening to active orders: $error');
    });
  }

  // �📍 Get user's current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocation = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentLocation = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = 'Location permission denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode to get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subLocality ?? '';
        String state = place.administrativeArea ?? '';
        
        setState(() {
          if (city.isNotEmpty && state.isNotEmpty) {
            _currentLocation = '$city, $state';
          } else if (city.isNotEmpty) {
            _currentLocation = city;
          } else {
            _currentLocation = place.subAdministrativeArea ?? 'Your Location';
          }
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('❌ Error getting location: $e');
      if (mounted) {
        setState(() {
          _currentLocation = 'Unable to get location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  List<DishModel> _getFilteredDishes(List<DishModel> dishes) {
    return dishes.where((dish) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!dish.title.toLowerCase().contains(query) &&
            !dish.cookName.toLowerCase().contains(query) &&
            !dish.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dishesProvider = Provider.of<DishesProvider>(context);
    final filteredDishes = _getFilteredDishes(dishesProvider.dishes);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Show exit confirmation
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit App?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text('Do you want to exit the app?', style: GoogleFonts.poppins()),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFC8019),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Exit', style: GoogleFonts.poppins()),
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
          CustomScrollView(
            slivers: [
              // Hero Banner Section
              SliverToBoxAdapter(
                child: _buildHeroBanner(),
              ),
              
              // Search Bar
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),
              
              // Category Chips
              SliverToBoxAdapter(
                child: _buildCategoryChips(),
              ),
              
              // 🏢 HOME → OFFICE TIFFIN SERVICE CARD
              SliverToBoxAdapter(
                child: _buildTiffinServiceCard(),
              ),
              
              // 👨‍🍳 COOK SECTIONS (Grouped by Cook like Swiggy/Zomato)
              SliverToBoxAdapter(
                child: _buildCookSections(),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          
          // Active Delivery Banner (dynamic position based on cart)
          if (_hasActiveDelivery && _activeOrder != null)
            Consumer<OrdersProvider>(
              builder: (context, ordersProvider, child) {
                final hasCartItems = ordersProvider.cartItemCount > 0;
                return Positioned(
                  bottom: hasCartItems ? 80 : 10, // Move up if cart visible, down if cart empty
                  left: 0,
                  right: 0,
                  child: ActiveDeliveryBar(activeOrder: _activeOrder),
                );
              },
            ),
          
          // Swiggy-Style Floating Cart Summary Bar
          Positioned(
            bottom: 10, // Right above bottom navigation
            left: 0,
            right: 0,
            child: CartSummaryBar(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFFFC8019),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: TextStyle(fontSize: 12),
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                label: 'My Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border),
                label: 'Favorite',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
            onTap: (index) {
              switch (index) {
                case 0:
                  // Already on Home
                  break;
                case 1:
                  Navigator.pushNamed(context, AppRouter.orderHistory);
                  break;
                case 2:
                  Navigator.pushNamed(context, AppRouter.favorites);
                  break;
                case 3:
                  Navigator.pushNamed(context, AppRouter.profile);
                  break;
              }
            },
          ),
        ),
      ),
      ), // Close PopScope
    );
  }
  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 32),
              _buildDrawerItem(Icons.local_offer, 'Voucher', badge: '2'),
              _buildDrawerItem(Icons.chat_bubble_outline, 'Chat', badge: '23'),
              _buildDrawerItem(Icons.history, 'History', badge: '14'),
              _buildDrawerItem(Icons.settings_outlined, 'Settings', badge: '1', onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRouter.settingsPage);
              }),
              Divider(height: 48),
              _buildDrawerItem(Icons.business_center, 'Home → Office Tiffin', 
                badge: 'NEW', isNew: true, onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRouter.tiffinOrder);
                }),
              Spacer(),
              Divider(),
              _buildDrawerItem(Icons.help_outline, 'Help'),
              _buildDrawerItem(Icons.logout, 'Logout', color: Color(0xFFFC8019)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {String? badge, bool isNew = false, Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87, size: 24),
      title: Text(title, style: TextStyle(color: color)),
      trailing: badge != null
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isNew ? Colors.green : Color(0xFFFC8019),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildHeroBanner() {
    final banners = [
      {
        'image': 'assets/images/home-harvest-logo1.jpeg',
        'title': '🍱 Fresh Home-Cooked Meals',
        'subtitle': 'Healthy Ghar Ka Khana',
        'description': 'Cooked by verified home cooks using fresh ingredients'
      },
      {
        'image': 'assets/images/home-office-tiffin1.jpeg',
        'title': '🏢 Home → Office Tiffin',
        'subtitle': 'Daily Tiffin Service',
        'description': 'No cooking. No stress. Just homely food at work.'
      },
      {
        'image': 'assets/images/home-local-home-cooks1.jpeg',
        'title': '👩‍🍳 Local Home Cooks',
        'subtitle': 'Made With Care & Love',
        'description': 'Hygienic, verified cooks from your neighborhood'
      },
    ];

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              // Restart auto-scroll timer after manual page change
              _autoScrollTimer?.cancel();
              _startAutoScroll();
            },
            itemCount: 20000, // Very large number for infinite scrolling
            itemBuilder: (context, index) {
              // Use modulo to cycle through banners: 0, 1, 2, 0, 1, 2...
              final bannerIndex = index % banners.length;
              return _buildBannerPage(banners[bannerIndex]);
            },
          ),
          
          // Top Bar
          Positioned(
            top: 44,
            left: 24,
            right: 24,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Consumer<OrdersProvider>(
                          builder: (context, ordersProvider, _) {
                            final cartCount = ordersProvider.cartItemCount;
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.shopping_cart, size: 20),
                                    onPressed: () => Navigator.pushNamed(context, AppRouter.cart),
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (cartCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFC8019),
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                                        child: Text(
                                          '$cartCount',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications, size: 20),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/notifications');
                                },
                                padding: EdgeInsets.zero,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFC8019),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                                  child: Text(
                                    '3',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.settings, color: Color(0xFFFC8019), size: 20),
                        onPressed: () => Navigator.pushNamed(context, AppRouter.settingsPage),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                // Location centered absolutely
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Location', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, color: Color(0xFFFC8019), size: 14),
                            _isLoadingLocation
                                ? SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(_currentLocation, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Page Indicator
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                banners.length,
                (index) {
                  // Use modulo to show correct indicator for infinite scroll
                  final currentIndicator = _currentPage % banners.length;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    width: currentIndicator == index ? 16 : 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: currentIndicator == index ? Color(0xFFFC8019) : Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPage(Map<String, String> banner) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            child: Image.asset(
              banner['image']!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  banner['title']!,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  banner['subtitle']!,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  banner['description']!,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: "Let's find the food you like",
            hintStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(Icons.tune, color: Colors.grey),
              onPressed: () {
                FilterPopup.show(
                  context,
                  initialSortBy: _sortBy,
                  initialCategories: _selectedFilterCategories,
                  initialMaxPrice: _maxPrice,
                  onApplyFilter: (filters) {
                    setState(() {
                      _sortBy = filters['sortBy'] ?? 'recommended';
                      _selectedFilterCategories = List<String>.from(filters['categories'] ?? []);
                      _maxPrice = filters['maxPrice'] ?? 1000.0;
                    });
                    print('Applied filters: $_sortBy, $_selectedFilterCategories, $_maxPrice');
                  },
                );
              },
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      {'name': 'Breakfast', 'icon': Icons.free_breakfast},
      {'name': 'Lunch', 'icon': Icons.lunch_dining},
      {'name': 'Dinner', 'icon': Icons.dinner_dining},
      {'name': 'Veg Thali', 'icon': Icons.set_meal_outlined},
      {'name': 'Non-Veg', 'icon': Icons.restaurant_menu},
      {'name': 'Roti & Rice', 'icon': Icons.fastfood},
    ];

    return Container(
      height: 50,
      margin: EdgeInsets.only(left: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final categoryName = category['name'] as String;
          final isSelected = _selectedFilterCategories.contains(categoryName.toLowerCase());
          
          return GestureDetector(
            onTap: () {
              setState(() {
                final categoryId = categoryName.toLowerCase();
                if (isSelected) {
                  _selectedFilterCategories.remove(categoryId);
                } else {
                  _selectedFilterCategories.add(categoryId);
                }
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFFC8019) : Colors.grey[200],
                borderRadius: BorderRadius.circular(33),
              ),
              child: Row(
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🏢 HOME → OFFICE TIFFIN SERVICE CARD
  Widget _buildTiffinServiceCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRouter.tiffinOrder),
            child: Container(
              height: 120,
              margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Green background for the animation
                    Positioned.fill(
                      child: Container(
                        color: Color(0xFFE8F5E9), // Light green background
                      ),
                    ),
                    
                    // Lottie animation in the middle
                    Positioned(
                      right: 60,
                      top: 0,
                      bottom: 0,
                      width: 120,
                      child: Lottie.asset(
                        'assets/lottie/tiffinbotton.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Home',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward, color: Colors.black, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Office Tiffin',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF27AE60).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule, color: Color(0xFF27AE60), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Daily delivery service',
                                        style: GoogleFonts.poppins(
                                          color: Color(0xFF27AE60),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                          // Animated arrow
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 1500),
                            curve: Curves.easeInOut,
                            builder: (context, arrowValue, child) {
                              return Transform.translate(
                                offset: Offset(
                                  5 * (0.5 - (arrowValue - 0.5).abs()),
                                  0,
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF27AE60),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 👨‍🍳 COOK SECTIONS (Grouped by Cook like Swiggy/Zomato)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildCookSections() {
    return Consumer<DishesProvider>(
      builder: (context, dishesProvider, _) {
        if (dishesProvider.isCookSectionsLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                color: Color(0xFFFC8019),
              ),
            ),
          );
        }

        // Filter cook sections by search query, categories, price, and sort
        final cookSections = dishesProvider.filterCookSections(
          _searchQuery,
          categories: _selectedFilterCategories.isEmpty ? null : _selectedFilterCategories,
          maxPrice: _maxPrice,
          sortBy: _sortBy,
        );

        if (cookSections.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No food found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters or search terms',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Text(
                    "👨‍🍳 Our Verified Cooks",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(0xFFFC8019).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cookSections.length} cooks',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFC8019),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Cook Sections List
            ...cookSections.map((cookSection) {
              return CookSectionCard(
                cookSection: cookSection,
                onDishTap: (dish) => _navigateToDishDetail(dish),
                dishCardBuilder: (dish) => _buildCompactDishCard(dish),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // COMPACT DISH CARD (For Horizontal Scroll within Cook Sections)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildCompactDishCard(DishModel dish) {
    return Container(
      width: 200,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Background Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: dish.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
              ),
            ),
          ),
          
          // Top & Bottom Content
          Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top: Rating Badge with Blur
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x7F191D31),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 5,
                              sigmaY: 2,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dish.rating.toStringAsFixed(1),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom: Dish Info with Blur
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x7F191D31),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 5,
                              sigmaY: 2,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        // Dish Name
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                dish.title,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Price
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '₹ ',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: const Color(0xFFFC8019),
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: dish.price.toStringAsFixed(0),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Heart Button
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Consumer<FavoritesProvider>(
                                        builder: (context, favProvider, _) {
                                          final isFavorite = favProvider.favoriteDishes.contains(dish.dishId);
                                          return GestureDetector(
                                            onTap: () async {
                                              await favProvider.toggleDishFavorite(dish.dishId);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                                color: isFavorite ? Colors.red : Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // NAVIGATION HELPER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  void _navigateToDishDetail(DishModel dish) {
    Navigator.of(context).pushNamed(
      AppRouter.dishDetail,
      arguments: {'dishId': dish.dishId},
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // OLD METHODS (Kept for reference, not used)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildHotDealsSection(List<DishModel> dishes) {
    final hotDeals = dishes.take(3).toList();
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Special 👩‍🍳",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'See All',
                style: TextStyle(color: Color(0xFFFC8019), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Container(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 24),
            itemCount: hotDeals.length,
            itemBuilder: (context, index) {
              return _buildDishCard(hotDeals[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMostBoughtSection(List<DishModel> dishes) {
    final mostBought = dishes.skip(3).take(3).toList();
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Most bought 🔥',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'See All',
                style: TextStyle(color: Color(0xFFFC8019), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Container(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 24),
            itemCount: mostBought.length,
            itemBuilder: (context, index) {
              return _buildDishCard(mostBought[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDishCard(DishModel dish) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRouter.dishDetail,
          arguments: {'dishId': dish.dishId},
        );
      },
      child: Container(
        width: 200,
        height: 250,
        margin: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Background Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: dish.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                ),
              ),
            ),
            
            // Top & Bottom Content
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top: Rating Badge with Blur
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x7F191D31),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 5,
                                sigmaY: 2,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dish.rating.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom: Dish Info with Blur
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x7F191D31),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 5,
                                sigmaY: 2,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          // Dish Name
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  dish.title,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Price
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: '₹ ',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: const Color(0xFFFC8019),
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: dish.price.toStringAsFixed(0),
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Heart Button
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Consumer<FavoritesProvider>(
                                          builder: (context, favProvider, _) {
                                            final isFavorite = favProvider.favoriteDishes.contains(dish.dishId);
                                            return GestureDetector(
                                              onTap: () async {
                                                await favProvider.toggleDishFavorite(dish.dishId);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Icon(
                                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                                  color: isFavorite ? Colors.red : Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

// Custom painter for tiffin card background pattern
class _TiffinPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw curved lines pattern
    final path = Path();
    for (int i = 0; i < 5; i++) {
      double startY = size.height * (i / 4) - 20;
      path.reset();
      path.moveTo(-20, startY);
      
      for (double x = 0; x <= size.width + 20; x += 40) {
        path.quadraticBezierTo(
          x + 20, startY - 15,
          x + 40, startY,
        );
      }
      canvas.drawPath(path, paint);
    }

    // Draw circles
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 30, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 20, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.8), 25, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}