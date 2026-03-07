import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/home_products_provider.dart';
import '../../models/order_model.dart';
import '../../models/home_product_model.dart';
import '../../models/verification_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/fcm_service.dart';
import '../../app_router.dart';
import '../../theme.dart';
import '../cook/product_verification_status.dart';
import '../customer/select_location_map_osm.dart';
import 'seller_withdraw_screen.dart';

// ?????????????????????????????????????????????????????????????????????
// ?? SELLER DASHBOARD � Root screen for the "seller" role
// ?????????????????????????????????????????????????????????????????????
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
      Provider.of<OrdersProvider>(context, listen: false).loadCookOrders(uid);
      FCMService().saveFCMToken();
      _listenForNewOrders(uid);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // ?? Listen for incoming order notifications
  void _listenForNewOrders(String sellerId) {
    // Only filter on recipientId (single-field index, always available).
    // Type and read are checked client-side to avoid needing a composite index.
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: sellerId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data() as Map<String, dynamic>;
        // Client-side filters: only unread NEW_PRODUCT_ORDER notifications
        if (data['type'] != 'NEW_PRODUCT_ORDER') continue;
        if (data['read'] == true) continue;
        final inner = data['data'] as Map<String, dynamic>? ?? {};
        final title = data['title'] as String? ?? '??? New Order!';
        final body = data['body'] as String? ?? 'You have a new product order.';
        // Show system-level top-bar notification
        FCMService().showLocalNotification(title: title, body: body);
        _showNewOrderDialog(
          orderId: data['orderId'] ?? '',
          customerName: inner['customerName'] ?? '',
          dishNames: inner['dishNames'] ?? '',
          totalAmount: (inner['totalAmount'] as num?)?.toDouble() ?? 0,
          notificationId: change.doc.id,
        );
      }
    }, onError: (e) {
      print('? [Seller] Notification listener error: $e');
    });
  }

  // ?? New-order popup
  void _showNewOrderDialog({
    required String orderId,
    required String customerName,
    required String dishNames,
    required double totalAmount,
    required String notificationId,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFC8019).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag, color: Color(0xFFFC8019), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('?? New Order!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFC8019))),
                  Text('Order #${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(Icons.person, 'Customer', customerName),
            const SizedBox(height: 10),
            _infoRow(Icons.inventory_2, 'Items', dishNames),
            const SizedBox(height: 10),
            _infoRow(Icons.currency_rupee, 'Amount',
                '₹${totalAmount.toStringAsFixed(0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(notificationId)
                  .update({'read': true});
              Navigator.pop(ctx);
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(notificationId)
                  .update({'read': true});
              Navigator.pop(ctx);
              // Switch to Orders tab (index 1)
              setState(() => _currentIndex = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFC8019),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View Order',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFC8019)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(onSwitchTab: (i) => setState(() => _currentIndex = i)),
          const _OrdersTab(),        // index 1 � NEW
          const _ProductsTab(),      // index 2
          const _EarningsTab(),      // index 3
          const _ProfileTab(),       // index 4
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryOrange.withOpacity(0.15),
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFFFC8019)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFFFC8019)),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Color(0xFFFC8019)),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFFC8019)),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFFFC8019)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ?????????????????????????????????????????????????????????????????????
// TAB 1 � HOME
// ?????????????????????????????????????????????????????????????????????
class _HomeTab extends StatelessWidget {
  final void Function(int) onSwitchTab;
  const _HomeTab({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? 'Seller';

        // ? Stream live status from product_verifications (what admin actually updates)
        return StreamBuilder<ProductVerificationModel?>(
          stream: FirestoreService().getProductVerification(uid),
          builder: (context, verSnap) {
            final status = verSnap.data?.status.name;
            final isApproved = status == 'APPROVED';
            final isRejected = status == 'REJECTED';

            return CustomScrollView(
          slivers: [
            // -- HEADER -----------------------------------------------
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFFFC8019),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFC8019), Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    Colors.white.withOpacity(0.3),
                                child: Text(
                                  (name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'S'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Welcome back,',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.white70)),
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isApproved
                                      ? '? Verified'
                                      : isRejected
                                          ? '? Rejected'
                                          : '? Pending',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Home Product Seller',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -- BODY -------------------------------------------------
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Verification status card
                  _VerificationCard(status: status),
                  const SizedBox(height: 16),

                  if (isApproved) ...[
                    // Quick stats
                    _QuickStatsRow(uid: uid),
                    const SizedBox(height: 16),

                    // Quick actions
                    Text('Quick Actions',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Add Product',
                            color: const Color(0xFFFC8019),
                            onTap: () => onSwitchTab(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.storefront_outlined,
                            label: 'View Market',
                            color: const Color(0xFF4CAF50),
                            onTap: () =>
                                Navigator.pushNamed(
                                    context, AppRouter.harvestMarket),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tips card
                  _TipsCard(isApproved: isApproved),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        );
          },
        );
      },
    );
  }
}

// Verification status card on the home tab
class _VerificationCard extends StatelessWidget {
  final String? status;
  const _VerificationCard({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'APPROVED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verified Seller',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                          fontSize: 15)),
                  Text('You can list and sell your products.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.green[600])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'PENDING') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verification Under Review',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                          fontSize: 15)),
                  Text('Admin is reviewing your submission. 24�48 hours.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.orange[600])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'REJECTED') {
      return _RejectedCard(onReapply: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const ProductVerificationStatusScreen()),
        );
      });
    }

    // Not submitted
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFC8019), Color(0xFFFF6B35)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text('Verification Required',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Submit your workplace details to start selling products on Home Harvest.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProductVerificationStatusScreen()),
              );
            },
            icon: const Icon(Icons.assignment_turned_in_outlined,
                color: Color(0xFFFC8019)),
            label: Text('Apply Now',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFC8019))),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedCard extends StatelessWidget {
  final VoidCallback onReapply;
  const _RejectedCard({required this.onReapply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification Rejected',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                        fontSize: 15)),
                Text('Please resubmit with correct details.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.red[600])),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onReapply,
                  child: Text('Reapply ?',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final String uid;
  const _QuickStatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('home_products')
          .where('sellerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final productCount = snap.data?.docs.length ?? 0;
        final availableCount = snap.data?.docs
                .where((d) => (d.data() as Map)['isAvailable'] == true)
                .length ??
            0;
        return Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'Products', value: '$productCount', emoji: '??')),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    label: 'Available', value: '$availableCount', emoji: '?')),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(label: 'Orders', value: '�', emoji: '??')),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, emoji;
  const _StatCard(
      {required this.label, required this.value, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final bool isApproved;
  const _TipsCard({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final tips = isApproved
        ? [
            '?? Add clear product photos to attract buyers',
            '??? Price competitively for more orders',
            '? Great packaging leads to better reviews',
            '?? Keep products marked available when ready to sell',
          ]
        : [
            '?? Submit workplace photos & video',
            '?? List all ingredients used in your products',
            '?? FSSAI number speeds up approval',
            '?? Admin reviews in 24�48 hours',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isApproved ? '?? Seller Tips' : '?? How to get approved',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(t,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[700], height: 1.4)),
              )),
        ],
      ),
    );
  }
}

