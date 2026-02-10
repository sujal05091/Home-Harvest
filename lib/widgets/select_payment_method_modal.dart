import 'package:flutter/material.dart';

/// Model class for payment method data
class PaymentMethod {
  final String id;
  final String name;
  final String accountDetails;
  final IconData icon;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.accountDetails,
    required this.icon,
  });
}

/// Modal for selecting payment method
class SelectPaymentMethodModal extends StatefulWidget {
  final String? initialSelectedId;
  final List<PaymentMethod> paymentMethods;
  final Function(String? selectedId)? onApply;
  final VoidCallback? onAddPaymentMethod;

  const SelectPaymentMethodModal({
    Key? key,
    this.initialSelectedId,
    this.paymentMethods = const [],
    this.onApply,
    this.onAddPaymentMethod,
  }) : super(key: key);

  /// Static method to show the modal
  static Future<String?> show(
    BuildContext context, {
    String? initialSelectedId,
    List<PaymentMethod>? paymentMethods,
    Function(String? selectedId)? onApply,
    VoidCallback? onAddPaymentMethod,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectPaymentMethodModal(
        initialSelectedId: initialSelectedId,
        paymentMethods: paymentMethods ?? _getDefaultPaymentMethods(),
        onApply: onApply,
        onAddPaymentMethod: onAddPaymentMethod,
      ),
    );
  }

  /// Default payment methods for demo
  static List<PaymentMethod> _getDefaultPaymentMethods() {
    return [
      PaymentMethod(
        id: 'paypal',
        name: 'PayPal',
        accountDetails: 'user****@mail.com',
        icon: Icons.paypal_sharp,
      ),
      PaymentMethod(
        id: 'card',
        name: 'Credit Card',
        accountDetails: '**** **** **** 1234',
        icon: Icons.credit_card,
      ),
      PaymentMethod(
        id: 'upi',
        name: 'UPI',
        accountDetails: 'user@upi',
        icon: Icons.account_balance_wallet,
      ),
    ];
  }

  @override
  State<SelectPaymentMethodModal> createState() =>
      _SelectPaymentMethodModalState();
}

class _SelectPaymentMethodModalState extends State<SelectPaymentMethodModal> {
  String? _selectedPaymentId;

  @override
  void initState() {
    super.initState();
    _selectedPaymentId = widget.initialSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Payment methods list
            ...widget.paymentMethods.map((method) {
              final isSelected = _selectedPaymentId == method.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                child: _buildPaymentMethodCard(
                  icon: method.icon,
                  name: method.name,
                  accountDetails: method.accountDetails,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedPaymentId = method.id;
                    });
                  },
                ),
              );
            }).toList(),

            // Add Payment Method card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: widget.onAddPaymentMethod,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Add Payment Method',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Apply button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.onApply != null) {
                      widget.onApply!(_selectedPaymentId);
                    }
                    Navigator.pop(context, _selectedPaymentId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC8019),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Apply the payment method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String name,
    required String accountDetails,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFC8019) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accountDetails,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Checkbox
              Theme(
                data: ThemeData(
                  checkboxTheme: CheckboxThemeData(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) => onTap(),
                  activeColor: const Color(0xFFFC8019),
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: Colors.grey[400]!,
                    width: 2,
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
