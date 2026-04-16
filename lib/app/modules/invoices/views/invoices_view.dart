import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/invoice_model.dart';
import '../controllers/invoices_controller.dart';

class InvoicesView extends GetView<InvoicesController> {
  const InvoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.primaryTextColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Mes Factures',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(context),

          // Invoices list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.invoices.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.invoices.isEmpty) {
                return _buildEmptyState(context);
              }

              return RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.builder(
                  padding: EdgeInsets.all(context.horizontalPadding),
                  itemCount: controller.invoices.length +
                      (controller.isLoadingMore.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == controller.invoices.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final invoice = controller.invoices[index];

                    // Load more when reaching the end
                    if (index == controller.invoices.length - 3) {
                      Future.microtask(() => controller.loadMore());
                    }

                    return _buildInvoiceCard(context, invoice);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      child: Row(
        children: controller.types.map((type) {
          return Obx(() {
            final isSelected = controller.selectedType.value == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(controller.getTypeLabel(type)),
                selected: isSelected,
                onSelected: (_) => controller.changeType(type),
                selectedColor: AppThemeSystem.primaryColor,
                backgroundColor: context.surfaceColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : context.primaryTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: context.secondaryTextColor,
          ),
          SizedBox(height: context.elementSpacing),
          Text(
            'Aucune facture',
            style: context.h5.copyWith(
              color: context.primaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing * 0.5),
          Text(
            'Vous n\'avez pas encore de factures',
            style: context.body2.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, InvoiceModel invoice) {
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

    return Container(
      margin: EdgeInsets.only(bottom: context.elementSpacing),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (invoice.pdfUrl != null || invoice.downloadUrl != null) {
              controller.downloadInvoice(invoice);
            }
          },
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(invoice.type).withOpacity(0.1),
                        borderRadius: context.borderRadius(BorderRadiusType.small),
                      ),
                      child: Text(
                        invoice.getTypeLabel(),
                        style: context.caption.copyWith(
                          color: _getTypeColor(invoice.type),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Date
                    Text(
                      dateFormat.format(invoice.date),
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.elementSpacing),

                // Invoice number
                Text(
                  invoice.invoiceNumber,
                  style: context.h6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.primaryTextColor,
                  ),
                ),

                SizedBox(height: context.elementSpacing * 0.5),

                // Description
                Text(
                  invoice.description,
                  style: context.body2.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: context.elementSpacing),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Amount
                    Text(
                      invoice.getFormattedAmount(),
                      style: context.h5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),

                    // Download button
                    if (invoice.pdfUrl != null || invoice.downloadUrl != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withOpacity(0.1),
                          borderRadius: context.borderRadius(BorderRadiusType.small),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 16,
                              color: AppThemeSystem.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Télécharger',
                              style: context.caption.copyWith(
                                color: AppThemeSystem.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'vendor_package':
        return Colors.purple;
      case 'wallet_recharge':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
