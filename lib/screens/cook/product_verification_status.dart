import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/verification_model.dart';
import '../../theme.dart';
import 'product_verification_form.dart';

/// ?? Product Seller Verification Status Screen.
///
/// Shown to:
///   1. New registrants who chose homeProductSeller (or both) during signup.
///   2. Existing cooks who tap "Start Selling Products" from the dashboard.
///
/// If no verification exists ? shows the form directly.
/// If PENDING ? shows waiting message.
/// If APPROVED ? shows success + "Manage Products" button.
/// If REJECTED ? shows reason + option to resubmit.
class ProductVerificationStatusScreen extends StatefulWidget {
  const ProductVerificationStatusScreen({super.key});

  @override
  State<ProductVerificationStatusScreen> createState() =>
      _ProductVerificationStatusScreenState();
}

class _ProductVerificationStatusScreenState
    extends State<ProductVerificationStatusScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Seller Verification'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ProductVerificationModel?>(
        stream: _firestoreService.getProductVerification(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _buildError(snap.error.toString());
          }

          // No submission yet ? show form inline (push to form screen)
          if (!snap.hasData || snap.data == null) {
            return _buildNotSubmitted(context);
          }

          final v = snap.data!;
          switch (v.status) {
            case VerificationStatus.PENDING:
              return _buildPending();
            case VerificationStatus.APPROVED:
              return _buildApproved(context);
            case VerificationStatus.REJECTED:
              return _buildRejected(context, v);
          }
        },
      ),
    );
  }

  // --- States ------------------------------------------------------------

  Widget _buildNotSubmitted(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          // -- TOP BANNER � "Verification Required" ----------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFC8019), Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text('??', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  'Verification Required',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To sell homemade products on Home Harvest,\n'
                  'verify your workplace with admin.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),

          // -- STEPS -------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What you need to submit:',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                _buildStep('1', 'Workplace name & full address'),
                _buildStep('2', 'Photos of your preparation area (min 1)'),
                _buildStep('3', 'Short video of your workplace (recommended)'),
                _buildStep('4', 'List of products you sell'),
                _buildStep('5', 'Ingredients used in your products'),
                _buildStep('6', 'Years of experience'),
                _buildStep('7', 'FSSAI certificate number (recommended)'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin reviews and approves in 24�48 hours. '  
                          'You cannot list products until approved.',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ProductVerificationFormScreen()),
                      );
                    },
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Apply for Verification'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),
        const Icon(Icons.access_time, size: 72, color: Colors.orange),
        const SizedBox(height: 16),
        Text('Verification Pending',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800])),
        const SizedBox(height: 12),
        Card(
          color: Colors.orange[50],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '� Our admin team is reviewing your submission\n'
              '� You will receive a notification once reviewed\n'
              '� Average review time: 24�48 hours\n'
              '� You cannot list products until approved',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.6),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildApproved(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),
        const Icon(Icons.verified, size: 72, color: Colors.green),
        const SizedBox(height: 16),
        Text('You are Approved! ??',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green[700])),
        const SizedBox(height: 12),
        Text(
          'You can now list and manage your homemade products.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.store),
            label: const Text('Go to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildRejected(
      BuildContext context, ProductVerificationModel v) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),
        const Icon(Icons.cancel, size: 72, color: Colors.red),
        const SizedBox(height: 16),
        Text('Verification Rejected',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red[700])),
        const SizedBox(height: 12),
        if (v.rejectionReason != null)
          Card(
            color: Colors.red[50],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Feedback:',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800])),
                    const SizedBox(height: 6),
                    Text(v.rejectionReason!,
                        style: GoogleFonts.poppins(fontSize: 13)),
                  ]),
            ),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProductVerificationFormScreen()),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Resubmit Verification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildError(String err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $err'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                color: Color(0xFFFC8019), shape: BoxShape.circle),
            child: Center(
              child: Text(num,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
