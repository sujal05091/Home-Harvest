import 'package:flutter/material.dart';

class LegalPoliciesScreen extends StatelessWidget {
  const LegalPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Legal and Policies',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Terms and Conditions
            _buildLegalSection(
              title: 'Terms and Conditions',
              content:
                  'By using the HomeHarvest application, you agree to follow all terms and conditions mentioned here. HomeHarvest acts as a platform connecting home cooks, customers, and delivery partners. We do not directly prepare food but ensure transparency, safety, and service quality.',
            ),
            const SizedBox(height: 28),

            // Section 2: Service Usage & Responsibilities
            _buildLegalSection(
              title: 'Service Usage & Responsibilities',
              content:
                  'Users are responsible for providing accurate information while placing orders. Home cooks must ensure hygiene, food quality, and lawful preparation. Customers must use the platform responsibly and avoid misuse or fraudulent activities.',
            ),
            const SizedBox(height: 28),

            // Section 3: Payments, Refunds & Cancellations
            _buildLegalSection(
              title: 'Payments, Refunds, and Cancellations',
              content:
                  'All payments are processed securely through supported payment methods. Refunds, if applicable, are initiated as per HomeHarvest refund policy. Cancellations may not be allowed once food preparation has started.',
            ),
            const SizedBox(height: 28),

            // Section 4: Safety, Legal Compliance & Police Cooperation
            _buildLegalSection(
              title: 'Safety, Legal Compliance, and Law Enforcement',
              content:
                  'HomeHarvest strictly follows Indian laws and regulations. Any misuse, illegal activity, harassment, fraud, or safety threat will be reported to concerned authorities. We fully cooperate with police and legal authorities when required by law.',
            ),
            const SizedBox(height: 28),

            // Section 5: Limitation of Liability
            _buildLegalSection(
              title: 'Limitation of Liability',
              content:
                  'HomeHarvest is not responsible for delays caused by weather, traffic, or unforeseen events. We are not liable for personal disputes between users, cooks, or delivery partners. Our responsibility is limited to providing platform-level support and coordination.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection({
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey[700],
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