// ?????????????????????????????????????????????????????????????????????
// TAB 2 � ORDERS  (seller order management)
// ?????????????????????????????????????????????????????????????????????
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}


class _OrdersTabState extends State<_OrdersTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Accept order ----------------------------------------------------
  Future<void> _acceptOrder(String orderId) async {
    final op = Provider.of<OrdersProvider>(context, listen: false);
    final ok = await op.updateOrderStatus(orderId, OrderStatus.ACCEPTED);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '? Order accepted! Tap "Start Packing" when ready.'
            : 'Failed to accept order'),
        backgroundColor: ok ? const Color(0xFFFC8019) : Colors.red,
      ));
    }
  }

  // --- Reject order ----------------------------------------------------
  Future<void> _rejectOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Order?'),
        content: const Text('Are you sure you want to reject this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final op = Provider.of<OrdersProvider>(context, listen: false);
      final ok = await op.updateOrderStatus(orderId, OrderStatus.CANCELLED);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Order rejected' : 'Failed to reject'),
          backgroundColor: ok ? Colors.orange : Colors.red,
        ));
      }
    }
  }

  // --- Start packing ---------------------------------------------------
  Future<void> _startPacking(String orderId) async {
    final op = Provider.of<OrdersProvider>(context, listen: false);
    final ok = await op.updateOrderStatus(orderId, OrderStatus.PREPARING);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '?? Packing started! Mark as ready when packed.'
            : 'Failed to update'),
        backgroundColor: ok ? Colors.blue : Colors.red,
      ));
    }
  }

  // --- Mark packed & ready ? notify riders ----------------------------
  Future<void> _markPackedReady(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Package Ready?'),
        content: const Text(
            'Mark product as packed and ready for pickup. Nearby riders will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Packed & Ready'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Notifying riders...'),
            ]),
          ),
        ),
      ),
    );

    final op = Provider.of<OrdersProvider>(context, listen: false);
    final ok = await op.updateOrderStatus(orderId, OrderStatus.READY);

    if (ok) {
      try {
        final orderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        if (orderDoc.exists) {
          final pickup = orderDoc.data()!['pickupLocation'] as GeoPoint;
          await FCMService().notifyNearbyRiders(
            orderId: orderId,
            pickupLat: pickup.latitude,
            pickupLng: pickup.longitude,
            radiusKm: 5.0,
          );
        }
      } catch (e) {
        print('?? [Seller] Rider notification failed: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '? Package ready! Riders notified.'
            : 'Failed to update status'),
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // --- Status helpers --------------------------------------------------
  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.PLACED:        return Colors.orange;
      case OrderStatus.ACCEPTED:      return Colors.blue;
      case OrderStatus.PREPARING:     return Colors.purple;
      case OrderStatus.READY:         return Colors.green;
      case OrderStatus.RIDER_ASSIGNED:
      case OrderStatus.RIDER_ACCEPTED: return Colors.teal;
      case OrderStatus.ON_THE_WAY_TO_PICKUP:
      case OrderStatus.PICKED_UP:
      case OrderStatus.ON_THE_WAY_TO_DROP: return Colors.indigo;
      case OrderStatus.DELIVERED:     return Colors.green.shade800;
      case OrderStatus.CANCELLED:     return Colors.red;
    }
  }

  String _statusText(OrderStatus s) {
    switch (s) {
      case OrderStatus.PLACED:        return 'New Order';
      case OrderStatus.ACCEPTED:      return 'Seller Accepted';
      case OrderStatus.PREPARING:     return 'Seller is Packing';
      case OrderStatus.READY:         return 'Product Ready';
      case OrderStatus.RIDER_ASSIGNED: return 'Rider Assigned';
      case OrderStatus.RIDER_ACCEPTED: return 'Rider on Way';
      case OrderStatus.ON_THE_WAY_TO_PICKUP: return 'Rider Coming';
      case OrderStatus.PICKED_UP:     return 'Picked Up';
      case OrderStatus.ON_THE_WAY_TO_DROP:   return 'Out for Delivery';
      case OrderStatus.DELIVERED:     return 'Delivered';
      case OrderStatus.CANCELLED:     return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = Provider.of<OrdersProvider>(context);
    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Orders',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFFC8019),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => op.loadCookOrders(uid),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // -- Active Orders ----------------------------------------
          op.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFC8019)))
              : op.orders.isEmpty
                  ? _emptyState(
                      Icons.receipt_long, 'No active orders', 'New orders will appear here')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: op.orders.length,
                      itemBuilder: (ctx, i) =>
                          _buildOrderCard(op.orders[i]),
                    ),

          // -- Order History ----------------------------------------
          StreamBuilder<List<OrderModel>>(
            stream: FirestoreService().getSellerOrderHistory(uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFC8019)));
              }
              final history = snap.data ?? [];
              if (history.isEmpty) {
                return _emptyState(Icons.history,
                    'No order history', 'Delivered orders will show here');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (ctx, i) =>
                    _buildHistoryCard(history[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderId.length >= 8 ? order.orderId.substring(0, 8) : order.orderId}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_statusText(order.status),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Customer: ${order.customerName}',
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'Items: ${order.dishItems.map((e) => '${e.dishName} �${e.quantity}').join(', ')}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '₹${order.total.toStringAsFixed(0)}  �  Delivery: ₹${order.deliveryCharge.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFC8019)),
            ),
            const SizedBox(height: 12),
            // Action area
            if (order.status == OrderStatus.PLACED)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectOrder(order.orderId),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptOrder(order.orderId),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFC8019),
                        foregroundColor: Colors.white),
                    child: const Text('Accept'),
                  ),
                ),
              ])
            else if (order.status == OrderStatus.ACCEPTED)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startPacking(order.orderId),
                  icon: const Icon(Icons.inventory_2),
                  label: const Text('?? Seller is Packing'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                ),
              )
            else if (order.status == OrderStatus.PREPARING)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markPackedReady(order.orderId),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('? Product Ready'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                ),
              )
            else if (order.status == OrderStatus.RIDER_ASSIGNED ||
                order.status == OrderStatus.RIDER_ACCEPTED ||
                order.status == OrderStatus.ON_THE_WAY_TO_PICKUP)
              _statusBanner(
                  Icons.delivery_dining,
                  'Rider on the way to pick up',
                  Colors.teal)
            else if (order.status == OrderStatus.PICKED_UP ||
                order.status == OrderStatus.ON_THE_WAY_TO_DROP)
              _statusBanner(
                  Icons.local_shipping, 'Out for delivery', Colors.indigo)
            else if (order.status == OrderStatus.DELIVERED)
              _statusBanner(Icons.check_circle,
                  'Delivered successfully', Colors.green)
            else if (order.status == OrderStatus.CANCELLED)
              _statusBanner(Icons.cancel, 'Cancelled', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(OrderModel order) {
    final isDelivered = order.status == OrderStatus.DELIVERED;
    final earning = order.total - order.deliveryCharge;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDelivered
                    ? Colors.green.withOpacity(0.12)
                    : Colors.red.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDelivered ? Icons.check_circle : Icons.cancel,
                color: isDelivered ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.orderId.length >= 8 ? order.orderId.substring(0, 8) : order.orderId}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (isDelivered)
                        Text(
                          '+₹${earning.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green[700]),
                        )
                      else
                        Text('Cancelled',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(order.customerName,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600])),
                  Text(
                    order.dishItems
                        .map((e) => '${e.dishName} �${e.quantity}')
                        .join(', '),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(order.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} � $h:$m $amPm';
  }

  Widget _statusBanner(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}

