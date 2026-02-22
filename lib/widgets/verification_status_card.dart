import 'package:flutter/material.dart';
import '../../models/verification_model.dart';
import '../theme.dart';

/// ✅ Verification Status Card Widget
/// Shows current verification status with appropriate styling
class VerificationStatusCard extends StatelessWidget {
  final VerificationModel verification;
  final VoidCallback? onResubmit;

  const VerificationStatusCard({
    super.key,
    required this.verification,
    this.onResubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Icon
            _buildStatusIcon(),
            const SizedBox(height: 16),
            
            // Status Badge
            _buildStatusBadge(),
            const SizedBox(height: 16),
            
            // Status Message
            _buildStatusMessage(),
            
            // Admin Notes (if any)
            if (verification.adminNotes != null) ...[
              const SizedBox(height: 20),
              _buildAdminNotes(),
            ],
            
            // Rejection Reason (if rejected)
            if (verification.status == VerificationStatus.REJECTED && 
                verification.rejectionReason != null) ...[
              const SizedBox(height: 12),
              _buildRejectionReason(),
            ],
            
            // Timestamps
            const SizedBox(height: 20),
            _buildTimestamps(),
            
            // Resubmit button (if rejected)
            if (verification.status == VerificationStatus.REJECTED && onResubmit != null) ...[
              const SizedBox(height: 20),
              _buildResubmitButton(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;
    
    switch (verification.status) {
      case VerificationStatus.APPROVED:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case VerificationStatus.REJECTED:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case VerificationStatus.PENDING:
      default:
        icon = Icons.pending;
        color = Colors.orange;
    }
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 60, color: color),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    String statusText;
    
    switch (verification.status) {
      case VerificationStatus.APPROVED:
        badgeColor = Colors.green;
        statusText = '✓ APPROVED';
        break;
      case VerificationStatus.REJECTED:
        badgeColor = Colors.red;
        statusText = '✕ REJECTED';
        break;
      case VerificationStatus.PENDING:
      default:
        badgeColor = Colors.orange;
        statusText = '⏳ PENDING REVIEW';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    String message;
    Color messageColor;
    
    switch (verification.status) {
      case VerificationStatus.APPROVED:
        message = 'Congratulations! You can now start adding dishes and receive orders.';
        messageColor = Colors.green[700]!;
        break;
      case VerificationStatus.REJECTED:
        message = 'Your verification was not approved. Please review the feedback and resubmit.';
        messageColor = Colors.red[700]!;
        break;
      case VerificationStatus.PENDING:
      default:
        message = 'Your verification is under review by our admin team. This usually takes 24-48 hours.';
        messageColor = Colors.grey[700]!;
    }
    
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: messageColor,
        height: 1.5,
      ),
    );
  }

  Widget _buildAdminNotes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.note_alt, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Admin Notes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verification.adminNotes!,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionReason() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Rejection Reason',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verification.rejectionReason!,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamps() {
    return Column(
      children: [
        _buildTimestampRow(
          'Submitted',
          verification.createdAt,
          Icons.upload_file,
        ),
        if (verification.reviewedAt != null) ...[
          const SizedBox(height: 8),
          _buildTimestampRow(
            'Reviewed',
            verification.reviewedAt!,
            Icons.check_circle_outline,
          ),
        ],
      ],
    );
  }

  Widget _buildTimestampRow(String label, DateTime timestamp, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _formatDate(timestamp),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildResubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onResubmit,
        icon: const Icon(Icons.refresh),
        label: const Text('Resubmit Verification'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          padding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
