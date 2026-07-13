import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/wallet_controller.dart';
import '../../../data/models/wallet_model.dart';
import '../../../core/utils/app_theme_system.dart';

class WalletHistoryView extends GetView<WalletController> {
  const WalletHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Historique des transactions'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppThemeSystem.primaryColor,
        foregroundColor: AppThemeSystem.whiteColor,
        actions: [
          _buildTypeFilter(context),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadTransactions(),
        child: Obx(() {
          if (controller.isLoadingTransactions.value &&
              controller.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 80,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vos transactions apparaîtront ici',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.transactions.length + 1,
            itemBuilder: (context, index) {
              if (index == controller.transactions.length) {
                // Load more indicator
                if (controller.currentPage.value < controller.lastPage.value) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Obx(
                        () => controller.isLoadingTransactions.value
                            ? const CircularProgressIndicator()
                            : OutlinedButton.icon(
                                onPressed: () =>
                                    controller.loadTransactions(loadMore: true),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Charger plus'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppThemeSystem.primaryColor,
                                  side: const BorderSide(
                                    color: AppThemeSystem.primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                }
                return const SizedBox(height: 80);
              }

              final transaction = controller.transactions[index];
              return _buildTransactionCard(context, transaction, index);
            },
          );
        }),
      ),
    );
  }

  Widget _buildTypeFilter(BuildContext context) {
    return PopupMenuButton<String?>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppThemeSystem.whiteColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.filter_list_rounded,
          color: AppThemeSystem.whiteColor,
          size: 20,
        ),
      ),
      onSelected: (value) => controller.filterByType(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(Icons.all_inclusive_rounded, size: 18),
              SizedBox(width: 12),
              Text('Toutes'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'credit',
          child: Row(
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: AppThemeSystem.successColor,
              ),
              SizedBox(width: 12),
              Text('Recharges'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'debit',
          child: Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 18,
                color: AppThemeSystem.errorColor,
              ),
              SizedBox(width: 12),
              Text('Paiements'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'bonus',
          child: Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                size: 18,
                color: AppThemeSystem.warningColor,
              ),
              SizedBox(width: 12),
              Text('Bonus'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'refund',
          child: Row(
            children: [
              Icon(
                Icons.replay_rounded,
                size: 18,
                color: AppThemeSystem.infoColor,
              ),
              SizedBox(width: 12),
              Text('Remboursements'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    WalletTransactionModel transaction,
    int index,
  ) {
    Color statusColor;
    switch (transaction.status) {
      case 'completed':
        statusColor = AppThemeSystem.successColor;
        break;
      case 'pending':
        statusColor = AppThemeSystem.warningColor;
        break;
      case 'failed':
        statusColor = AppThemeSystem.errorColor;
        break;
      default:
        statusColor = AppThemeSystem.infoColor;
    }

    final isCredit = transaction.isCredit;
    final amountColor = isCredit
        ? AppThemeSystem.successColor
        : AppThemeSystem.errorColor;

    return Container(
      margin: EdgeInsets.only(bottom: index == controller.transactions.length - 1 ? 0 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeSystem.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: amountColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transaction.typeIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          transaction.typeLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        ),
                        Text(
                          transaction.formattedAmount,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemeSystem.getSecondaryTextColor(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppThemeSystem.getSecondaryTextColor(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(transaction.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppThemeSystem.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            transaction.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (transaction.paymentProvider != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.infoColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  transaction.paymentProvider == 'kpay'
                                      ? '📱'
                                      : '💳',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  transaction.paymentProvider == 'kpay'
                                      ? 'KPay'
                                      : 'PayPal',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppThemeSystem.infoColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} jours';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}
