import 'package:flutter/material.dart';
import '../../app_router.dart';
import '../../widgets/logout_modal.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ═══════════════════════════════════════
            // APP BAR
            // ═══════════════════════════════════════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 22),
                    onPressed: () {
                      // More options
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ═══════════════════════════════════════
            // SETTINGS LIST
            // ═══════════════════════════════════════
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 30, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // GENERAL SECTION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'General',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.editProfile);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.changePassword);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.payment,
                      title: 'Payment Settings',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.paymentSettings);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () {
                        Navigator.pushNamed(context, '/notifications');
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notification Settings',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.notificationSettings);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.security_outlined,
                      title: 'Security',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.security);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.language,
                      title: 'Language',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.language);
                      },
                    ),

                    const SizedBox(height: 24),

                    // PREFERENCES SECTION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.gavel_outlined,
                      title: 'Legal and Policies',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.legalPolicies);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.helpSupport);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSettingTile(
                      icon: Icons.logout,
                      title: 'Logout',
                      onTap: () => _showLogoutDialog(context),
                      textColor: const Color(0xFFFC8019),
                      iconColor: const Color(0xFFFC8019),
                    ),

                    const SizedBox(height: 24),

                    // VERSION INFO
                    Center(
                      child: Text(
                        'Home Harvest Version 1.0.0 Build 01',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
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

  // BUILD SETTING TILE
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: iconColor ?? Colors.grey[800],
            size: 24,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.grey[900],
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: iconColor ?? Colors.grey[400],
            size: 18,
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  // SHOW LOGOUT DIALOG
  void _showLogoutDialog(BuildContext context) async {
    final result = await LogoutModal.show(
      context,
      onLogout: () {
        // Perform logout - navigate to role select
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/role-select',
          (route) => false,
        );
      },
    );
    
    // Result is true if user confirmed logout, false if cancelled, null if dismissed
    if (result == true) {
      print('User confirmed logout');
    }
  }
}
