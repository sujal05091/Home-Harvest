import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../app_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedLanguage = 'EN';
  String _selectedFlag = '🇮🇳';

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Language',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              _languageOption('🇮🇳', 'English', 'EN'),
              _languageOption('🇮🇳', 'हिंदी', 'HI'),
              _languageOption('🇮🇳', 'ಕನ್ನಡ', 'KN'),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOption(String flag, String language, String code) {
    final isSelected = _selectedLanguage == code;
    return ListTile(
      leading: Text(flag, style: TextStyle(fontSize: 24)),
      title: Text(
        language,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Color(0xFFFC8019))
          : null,
      onTap: () {
        setState(() {
          _selectedLanguage = code;
          _selectedFlag = flag;
        });
        Navigator.pop(context);
        // TODO: Implement language change logic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to $language'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : CustomScrollView(
              slivers: [
                // Header with gradient
                SliverAppBar(
                  expandedHeight: 280,
                  floating: false,
                  pinned: true,
                  backgroundColor: Color(0xFFFC8019),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFB347),
                            Color(0xFFFC8019),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Profile Picture
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      user.name[0].toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFC8019),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Show options to change or remove photo
                                      showModalBottomSheet(
                                        context: context,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        ),
                                        builder: (context) => Container(
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Profile Photo',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 20),
                                              ListTile(
                                                leading: Icon(Icons.camera_alt, color: Color(0xFFFC8019)),
                                                title: Text('Change Photo'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Navigator.pushNamed(context, AppRouter.editProfile);
                                                },
                                              ),
                                              ListTile(
                                                leading: Icon(Icons.delete, color: Colors.red),
                                                title: Text('Remove Photo'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  // TODO: Implement remove photo logic
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Photo removal coming soon')),
                                                  );
                                                },
                                              ),
                                              SizedBox(height: 10),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFC8019),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            // Name
                            Text(
                              user.name,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            // Phone
                            Text(
                              user.phone,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            SizedBox(height: 6),
                            // Role Badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.role == 'customer'
                                        ? Icons.shopping_bag
                                        : user.role == 'cook'
                                            ? Icons.restaurant
                                            : Icons.delivery_dining,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    user.role.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            // Edit Profile Button
                            ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.pushNamed(context, AppRouter.editProfile);
                                // Refresh profile if data was updated
                                if (result == true && mounted) {
                                  setState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFC8019),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 5,
                              ),
                              child: Text(
                                'Edit Profile',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    // Language Selector
                    GestureDetector(
                      onTap: _showLanguageSelector,
                      child: Container(
                        margin: EdgeInsets.only(right: 16, top: 8),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedFlag, style: TextStyle(fontSize: 18)),
                            SizedBox(width: 4),
                            Text(
                              _selectedLanguage,
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.black, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Menu Items
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Conditional menu items based on user role
                        if (user.role == 'customer') ...[
                          // CUSTOMER MENU
                          _buildMenuCard(
                            context,
                            icon: Icons.receipt_long,
                            iconColor: Color(0xFFFC8019),
                            title: 'My Orders',
                            subtitle: 'Track and manage your recent orders',
                            onTap: () => Navigator.pushNamed(context, AppRouter.orderHistory),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.lunch_dining,
                            iconColor: Color(0xFF27AE60),
                            title: 'Tiffin Subscriptions',
                            subtitle: 'Manage your daily or monthly tiffin plans',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Tiffin Subscriptions',
                                'message': 'Tiffin subscription feature is coming soon! You will be able to subscribe to daily or monthly meal plans.',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.location_on,
                            iconColor: Color(0xFF5B9BD5),
                            title: 'Saved Addresses',
                            subtitle: 'Your saved home or office addresses',
                            onTap: () => Navigator.pushNamed(context, AppRouter.selectAddress),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.payment,
                            iconColor: Color(0xFF7B68A6),
                            title: 'Payment Methods',
                            subtitle: 'Manage payment options',
                            onTap: () => Navigator.pushNamed(context, AppRouter.paymentSettings),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.local_offer,
                            iconColor: Color(0xFFFC8019),
                            title: 'Offers & Coupons',
                            subtitle: 'Find and apply discounts',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Offers & Coupons',
                                'message': 'Exciting offers and coupons are coming soon! Stay tuned for amazing deals.',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.headset_mic,
                            iconColor: Color(0xFF8BC34A),
                            title: 'Help & Support',
                            subtitle: 'Get assistance or raise a ticket',
                            onTap: () => Navigator.pushNamed(context, AppRouter.helpSupport),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.info,
                            iconColor: Color(0xFFFC8019),
                            title: 'About HomeHarvest',
                            subtitle: 'Learn more about our service',
                            onTap: () => Navigator.pushNamed(context, AppRouter.legalPolicies),
                          ),
                        ] else if (user.role == 'cook') ...[
                          // COOK MENU
                          _buildMenuCard(
                            context,
                            icon: Icons.dashboard,
                            iconColor: Color(0xFFFC8019),
                            title: 'Dashboard',
                            subtitle: 'View your business overview and stats',
                            onTap: () => Navigator.pushNamed(context, AppRouter.cookDashboardModern),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.shopping_bag,
                            iconColor: Color(0xFF27AE60),
                            title: 'Today\'s Orders',
                            subtitle: 'Manage orders scheduled for today',
                            onTap: () => Navigator.pushNamed(context, AppRouter.cookOrders),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.restaurant_menu,
                            iconColor: Color(0xFFE91E63),
                            title: 'My Dishes',
                            subtitle: 'View and manage your menu items',
                            onTap: () => Navigator.pushNamed(context, AppRouter.cookDishes),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.add_circle,
                            iconColor: Color(0xFF4CAF50),
                            title: 'Add Dish',
                            subtitle: 'Create and publish new dishes',
                            onTap: () => Navigator.pushNamed(context, AppRouter.addDish),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.currency_rupee,
                            iconColor: Color(0xFF27AE60),
                            title: 'Earnings',
                            subtitle: 'Track your revenue and income',
                            onTap: () => Navigator.pushNamed(context, AppRouter.cookEarnings),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.account_balance_wallet,
                            iconColor: Color(0xFF7B68A6),
                            title: 'Wallet / Withdraw',
                            subtitle: 'Manage wallet and withdraw funds',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Wallet',
                                'message': 'Wallet management coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.account_balance,
                            iconColor: Color(0xFF5B9BD5),
                            title: 'Bank Account',
                            subtitle: 'Add or update bank details',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Bank Account',
                                'message': 'Bank account setup coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.verified,
                            iconColor: Color(0xFF2196F3),
                            title: 'Verification Status',
                            subtitle: 'Check your account verification status',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Verification',
                                'message': 'Verification status coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.star_rate,
                            iconColor: Color(0xFFFFB300),
                            title: 'Ratings & Reviews',
                            subtitle: 'View customer feedback and ratings',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Ratings & Reviews',
                                'message': 'Ratings management coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.notifications,
                            iconColor: Color(0xFFFF5722),
                            title: 'Notifications',
                            subtitle: 'Manage notification preferences',
                            onTap: () => Navigator.pushNamed(context, AppRouter.notificationSettings),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.headset_mic,
                            iconColor: Color(0xFF8BC34A),
                            title: 'Help & Support',
                            subtitle: 'Get assistance or raise a ticket',
                            onTap: () => Navigator.pushNamed(context, AppRouter.helpSupport),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.info,
                            iconColor: Color(0xFFFC8019),
                            title: 'About HomeHarvest',
                            subtitle: 'Learn more about our service',
                            onTap: () => Navigator.pushNamed(context, AppRouter.legalPolicies),
                          ),
                        ] else if (user.role == 'rider') ...[
                          // RIDER MENU
                          _buildMenuCard(
                            context,
                            icon: Icons.power_settings_new,
                            iconColor: Color(0xFF4CAF50),
                            title: 'Online / Offline Status',
                            subtitle: 'Toggle your availability for deliveries',
                            onTap: () => Navigator.pushNamed(context, AppRouter.riderHomeModern),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.delivery_dining,
                            iconColor: Color(0xFFFC8019),
                            title: 'Today\'s Deliveries',
                            subtitle: 'View and manage today\'s delivery tasks',
                            onTap: () => Navigator.pushNamed(context, AppRouter.riderHomeModern),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.history,
                            iconColor: Color(0xFF7B68A6),
                            title: 'Ride History',
                            subtitle: 'View your past delivery records',
                            onTap: () => Navigator.pushNamed(context, AppRouter.riderHistory),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.currency_rupee,
                            iconColor: Color(0xFF27AE60),
                            title: 'Earnings',
                            subtitle: 'Track your delivery earnings',
                            onTap: () => Navigator.pushNamed(context, AppRouter.riderEarnings),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.account_balance_wallet,
                            iconColor: Color(0xFF2196F3),
                            title: 'Wallet',
                            subtitle: 'View your wallet balance',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Wallet',
                                'message': 'Wallet feature coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.money,
                            iconColor: Color(0xFF4CAF50),
                            title: 'Withdraw Money',
                            subtitle: 'Transfer earnings to your bank',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Withdraw Money',
                                'message': 'Withdrawal feature coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.card_giftcard,
                            iconColor: Color(0xFFFFB300),
                            title: 'Incentives',
                            subtitle: 'View bonuses and incentive programs',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Incentives',
                                'message': 'Incentive programs coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.account_balance,
                            iconColor: Color(0xFF5B9BD5),
                            title: 'Bank Account',
                            subtitle: 'Add or update bank details',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Bank Account',
                                'message': 'Bank account setup coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.two_wheeler,
                            iconColor: Color(0xFFE91E63),
                            title: 'Vehicle Details',
                            subtitle: 'Manage your vehicle information',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRouter.comingSoon,
                              arguments: {
                                'title': 'Vehicle Details',
                                'message': 'Vehicle management coming soon!',
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.notifications,
                            iconColor: Color(0xFFFF5722),
                            title: 'Notifications',
                            subtitle: 'Manage notification preferences',
                            onTap: () => Navigator.pushNamed(context, AppRouter.notificationSettings),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.headset_mic,
                            iconColor: Color(0xFF8BC34A),
                            title: 'Help & Support',
                            subtitle: 'Get assistance or raise a ticket',
                            onTap: () => Navigator.pushNamed(context, AppRouter.helpSupport),
                          ),
                          SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.info,
                            iconColor: Color(0xFFFC8019),
                            title: 'About HomeHarvest',
                            subtitle: 'Learn more about our service',
                            onTap: () => Navigator.pushNamed(context, AppRouter.legalPolicies),
                          ),
                        ],
                        SizedBox(height: 24),
                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    'Logout',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to logout?',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Logout',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await authProvider.signOut();
                                if (context.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRouter.roleSelect,
                                    (route) => false,
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text(
                                  'Logout',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
