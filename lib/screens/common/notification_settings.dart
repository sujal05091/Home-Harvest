import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _scrollController = ScrollController();
  
  bool _paymentNotifications = true;
  bool _trackingNotifications = true;
  bool _completeOrderNotifications = true;
  bool _generalNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paymentNotifications = prefs.getBool('payment_notifications') ?? true;
      _trackingNotifications = prefs.getBool('tracking_notifications') ?? true;
      _completeOrderNotifications = prefs.getBool('complete_order_notifications') ?? true;
      _generalNotifications = prefs.getBool('general_notifications') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildNotificationToggle({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFC8019),
            activeTrackColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
            inactiveThumbColor: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 24),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════
              // CONTENT
              // ═══════════════════════════════════════
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Notification Settings Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Payment
                              _buildNotificationToggle(
                                title: 'Payment',
                                value: _paymentNotifications,
                                onChanged: (value) {
                                  setState(() {
                                    _paymentNotifications = value;
                                  });
                                  _saveSetting('payment_notifications', value);
                                },
                              ),
                              
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey[200],
                              ),
                              
                              // Tracking
                              _buildNotificationToggle(
                                title: 'Tracking',
                                value: _trackingNotifications,
                                onChanged: (value) {
                                  setState(() {
                                    _trackingNotifications = value;
                                  });
                                  _saveSetting('tracking_notifications', value);
                                },
                              ),
                              
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey[200],
                              ),
                              
                              // Complete Order
                              _buildNotificationToggle(
                                title: 'Complete Order',
                                value: _completeOrderNotifications,
                                onChanged: (value) {
                                  setState(() {
                                    _completeOrderNotifications = value;
                                  });
                                  _saveSetting('complete_order_notifications', value);
                                },
                              ),
                              
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey[200],
                              ),
                              
                              // General Notification
                              _buildNotificationToggle(
                                title: 'Notification',
                                value: _generalNotifications,
                                onChanged: (value) {
                                  setState(() {
                                    _generalNotifications = value;
                                  });
                                  _saveSetting('general_notifications', value);
                                },
                              ),
                            ],
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
      ),
    );
  }
}
