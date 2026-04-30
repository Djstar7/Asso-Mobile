import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/providers/currency_service.dart';

class PaymentMethodBottomSheet extends StatelessWidget {
  final WalletModel wallet;
  final double totalAmount;
  final VoidCallback onFreemopaySelected;
  final VoidCallback onPaypalSelected;

  const PaymentMethodBottomSheet({
    super.key,
    required this.wallet,
    required this.totalAmount,
    required this.onFreemopaySelected,
    required this.onPaypalSelected,
  });

  @override
  Widget build(BuildContext context) {
    final freemopayAvailable = wallet.freemopayBalance;
    final paypalAvailable = wallet.paypalBalance;
    final canPayWithFreemopay = freemopayAvailable >= totalAmount;
    final canPayWithPaypal = paypalAvailable >= totalAmount;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: AppThemeSystem.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choisir une méthode de paiement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Montant à payer: ${_formatAmount(totalAmount)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Mobile Money Option
              _buildPaymentOption(
                context: context,
                icon: Icons.phone_android_rounded,
                emoji: '📱',
                title: 'Mobile Money',
                subtitle: 'Orange Money & MTN MoMo',
                balance: freemopayAvailable,
                canPay: canPayWithFreemopay,
                color: AppThemeSystem.freemopayColor,
                onTap: canPayWithFreemopay ? onFreemopaySelected : null,
              ),

              const SizedBox(height: 16),

              // PayPal / Bank Cards Option
              _buildPaymentOption(
                context: context,
                icon: Icons.credit_card_rounded,
                emoji: '💳',
                title: 'Cartes Bancaires',
                subtitle: 'VISA, MasterCard, PayPal',
                balance: paypalAvailable,
                canPay: canPayWithPaypal,
                color: AppThemeSystem.paypalColor,
                onTap: canPayWithPaypal ? onPaypalSelected : null,
              ),

              const SizedBox(height: 20),

              // Help text
              if (!canPayWithFreemopay && !canPayWithPaypal)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Solde insuffisant. Veuillez recharger votre wallet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Les fonds seront bloqués jusqu\'à la confirmation de livraison par le code secret.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
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

  Widget _buildPaymentOption({
    required BuildContext context,
    required IconData icon,
    required String emoji,
    required String title,
    required String subtitle,
    required double balance,
    required bool canPay,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: canPay
              ? AppThemeSystem.getSurfaceColor(context)
              : AppThemeSystem.getSurfaceColor(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canPay
                ? color.withValues(alpha: 0.3)
                : AppThemeSystem.getBorderColor(context),
            width: canPay ? 2 : 1,
          ),
          boxShadow: canPay
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon with emoji
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: canPay
                        ? color.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: canPay ? color : Colors.grey.shade500,
                    size: 28,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: canPay
                          ? AppThemeSystem.getPrimaryTextColor(context)
                          : AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Solde: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppThemeSystem.getSecondaryTextColor(context),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _formatAmount(balance),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: canPay ? color : Colors.red.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status indicator
            if (canPay)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: color,
                  size: 24,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block,
                  color: Colors.grey.shade500,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${amount.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(amount, showSymbol: true);
  }
}
