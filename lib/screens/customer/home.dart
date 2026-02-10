import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/dishes_provider.dart';
import '../../app_router.dart';
import '../../models/dish_model.dart';
import '../../models/order_model.dart';
import '../../widgets/filter_popup.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'Veg Thali';
  bool _hasActiveDelivery = false;
  OrderModel? _activeOrder;
  late PageController _pageController;
  int _currentPage = 0;
  String _currentLocation = 'Fetching location...';
  bool _isLoadingLocation = true;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DishesProvider>(context, listen: false).loadDishes();
      _checkActiveOrder();
      _getCurrentLocation();
    });
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  // 📍 Get user's current location
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
      drawer: _buildDrawer(),
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
              
              // Hot Deals Section
              SliverToBoxAdapter(
                child: _buildHotDealsSection(filteredDishes),
              ),
              
              // Most Bought Section
              SliverToBoxAdapter(
                child: _buildMostBoughtSection(filteredDishes),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          
          // Active Delivery Banner
          if (_hasActiveDelivery && _activeOrder != null)
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: _buildActiveDeliveryBanner(),
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
              if (index < banners.length) {
                setState(() => _currentPage = index);
              }
            },
            itemCount: banners.length,
            itemBuilder: (context, index) {
              return _buildBannerPage(banners[index]);
            },
          ),
          
          // Top Bar
          Positioned(
            top: 44,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.menu, size: 20),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        padding: EdgeInsets.zero,
                      ),
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
                            icon: Icon(Icons.shopping_cart, size: 20),
                            onPressed: () => Navigator.pushNamed(context, AppRouter.cart),
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
                                '5',
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
                Column(
                  children: [
                    Text('Location', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Row(
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
                Row(
                  children: [
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
                    SizedBox(width: 8),
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
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  width: _currentPage == index ? 16 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Color(0xFFFC8019) : Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
                  onApplyFilter: (filters) {
                    // Handle filter results
                    print('Applied filters: $filters');
                    // TODO: Implement filter logic
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
      {'name': 'Veg Thali', 'icon': Icons.set_meal_outlined},
      {'name': 'Non-Veg', 'icon': Icons.dinner_dining},
      {'name': 'Beverages', 'icon': Icons.local_drink_outlined},
      {'name': 'Roti & Rice', 'icon': Icons.fastfood},
      {'name': 'Meat', 'icon': Icons.food_bank},
    ];

    return Container(
      height: 50,
      margin: EdgeInsets.only(left: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['name'];
          
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category['name'] as String),
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
              margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF27AE60),
                    Color(0xFF2ECC71),
                    Color(0xFF3FDE81),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF27AE60).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: -5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated background pattern
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(
                        painter: _TiffinPatternPainter(),
                      ),
                    ),
                  ),
                  
                  // Main content
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Animated icon container
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 1200),
                          curve: Curves.elasticOut,
                          builder: (context, iconValue, child) {
                            return Transform.rotate(
                              angle: (1 - iconValue) * 0.5,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.lunch_dining_rounded,
                                  color: Color(0xFF27AE60),
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 16),
                        
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
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Office Tiffin',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
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
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Daily delivery service',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
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
                                  color: Colors.white.withOpacity(0.2),
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
        );
      },
    );
  }

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
        margin: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: dish.imageUrl,
                width: 200,
                height: 250,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.restaurant, size: 50, color: Colors.grey),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      dish.rating?.toStringAsFixed(1) ?? '4.5',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '\$ ',
                                  style: TextStyle(color: Color(0xFFFC8019), fontSize: 12),
                                ),
                                TextSpan(
                                  text: dish.price.toStringAsFixed(2),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.favorite_border, color: Colors.white, size: 18),
                        onPressed: () {},
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRouter.orderTrackingLive,
          arguments: {'orderId': _activeOrder!.orderId},
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[600]!, Colors.green[400]!],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delivery_dining, color: Colors.white, size: 32),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚀 Delivery in Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _activeOrder!.status.name.replaceAll('_', ' '),
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
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