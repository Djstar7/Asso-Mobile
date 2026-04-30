import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/currency_service.dart';
import '../views/invoice_webview.dart';
import '../../vendorDashboard/controllers/vendor_dashboard_controller.dart';
import '../../storeManagement/controllers/store_management_controller.dart';

class PaymentSuccessDialog extends StatefulWidget {
  final String packageName;
  final double amount;
  final String paymentMethod;
  final String? invoiceUrl;

  const PaymentSuccessDialog({
    super.key,
    required this.packageName,
    required this.amount,
    required this.paymentMethod,
    this.invoiceUrl,
  });

  static Future<void> show({
    required String packageName,
    required double amount,
    required String paymentMethod,
    String? invoiceUrl,
  }) {
    return Get.dialog(
      PaymentSuccessDialog(
        packageName: packageName,
        amount: amount,
        paymentMethod: paymentMethod,
        invoiceUrl: invoiceUrl,
      ),
      barrierDismissible: false,
    );
  }

  @override
  State<PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<PaymentSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatPrice(double priceInXOF) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: true);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon with animation
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppThemeSystem.successColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple effect
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Container(
                            width: 100 * value,
                            height: 100 * value,
                            decoration: BoxDecoration(
                              color: AppThemeSystem.successColor
                                  .withValues(alpha: (0.3 * (1 - value))),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                      // Check icon
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppThemeSystem.successColor,
                        size: 64,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Success title
                Text(
                  'Paiement réussi !',
                  style: context.h4.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppThemeSystem.successColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Package info
                Text(
                  'Votre package ${widget.packageName} a été activé avec succès',
                  style: context.body1.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Payment details card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        context,
                        'Package',
                        widget.packageName,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        context,
                        'Montant',
                        _formatPrice(widget.amount),
                        isHighlight: true,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        context,
                        'Méthode',
                        widget.paymentMethod == 'freemopay'
                            ? 'FreeMoPay'
                            : 'PayPal',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        context,
                        'Date',
                        DateFormat('dd MMM yyyy à HH:mm', 'fr_FR')
                            .format(DateTime.now()),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Column(
                  children: [
                    if (widget.invoiceUrl != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Open invoice in WebView
                            Get.to(
                              () => InvoiceWebView(
                                invoiceUrl: widget.invoiceUrl!,
                              ),
                            );
                          },
                          icon: Icon(Icons.receipt_long_rounded),
                          label: Text('Voir la facture'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppThemeSystem.primaryColor,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (widget.invoiceUrl != null) const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close dialog
                          Get.back();

                          // Go back to previous page
                          Get.back();

                          // Wait a moment for navigation animation
                          await Future.delayed(const Duration(milliseconds: 200));

                          // Force refresh the dashboard and store management
                          try {
                            if (Get.isRegistered<VendorDashboardController>()) {
                              final controller = Get.find<VendorDashboardController>();
                              print('[PaymentSuccess] Refreshing VendorDashboard');
                              await controller.refreshData();
                            }

                            if (Get.isRegistered<StoreManagementController>()) {
                              final controller = Get.find<StoreManagementController>();
                              print('[PaymentSuccess] Refreshing StoreManagement');
                              await controller.loadData();
                            }
                          } catch (e) {
                            print('[PaymentSuccess] Error refreshing: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.successColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Voir mon dashboard',
                          style: context.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.body2.copyWith(
            color: context.secondaryTextColor,
          ),
        ),
        Text(
          value,
          style: context.body2.copyWith(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight
                ? AppThemeSystem.primaryColor
                : context.primaryTextColor,
          ),
        ),
      ],
    );
  }
}
