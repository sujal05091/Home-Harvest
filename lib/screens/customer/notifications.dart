import 'package:flutter/material.dart';

class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
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
            // APP BAR - Clean & Premium
            // ═══════════════════════════════════════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ═══════════════════════════════════════
            // NOTIFICATION LIST - Scannable & Clean
            // ═══════════════════════════════════════
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // ═══════════════════════════════════════
                    // TODAY SECTION
                    // ═══════════════════════════════════════
                    Column(
                      children: [
                        // DATE HEADER - Today
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Row(
                            children: [
                              Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // NOTIFICATION CARDS
                        _buildNotificationCard(
                          icon: Icons.local_offer,
                          title: 'Discount voucher!',
                          time: '5min ago',
                          isImportant: true,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.system_update,
                          title: 'New update! Ver 1.87',
                          time: '20min ago',
                          isImportant: true,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.mail_outline,
                          title: 'New message from Chris',
                          time: '35min ago',
                          isImportant: false,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.local_offer,
                          title: 'Discount voucher! 50%',
                          time: '2hour 60min ago',
                          isImportant: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ═══════════════════════════════════════
                    // YESTERDAY SECTION
                    // ═══════════════════════════════════════
                    Column(
                      children: [
                        // DATE HEADER - Yesterday with Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                height: 1,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Text(
                                    'Yesterday',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                        // NOTIFICATION CARDS
                        _buildNotificationCard(
                          icon: Icons.local_offer,
                          title: 'Discount voucher!',
                          time: '5min ago',
                          isImportant: true,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.system_update,
                          title: 'New update! Ver 1.87',
                          time: '20min ago',
                          isImportant: true,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.mail_outline,
                          title: 'New message from Chris',
                          time: '35min ago',
                          isImportant: false,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.local_offer,
                          title: 'Discount voucher! 50%',
                          time: '2hour 60min ago',
                          isImportant: true,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildNotificationCard(
                          icon: Icons.local_offer,
                          title: 'Discount voucher! 50%',
                          time: '2hour 60min ago',
                          isImportant: true,
                        ),
                      ],
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

  // BUILD NOTIFICATION CARD
  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String time,
    required bool isImportant,
  }) {
    const primaryOrange = Color(0xFFFC8019);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isImportant 
                ? primaryOrange.withOpacity(0.08) 
                : Colors.grey[300]!.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isImportant 
                      ? primaryOrange.withOpacity(0.12) 
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isImportant ? primaryOrange : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              
              // Text Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