// ?????????????????????????????????????????????????????????????????????
// TAB 3 � PRODUCTS
// ?????????????????????????????????????????????????????????????????????
class _ProductsTab extends StatefulWidget {
  const _ProductsTab();

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
      context.read<HomeProductsProvider>().loadSellerProducts(uid);
    });
  }

  @override
  void dispose() {
    context.read<HomeProductsProvider>().cancelSellerProductsListener();
    super.dispose();
  }

  void _openProductForm({HomeProductModel? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SellerProductFormSheet(existing: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};

        // ? Stream live status from product_verifications (what admin actually updates)
        return StreamBuilder<ProductVerificationModel?>(
          stream: FirestoreService().getProductVerification(uid),
          builder: (context, verSnap) {
            final status = verSnap.data?.status.name;
            final isApproved = status == 'APPROVED';
            final rejectionReason = verSnap.data?.rejectionReason;

            if (!isApproved) {
              return _NotApprovedPlaceholder(
                status: status,
                rejectionReason: rejectionReason,
              );
            }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('My Products',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: const Color(0xFFFC8019),
            actions: [
              IconButton(
                  onPressed: () => _openProductForm(),
                  icon: const Icon(Icons.add, color: Colors.white)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openProductForm(),
            backgroundColor: const Color(0xFFFC8019),
            icon: const Icon(Icons.add),
            label: Text('Add Product',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          body: Consumer<HomeProductsProvider>(
            builder: (ctx, provider, _) {
              if (provider.isLoading) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFFC8019)));
              }
              if (provider.sellerProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No products yet',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Tap + Add Product to list your first item',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: provider.sellerProducts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final p = provider.sellerProducts[i];
                  return _SellerProductCard(
                    product: p,
                    onEdit: () => _openProductForm(product: p),
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Product'),
                          content: Text(
                              'Delete "${p.name}"? This cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style:
                                        TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.deleteProduct(p.productId, p.sellerId);
                      }
                    },
                    onToggle: () async {
                      await provider.updateProduct(
                          p.copyWith(isAvailable: !p.isAvailable));
                    },
                  );
                },
              );
            },
          ),
        );
          },
        );
      },
    );
  }
}

