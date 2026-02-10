import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/dishes_provider.dart';
import '../../providers/orders_provider.dart';
import '../../app_router.dart';
import '../../models/dish_model.dart';
import '../../models/order_model.dart';
import '../../theme.dart';

/// 🏠 HOME SCREEN - Modern Swiggy/Zomato Inspired UI
/// 
/// Features:
/// - Sticky Header with Location, Notifications, Profile
/// - Hero Section with Quick Actions (Food Delivery + Tiffin Service)
/// - Search Bar with Filters
/// - Category Chips
/// - Hot Deals & Most Bought Sections
/// - Empty States
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // 🔍 Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _vegOnly = false;
  String _sortBy = 'popular';
  String _selectedCategory = 'All';
  
  // 🚚 Active Delivery State
  bool _hasActiveDelivery = false;
  OrderModel? _activeOrder;
  
  // 📜 Scroll Controller for Sticky Header
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DishesProvider>(context, listen: false).loadDishes();
      _checkActiveOrder();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 📜 Scroll Listener for Header Animation
  void _onScroll() {
    if (_scrollController.offset > 100 && !_isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = true);
    } else if (_scrollController.offset <= 100 && _isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = false);
    }
  }

  // 🚀 Check for Active Delivery
  Future<void> _checkActiveOrder() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final activeOrderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: [
            'PLACED',
            'ACCEPTED',
            'RIDER_ASSIGNED',
            'RIDER_ACCEPTED',
            'ON_THE_WAY_TO_PICKUP',
            'PICKED_UP',
            'ON_THE_WAY_TO_DROP'
          ])
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

  // 🔍 Filter Dishes
  List<DishModel> _getFilteredDishes(List<DishModel> dishes) {
    var filtered = dishes.where((dish) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!dish.title.toLowerCase().contains(query) &&
            !dish.cookName.toLowerCase().contains(query) &&
            !dish.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Veg filter
      if (_vegOnly && !dish.isVeg) {
        return false;
      }
      
      // Category filter
      if (_selectedCategory != 'All' && dish.category != _selectedCategory) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Sort
    switch (_sortBy) {
      case 'price_low':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1️⃣ HEADER SECTION (Sticky)
            _buildStickyHeader(),
            
            // 2️⃣ HERO / QUICK ACTIONS
            SliverToBoxAdapter(child: _buildQuickActions()),
            
            // 3️⃣ SEARCH BAR
            SliverToBoxAdapter(child: _buildSearchBar()),
            
            // 4️⃣ FEATURE HIGHLIGHTS
            SliverToBoxAdapter(child: _buildFeatureHighlights()),
            
            // 5️⃣ CATEGORY CHIPS
            SliverToBoxAdapter(child: _buildCategoryChips()),
            
            // 6️⃣ HOT DEALS SECTION
            SliverToBoxAdapter(child: _buildHotDealsSection()),
            
            // 7️⃣ MOST BOUGHT SECTION
            SliverToBoxAdapter(child: _buildMostBoughtSection()),
            
            // Bottom Padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 1️⃣ STICKY HEADER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildStickyHeader() {
    return SliverAppBar(
      floating: true,
      pinned: true,
      elevation: _isHeaderCollapsed ? 2 : 0,
      backgroundColor: Colors.white,
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Menu Icon
                  IconButton(
                    icon: const Icon(Icons.menu, color: AppTheme.darkGrey),
                    onPressed: () {
                      // Open drawer if exists
                    },
                  ),
                  
                  // Location Selector
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: Open location picker
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Deliver to',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Home - San Diego, CA',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Notification Badge
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: AppTheme.darkGrey,
                        ),
                        onPressed: () {
                          // Navigate to notifications
                        },
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Profile Avatar
                  GestureDetector(
                    onTap: () {
                      // Navigate to profile
                    },
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.lightGrey,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Active Delivery Banner
              if (_hasActiveDelivery) ...[
                const SizedBox(height: 12),
                _buildActiveDeliveryBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 🚚 Active Delivery Banner
  Widget _buildActiveDeliveryBanner() {
    return GestureDetector(
      onTap: () {
        if (_activeOrder != null) {
          Navigator.pushNamed(
            context,
            AppRouter.tracking,
            arguments: {'orderId': _activeOrder!.orderId},
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.successGreen.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.delivery_dining,
              color: AppTheme.successGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Order on the way • Track delivery',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.successGreen,
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 2️⃣ QUICK ACTIONS (HERO SECTION)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Craving Ghar Ka Khana?',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // 🍱 Normal Food Delivery
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Home Food',
                  subtitle: 'Fresh homely meals',
                  icon: Icons.restaurant_menu,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryOrange.withOpacity(0.9),
                      AppTheme.deepOrange.withOpacity(0.9),
                    ],
                  ),
                  onTap: () {
                    // Already on home, just scroll to dishes
                    _scrollController.animateTo(
                      600,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 🏢 Home → Office (Tiffin Delivery) ← NEW FEATURE
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Tiffin Service',
                  subtitle: 'Home → Office daily',
                  icon: Icons.business_center,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successGreen.withOpacity(0.9),
                      AppTheme.successGreen.withOpacity(0.7),
                    ],
                  ),
                  onTap: () {
                    // Navigate to Tiffin Order Screen
                    Navigator.pushNamed(context, AppRouter.tiffinOrder);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 36,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 3️⃣ SEARCH BAR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.lightGrey,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          decoration: InputDecoration(
            hintText: 'Search dishes, cooks...',
            hintStyle: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.textSecondary,
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.tune,
                color: AppTheme.primaryOrange,
              ),
              onPressed: () => _showFilterBottomSheet(),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  // 🎛️ Filter Bottom Sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _vegOnly = false;
                        _sortBy = 'popular';
                      });
                      setModalState(() {});
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Veg Only Toggle
              SwitchListTile(
                title: Text(
                  'Veg Only',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                value: _vegOnly,
                activeColor: AppTheme.successGreen,
                onChanged: (value) {
                  setState(() => _vegOnly = value);
                  setModalState(() {});
                },
              ),
              
              const Divider(),
              
              // Sort Options
              Text(
                'Sort By',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              ...[
                {'value': 'popular', 'label': 'Popular'},
                {'value': 'price_low', 'label': 'Price: Low to High'},
                {'value': 'price_high', 'label': 'Price: High to Low'},
                {'value': 'rating', 'label': 'Top Rated'},
              ].map((option) => RadioListTile<String>(
                title: Text(option['label']!),
                value: option['value']!,
                groupValue: _sortBy,
                activeColor: AppTheme.primaryOrange,
                onChanged: (value) {
                  setState(() => _sortBy = value!);
                  setModalState(() {});
                },
              )),
              
              const SizedBox(height: 20),
              
              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 4️⃣ FEATURE HIGHLIGHTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildFeatureHighlights() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 90,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildFeatureCard(
              icon: Icons.eco,
              title: 'Healthy Food',
              color: Colors.green,
            ),
            _buildFeatureCard(
              icon: Icons.water_drop_outlined,
              title: 'Low Oil',
              color: Colors.blue,
            ),
            _buildFeatureCard(
              icon: Icons.verified_user,
              title: 'Verified Cooks',
              color: Colors.orange,
            ),
            _buildFeatureCard(
              icon: Icons.attach_money,
              title: 'Affordable',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 5️⃣ CATEGORY CHIPS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildCategoryChips() {
    final categories = [
      {'name': 'All', 'icon': Icons.apps},
      {'name': 'Veg Thali', 'icon': Icons.restaurant},
      {'name': 'Non-Veg', 'icon': Icons.dinner_dining},
      {'name': 'Beverages', 'icon': Icons.local_drink},
      {'name': 'Roti & Rice', 'icon': Icons.fastfood},
      {'name': 'Sweets', 'icon': Icons.cake},
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['name'];
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category['name'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category['name'] as String);
              },
              selectedColor: AppTheme.primaryOrange,
              backgroundColor: AppTheme.lightGrey,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 6️⃣ HOT DEALS SECTION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildHotDealsSection() {
    return Consumer<DishesProvider>(
      builder: (context, dishesProvider, _) {
        if (dishesProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                color: AppTheme.primaryOrange,
              ),
            ),
          );
        }

        final dishes = _getFilteredDishes(dishesProvider.dishes);
        final hotDeals = dishes.take(5).toList();

        if (hotDeals.isEmpty) {
          return _buildEmptyState();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's Special",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('👩‍🍳', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to see all
                      },
                      child: Text(
                        'See All',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hotDeals.length,
                  itemBuilder: (context, index) {
                    return _buildDishCard(hotDeals[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 7️⃣ MOST BOUGHT SECTION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildMostBoughtSection() {
    return Consumer<DishesProvider>(
      builder: (context, dishesProvider, _) {
        final dishes = _getFilteredDishes(dishesProvider.dishes);
        final mostBought = dishes.skip(5).take(5).toList();

        if (mostBought.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Customer Favorites',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('🍱', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to see all
                      },
                      child: Text(
                        'See All',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: mostBought.length,
                  itemBuilder: (context, index) {
                    return _buildDishCard(mostBought[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🍽️ DISH CARD (Rounded, Modern, with Badges)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
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
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: dish.imageUrl,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.lightGrey,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryOrange,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.lightGrey,
                      child: const Icon(
                        Icons.restaurant,
                        size: 50,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                
                // Veg/Non-Veg Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      dish.isVeg ? Icons.crop_square : Icons.change_history,
                      color: dish.isVeg ? Colors.green : Colors.red,
                      size: 16,
                    ),
                  ),
                ),
                
                // Rating Badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          dish.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Favorite Icon
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.favorite_border,
                        color: AppTheme.primaryOrange,
                        size: 20,
                      ),
                      onPressed: () {
                        // TODO: Add to favorites
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
            
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dish.cookName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${dish.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ADD',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📭 EMPTY STATE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No dishes found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
