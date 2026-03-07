import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../app_router.dart';
import 'product_verification_status.dart';

class CookServiceSelectionScreen extends StatefulWidget {
  const CookServiceSelectionScreen({super.key});

  @override
  State<CookServiceSelectionScreen> createState() =>
      _CookServiceSelectionScreenState();
}

class _CookServiceSelectionScreenState
    extends State<CookServiceSelectionScreen> {
  bool _foodCook = false;
  bool _homeProductSeller = false;
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_foodCook && !_homeProductSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid =
          Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'services': {
          'foodCook': _foodCook,
          'homeProductSeller': _homeProductSeller,
        },
      });
      if (!mounted) return;

      // Route to the appropriate verification screen(s).
      // foodCook → cook kitchen verification (verificationStatus)
      // homeProductSeller only → product workplace verification
      // Both → cook verification first; product verification is available from dashboard
      if (_foodCook) {
        // Cook verification is mandatory; product verification can follow from dashboard
        Navigator.pushReplacementNamed(context, AppRouter.verificationStatus);
      } else {
        // Only product seller → go straight to product verification status
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ProductVerificationStatusScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC8019).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('👨‍🍳', style: TextStyle(fontSize: 36)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Select Your Services',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Choose what you want to offer on Home Harvest',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Option: Food Cook
              _ServiceOptionCard(
                emoji: '🍱',
                title: 'Home Food Cook',
                subtitle:
                    'Cook & deliver fresh home meals.\nOrders, tiffin, and on-demand food.',
                selected: _foodCook,
                onTap: () => setState(() => _foodCook = !_foodCook),
              ),
              const SizedBox(height: 16),

              // Option: Home Product Seller
              _ServiceOptionCard(
                emoji: '🫙',
                title: 'Homemade Product Seller',
                subtitle:
                    'Sell pickles, masalas, snacks, sweets\nand other homemade products.',
                selected: _homeProductSeller,
                onTap: () =>
                    setState(() => _homeProductSeller = !_homeProductSeller),
              ),

              const SizedBox(height: 12),

              // Both shortcut
              if (_foodCook && _homeProductSeller)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✅ You selected Both services',
                      style: TextStyle(
                        color: Color(0xFF27AE60),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC8019),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceOptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFC8019).withOpacity(0.08)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFC8019) : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? const Color(0xFFFC8019)
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color:
                    selected ? const Color(0xFFFC8019) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFC8019)
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