class _NotApprovedPlaceholder extends StatelessWidget {
  final String? status;
  final String? rejectionReason;
  const _NotApprovedPlaceholder({this.status, this.rejectionReason});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'PENDING';
    final isRejected = status == 'REJECTED';

    // -- REJECTED STATE ------------------------------------------------
    if (isRejected) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                'Verification Rejected',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'Your application was rejected by admin.\nFix the issues below and resubmit.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey[500], height: 1.5),
              ),
              if (rejectionReason != null && rejectionReason!.isNotEmpty) ...[  
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Feedback:',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(rejectionReason!,
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProductVerificationStatusScreen()),
                ),
                icon: const Icon(Icons.refresh),
                label: Text('Resubmit Verification',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC8019),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.access_time : Icons.lock_outline,
              size: 80,
              color: isPending ? Colors.orange[300] : Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              isPending
                  ? 'Verification Under Review'
                  : 'Verification Required',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isPending ? Colors.orange[700] : Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Admin is reviewing your application.\nYou can add products once approved.'
                  : 'Complete your seller verification first\nto add and sell products.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
            if (!isPending) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ProductVerificationStatusScreen()),
                ),
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label:
                    Text('Apply for Verification',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC8019),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SellerProductCard extends StatelessWidget {
  final HomeProductModel product;
  final VoidCallback onEdit, onDelete, onToggle;

  const _SellerProductCard(
      {required this.product,
      required this.onEdit,
      required this.onDelete,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16)),
            child: product.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.orange[50],
                        child: const Icon(Icons.inventory_2,
                            color: Colors.orange)),
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: Colors.orange[50],
                    child: const Icon(Icons.inventory_2,
                        color: Colors.orange, size: 36)),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Switch(
                        value: product.isAvailable,
                        onChanged: (_) => onToggle(),
                        activeColor: Colors.green,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  Text('₹${product.price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFFFC8019),
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    product.isAvailable ? '? In Stock' : '? Out of Stock',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: product.isAvailable
                            ? Colors.green
                            : Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SmallBtn(
                          label: 'Edit',
                          color: Colors.blue,
                          onTap: onEdit),
                      const SizedBox(width: 8),
                      _SmallBtn(
                          label: 'Delete',
                          color: Colors.red,
                          onTap: onDelete),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// Product add/edit form sheet (identical logic to CookProductsScreen's sheet)
class _SellerProductFormSheet extends StatefulWidget {
  final HomeProductModel? existing;
  const _SellerProductFormSheet({this.existing});

  @override
  State<_SellerProductFormSheet> createState() =>
      _SellerProductFormSheetState();
}

class _SellerProductFormSheetState extends State<_SellerProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _ingredientsCtrl;
  late final TextEditingController _stockCtrl;
  bool _isAvailable = true;
  bool _isSaving = false;
  final List<String> _selectedCategories = [];
  String? _existingImageUrl;
  File? _pickedImage;

  final _picker = ImagePicker();
  final _storage = StorageService();

  static const _cats = [
    'Pickles',
    'Masalas',
    'Sweets',
    'Snacks',
    'Jams',
    'Beverages',
    'Baked Goods',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(text: e != null ? '${e.price}' : '');
    _ingredientsCtrl = TextEditingController(text: e?.ingredients ?? '');
    _stockCtrl = TextEditingController(text: e != null ? '${e.stock}' : '');
    _isAvailable = e?.isAvailable ?? true;
    _existingImageUrl = (e?.imageUrl.isNotEmpty ?? false) ? e!.imageUrl : null;
    if (e != null && e.category.isNotEmpty) _selectedCategories.add(e.category);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _ingredientsCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFC8019)),
              title: Text('Take Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFFFC8019)),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final xfile = await _picker.pickImage(
      source: choice,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => _pickedImage = File(xfile.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')));
      return;
    }
    setState(() => _isSaving = true);

    final provider =
        Provider.of<HomeProductsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser!.uid;
    final sellerName = auth.currentUser!.name;

    try {
      String imageUrl = _existingImageUrl ?? '';
      if (_pickedImage != null && !kIsWeb) {
        imageUrl = await _storage.uploadDishImage(
          _pickedImage!,
          widget.existing?.productId ??
              'product_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final product = HomeProductModel(
        productId: widget.existing?.productId ?? '',
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text) ?? 0,
        ingredients: _ingredientsCtrl.text.trim(),
        category: _selectedCategories.first,
        imageUrl: imageUrl,
        sellerId: uid,
        sellerName: sellerName,
        workplace: '',
        stock: int.tryParse(_stockCtrl.text) ?? 0,
        isAvailable: _isAvailable,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      final isNew = widget.existing == null;
      if (isNew) {
        await provider.addProduct(product);
      } else {
        await provider.updateProduct(product);
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  isNew ? 'Product added successfully!' : 'Product updated!',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Drag handle ---------------------------------------
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Add Product' : 'Edit Product',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // -- Image Picker --------------------------------------
              GestureDetector(
                onTap: _isSaving ? null : _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.orange.shade300, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _pickedImage != null && !kIsWeb
                        ? Image.file(_pickedImage!, fit: BoxFit.cover)
                        : (_existingImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _existingImageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _imagePlaceholder(),
                              )
                            : _imagePlaceholder()),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Tap to add product photo',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[500])),
              ),
              const SizedBox(height: 16),

              // -- Product Name --------------------------------------
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    _inputDecor('Product name', Icons.inventory_2_outlined),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // -- Description ---------------------------------------
              TextFormField(
                controller: _descriptionCtrl,
                decoration: _inputDecor(
                    'Description (optional)', Icons.description_outlined),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              // -- Price + Stock -------------------------------------
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          _inputDecor('Price (?)', Icons.currency_rupee),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecor(
                          'Stock (qty)', Icons.layers_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // -- Ingredients ---------------------------------------
              TextFormField(
                controller: _ingredientsCtrl,
                decoration: _inputDecor(
                    'Ingredients (e.g. mango, salt, spices)',
                    Icons.spa_outlined),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // -- Category ------------------------------------------
              Text('Category',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cats.map((cat) {
                  final sel = _selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat,
                        style: GoogleFonts.poppins(fontSize: 12)),
                    selected: sel,
                    selectedColor:
                        const Color(0xFFFC8019).withOpacity(0.18),
                    checkmarkColor: const Color(0xFFFC8019),
                    onSelected: (_) => setState(() {
                      _selectedCategories
                        ..clear()
                        ..add(cat);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // -- Available toggle ----------------------------------
              SwitchListTile(
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                title: Text('Available for purchase',
                    style: GoogleFonts.poppins(fontSize: 14)),
                activeColor: const Color(0xFFFC8019),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // -- Save button ---------------------------------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC8019),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.existing == null
                              ? 'Add Product'
                              : 'Save Changes',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 48, color: Colors.orange[300]),
        const SizedBox(height: 8),
        Text('Add Product Photo',
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.orange[400],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[500]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFC8019), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}

// ?????????????????????????????????????????????????????????????????????
// TAB 3 � EARNINGS
// ?????????????????????????????????????????????????????????????????????
class _EarningsTab extends StatelessWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Earnings',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: FirestoreService().getSellerOrderHistory(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFC8019)));
          }

          final allOrders = snap.data ?? [];
          final delivered = allOrders
              .where((o) => o.status == OrderStatus.DELIVERED)
              .toList();

          // Compute earnings: food subtotal only (total - deliveryCharge)
          double totalEarnings = 0;
          double todayEarnings = 0;
          final now = DateTime.now();
          for (final o in delivered) {
            final earning = o.total - o.deliveryCharge;
            totalEarnings += earning;
            if (o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day) {
              todayEarnings += earning;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Summary cards ----------------------------------
                Row(
                  children: [
                    Expanded(
                      child: _EarningCard(
                        label: 'Today',
                        amount: todayEarnings,
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _EarningCard(
                        label: 'Total Earned',
                        amount: totalEarnings,
                        icon: Icons.account_balance_wallet,
                        color: const Color(0xFFFC8019),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _EarningCard(
                        label: 'Delivered Orders',
                        amount: delivered.length.toDouble(),
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        isCurrency: false,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _EarningCard(
                        label: 'Avg per Order',
                        amount: delivered.isEmpty
                            ? 0
                            : totalEarnings / delivered.length,
                        icon: Icons.trending_up,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // -- Withdraw button ---------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SellerWithdrawScreen()),
                    ),
                    icon: const Icon(Icons.account_balance_wallet,
                        color: Colors.white),
                    label: Text(
                      'Withdraw Earnings',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC8019),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // -- Recent transactions -----------------------------
                Text('Recent Transactions',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (delivered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No earnings yet',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text(
                            'Earnings appear here once orders are delivered.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...delivered.take(30).map((order) {
                    final earning = order.total - order.deliveryCharge;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_downward,
                                color: Colors.green, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.dishItems
                                      .map((e) => e.dishName)
                                      .join(', '),
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatEarningDate(order.createdAt),
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+₹${earning.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.green[700]),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatEarningDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _EarningCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isCurrency;

  const _EarningCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final display = isCurrency
        ? '₹${amount.toStringAsFixed(0)}'
        : amount.toInt().toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            display,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: color),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ?????????????????????????????????????????????????????????????????????
// TAB 4 � PROFILE
// ?????????????????????????????????????????????????????????????????????
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _isSaving = false;

  Future<void> _setBaseAddress() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationMapScreen(
          initialLocation: user.location,
          initialAddress: user.address,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final geoPoint = result['location'] as dynamic;
    final addressStr = result['address'] as String? ?? '';

    setState(() => _isSaving = true);
    try {
      await auth.updateUser(
        user.copyWith(
          location: geoPoint,
          address: addressStr.isNotEmpty ? addressStr : user.address,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('? Base address saved! Riders can now find you.'),
            backgroundColor: Color(0xFFFC8019),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving address: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Profile',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              color: const Color(0xFFFC8019).withOpacity(0.1),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFFC8019),
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.name ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Home Product Seller',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Menu items
            _ProfileItem(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.editProfile),
            ),
            _ProfileItem(
              icon: Icons.location_on_outlined,
              label: 'Set Base Address',
              subtitle: user?.address != null && user!.address!.isNotEmpty
                  ? user.address!
                  : user?.location != null
                      ? '${user!.location!.latitude.toStringAsFixed(5)}, ${user.location!.longitude.toStringAsFixed(5)}'
                      : 'Not set � riders need this to deliver',
              subtitleColor: user?.location == null ? Colors.red[400] : null,
              onTap: _isSaving ? () {} : _setBaseAddress,
              trailing: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFC8019),
                      ),
                    )
                  : null,
            ),
            _ProfileItem(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Verification Status',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const ProductVerificationStatusScreen()),
              ),
            ),
            _ProfileItem(
              icon: Icons.storefront_outlined,
              label: 'Browse Harvest Market',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.harvestMarket),
            ),
            _ProfileItem(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.helpSupport),
            ),
            _ProfileItem(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.changePassword),
            ),
            const Divider(indent: 16, endIndent: 16),
            _ProfileItem(
              icon: Icons.logout,
              label: 'Logout',
              iconColor: Colors.red,
              labelColor: Colors.red,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Logout'),
                    content:
                        const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await auth.signOut();
                  Navigator.pushReplacementNamed(
                      context, AppRouter.roleSelect);
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFFFC8019)),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: labelColor ?? Colors.black87)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: subtitleColor ?? Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
