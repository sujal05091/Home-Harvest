import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/verification_model.dart';
import '../../widgets/verification_status_card.dart';
import '../../theme.dart';
import 'cook_verification_form.dart';

/// ✅ Verification Status Screen
/// Shows verification status or form based on submission state
class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cook Verification'),
        backgroundColor: AppTheme.primaryOrange,
      ),
      body: StreamBuilder<VerificationModel?>(
        stream: _firestoreService.getCookVerification(authProvider.currentUser!.uid),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Check if verification exists
          if (snapshot.hasData && snapshot.data != null) {
            final verification = snapshot.data!;
            
            // ✅ Show verification status card
            return SingleChildScrollView(
              child: Column(
                children: [
                  VerificationStatusCard(
                    verification: verification,
                    onResubmit: verification.status == VerificationStatus.REJECTED
                        ? () => _navigateToResubmit(context)
                        : null,
                  ),
                  
                  // Additional info for pending status
                  if (verification.status == VerificationStatus.PENDING) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.access_time, color: Colors.blue, size: 40),
                              const SizedBox(height: 12),
                              const Text(
                                'What happens next?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• Our admin team will review your submission\n'
                                '• You will receive a notification once reviewed\n'
                                '• Average review time: 24-48 hours\n'
                                '• You cannot add dishes until approved',
                                style: const TextStyle(fontSize: 13, height: 1.6),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Additional info for approved status
                  if (verification.status == VerificationStatus.APPROVED) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.celebration, color: Colors.green, size: 40),
                              const SizedBox(height: 12),
                              const Text(
                                'You\'re all set!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'You can now:\n'
                                '• Add your delicious dishes\n'
                                '• Receive orders from customers\n'
                                '• Manage your cook profile',
                                style: TextStyle(fontSize: 13, height: 1.6),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.restaurant_menu),
                                  label: const Text('Go to Dashboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryOrange,
                                    padding: const EdgeInsets.all(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          // ✅ No verification exists - show form button
          return _buildNoVerificationState(context);
        },
      ),
    );
  }

  /// No verification submitted yet
  Widget _buildNoVerificationState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user,
                size: 60,
                color: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Get Verified to Start Cooking!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete your cook verification to start\nadding dishes and receiving orders',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToForm(context),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Start Verification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, color: AppTheme.primaryOrange),
                        const SizedBox(width: 8),
                        const Text(
                          'What you\'ll need:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRequirementItem('Kitchen photos (multiple)'),
                    _buildRequirementItem('Kitchen video (optional, max 60s)'),
                    _buildRequirementItem('List of ingredients you use'),
                    _buildRequirementItem('Your experience & specialities'),
                    _buildRequirementItem('Kitchen name & address'),
                    _buildRequirementItem('FSSAI certificate (optional)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _navigateToForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CookVerificationFormScreen(),
      ),
    );
  }

  void _navigateToResubmit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CookVerificationFormScreen(),
      ),
    );
  }
}
