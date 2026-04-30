import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/wallet_controller.dart';
import '../../../core/utils/app_theme_system.dart';
import '../widgets/withdrawal_bottom_sheet.dart';
import '../widgets/recharge_bottom_sheet.dart';
import '../widgets/quick_confirm_code_dialog.dart';

class WalletView extends GetView<WalletController> {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppThemeSystem.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage.value,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppThemeSystem.getSecondaryTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => controller.loadWallet(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.primaryColor,
                        foregroundColor: AppThemeSystem.whiteColor,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Carte bancaire style VISA/ASSO
                _buildAssoCard(context),

                const SizedBox(height: 24),

                // Actions rapides
                _buildQuickActions(context),

                const SizedBox(height: 24),

                // Fonds en attente DIASPO EXPRESS - only if has locked diaspo bookings OR diaspo locked funds
                // Ne pas afficher pour les autres types de locks (commandes, abonnements, etc.)
                Obx(() {
                  final hasLockedDiaspo = controller.lockedBookings.isNotEmpty;

                  if (hasLockedDiaspo) {
                    return Column(
                      children: [
                        _buildLockedFundsSection(context),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Soldes par méthode de paiement
                _buildBalancesByProvider(context),

                const SizedBox(height: 100), // Espace pour le bottom nav
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Carte bancaire ASSO (style VISA)
  Widget _buildAssoCard(BuildContext context) {
    // Utiliser LayoutBuilder pour un design responsive
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = AppThemeSystem.getDeviceType(context);

        // Calcul responsive de la hauteur de la carte
        double cardHeight;
        double horizontalMargin;
        double cardPadding;
        double logoFontSize;
        double balanceFontSize;
        double cardNumberFontSize;

        switch (deviceType) {
          case DeviceType.mobile:
            cardHeight = 200;
            horizontalMargin = 20;
            cardPadding = 20;
            logoFontSize = 20;
            balanceFontSize = 28;
            cardNumberFontSize = 16;
            break;
          case DeviceType.tablet:
            cardHeight = 240;
            horizontalMargin = 32;
            cardPadding = 28;
            logoFontSize = 24;
            balanceFontSize = 36;
            cardNumberFontSize = 18;
            break;
          case DeviceType.largeTablet:
            cardHeight = 260;
            horizontalMargin = 40;
            cardPadding = 32;
            logoFontSize = 26;
            balanceFontSize = 40;
            cardNumberFontSize = 20;
            break;
          default:
            cardHeight = 280;
            horizontalMargin = 48;
            cardPadding = 36;
            logoFontSize = 28;
            balanceFontSize = 44;
            cardNumberFontSize = 22;
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          height: cardHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1e3c72), // Bleu foncé
                Color(0xFF2a5298), // Bleu moyen
                Color(0xFF7e22ce), // Violet
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Motif de fond (cercles décoratifs)
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Contenu de la carte
              Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header avec logo ASSO et type de carte
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo ASSO
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: logoFontSize * 0.6,
                            vertical: logoFontSize * 0.3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ASSO',
                            style: TextStyle(
                              fontSize: logoFontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1e3c72),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        // Puce EMV (chip de carte)
                        _buildEMVChip(cardHeight),
                      ],
                    ),

                    // Numéro de carte (masqué style VISA)
                    _buildCardNumber(context, cardNumberFontSize),

                    // Footer: Solde + Holder
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Solde disponible
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Solde',
                                style: TextStyle(
                                  fontSize: balanceFontSize * 0.35,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              SizedBox(height: balanceFontSize * 0.1),
                              // Utiliser Builder au lieu de Obx pour éviter l'erreur
                              Builder(
                                builder: (context) {
                                  // Lire la valeur réactive ici
                                  final balance = controller.formattedBalance;
                                  return Text(
                                    balance,
                                    style: TextStyle(
                                      fontSize: balanceFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Type de carte (WALLET badge)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: cardNumberFontSize * 0.5,
                            vertical: cardNumberFontSize * 0.25,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'WALLET',
                            style: TextStyle(
                              fontSize: cardNumberFontSize * 0.55,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Puce EMV (chip de carte bancaire)
  Widget _buildEMVChip(double cardHeight) {
    final chipSize = cardHeight * 0.25; // 25% de la hauteur de la carte

    return Container(
      width: chipSize * 1.3,
      height: chipSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD4AF37), // Or
            const Color(0xFFFFD700), // Or clair
            const Color(0xFFB8860B), // Or foncé
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lignes horizontales de la puce
          Positioned(
            top: chipSize * 0.2,
            left: chipSize * 0.15,
            right: chipSize * 0.15,
            child: Container(
              height: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            top: chipSize * 0.4,
            left: chipSize * 0.15,
            right: chipSize * 0.15,
            child: Container(
              height: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            top: chipSize * 0.6,
            left: chipSize * 0.15,
            right: chipSize * 0.15,
            child: Container(
              height: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            top: chipSize * 0.8,
            left: chipSize * 0.15,
            right: chipSize * 0.15,
            child: Container(
              height: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          // Lignes verticales
          Positioned(
            left: chipSize * 0.3,
            top: chipSize * 0.15,
            bottom: chipSize * 0.15,
            child: Container(
              width: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            left: chipSize * 0.5,
            top: chipSize * 0.15,
            bottom: chipSize * 0.15,
            child: Container(
              width: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            left: chipSize * 0.7,
            top: chipSize * 0.15,
            bottom: chipSize * 0.15,
            child: Container(
              width: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            right: chipSize * 0.15,
            top: chipSize * 0.15,
            bottom: chipSize * 0.15,
            child: Container(
              width: 1,
              color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Numéro de carte masqué (style VISA)
  Widget _buildCardNumber(BuildContext context, double fontSize) {
    // Générer un numéro de carte virtuel basé sur le téléphone de l'utilisateur
    String generateCardNumber() {
      final phone = controller.userPhone;
      if (phone == null || phone.isEmpty) {
        return '**** **** **** ****';
      }

      // Utiliser les derniers chiffres du téléphone
      final lastDigits = phone.length >= 4
          ? phone.substring(phone.length - 4)
          : phone.padLeft(4, '0');

      return '**** **** **** $lastDigits';
    }

    return Builder(
      builder: (context) {
        final cardNumber = generateCardNumber();
        return Text(
          cardNumber,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 2,
            fontFamily: 'Courier', // Police monospace pour le numéro
          ),
        );
      },
    );
  }

  /// Actions rapides (Recharger, Retirer, Historique)
  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.add_circle_outline_rounded,
              label: 'Recharger',
              color: AppThemeSystem.successColor,
              onTap: () async {
                await RechargeBottomSheet.show(context);
                controller.refresh();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.arrow_circle_up_outlined,
              label: 'Retirer',
              color: AppThemeSystem.warningColor,
              onTap: () => _showWithdrawalOptions(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => _buildActionButton(
                context: context,
                icon: Icons.history_rounded,
                label: 'Historique',
                color: AppThemeSystem.infoColor,
                onTap: () => Get.toNamed('/wallet/history'),
                badgeCount: controller.pendingTransactionsCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 28),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeSystem.whiteColor,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: AppThemeSystem.whiteColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Soldes par provider (Mobile Money et Bank Cards)
  /// Section des fonds bloqués en escrow (DIASPO UNIQUEMENT)
  Widget _buildLockedFundsSection(BuildContext context) {
    return Obx(() {
      final bookings = controller.lockedBookings;

      // Calculer le total des fonds bloqués pour les diaspo uniquement
      final lockedBalance = bookings.fold<double>(
        0.0,
        (sum, booking) => sum + (booking['subtotal'] as double),
      );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Fonds en Attente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppThemeSystem.getPrimaryTextColor(context),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.formatPrice(lockedBalance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Affichage horizontal scrollable des bookings
            if (bookings.isEmpty)
              // Si pas de bookings détaillés, afficher une card générique
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade50,
                      Colors.amber.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vous avez des fonds bloqués qui seront débloqués après confirmation de livraison',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showEnterCodeForUnlock(context),
                        icon: const Icon(Icons.lock_open, size: 20),
                        label: const Text('Débloquer avec code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.primaryColor,
                          foregroundColor: AppThemeSystem.whiteColor,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Afficher les bookings individuellement avec scroll horizontal
              SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _buildLockedBookingCard(context, booking);
                  },
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Card individuelle pour un booking avec fonds bloqués
  Widget _buildLockedBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final subtotal = booking['subtotal'] as double;
    final kgBooked = booking['kg_booked'] as double;
    final buyerName = booking['buyer_name'] ?? 'Client';

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.amber.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔒',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${kgBooked.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  controller.formatPrice(subtotal),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEnterCodeForUnlock(context),
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text(
                'Débloquer',
                style: TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: AppThemeSystem.whiteColor,
                minimumSize: const Size(double.infinity, 38),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnterCodeForUnlock(BuildContext context) {
    // Show dialog to enter code directly
    Get.dialog(
      QuickConfirmCodeDialog(
        onSuccess: () {
          // Refresh wallet, balances and transactions after successful unlock
          controller.refresh();
        },
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildBalancesByProvider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soldes par Méthode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
          ),
          const SizedBox(height: 16),

          // Mobile Money (Orange Money + MTN MoMo)
          Obx(() {
            final balance = controller.wallet.value?.freemopayBalance ?? 0.0;
            return _buildProviderCard(
              context: context,
              iconData: Icons.phone_android_rounded,
              emoji: '📱',
              title: 'Mobile Money',
              subtitle: 'Orange Money & MTN MoMo',
              balance: balance,
              color: AppThemeSystem.freemopayColor,
            );
          }),

          const SizedBox(height: 12),

          // Bank Cards (VISA, MasterCard, PayPal)
          Obx(() {
            final balance = controller.wallet.value?.paypalBalance ?? 0.0;
            return _buildProviderCard(
              context: context,
              iconData: Icons.credit_card_rounded,
              emoji: '💳',
              title: 'Cartes Bancaires',
              subtitle: 'VISA, MasterCard, PayPal',
              balance: balance,
              color: AppThemeSystem.paypalColor,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required BuildContext context,
    required IconData iconData,
    required String emoji,
    required String title,
    required String subtitle,
    required double balance,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeSystem.getBorderColor(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône avec emoji
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconData,
                  color: color,
                  size: 24,
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppThemeSystem.getPrimaryTextColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                controller.formatPrice(balance),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppThemeSystem.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Affiche les options de retrait
  void _showWithdrawalOptions(BuildContext context) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getBackgroundColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                'Choisir une méthode de retrait',
                style: TextStyle(
                  fontSize: AppThemeSystem.getFontSize(context, FontSizeType.h4),
                  fontWeight: FontWeight.bold,
                  color: AppThemeSystem.getPrimaryTextColor(context),
                ),
              ),
              SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

              // Mobile Money Option
              _buildWithdrawalOption(
                context: context,
                iconData: Icons.phone_android_rounded,
                emoji: '📱',
                title: 'Mobile Money',
                subtitle: 'Orange Money & MTN MoMo',
                balance: controller.wallet.value?.freemopayBalance ?? 0.0,
                color: AppThemeSystem.freemopayColor,
                onTap: () async {
                  Get.back();
                  final result = await WithdrawalBottomSheet.show(
                    provider: 'freemopay',
                    availableBalance: controller.wallet.value?.freemopayBalance ?? 0.0,
                  );
                  if (result == true) {
                    controller.refresh();
                  }
                },
              ),

              SizedBox(height: AppThemeSystem.getElementSpacing(context)),

              // Bank Cards Option
              _buildWithdrawalOption(
                context: context,
                iconData: Icons.credit_card_rounded,
                emoji: '💳',
                title: 'Cartes Bancaires',
                subtitle: 'VISA, MasterCard, PayPal',
                balance: controller.wallet.value?.paypalBalance ?? 0.0,
                color: AppThemeSystem.paypalColor,
                onTap: () async {
                  Get.back();
                  final result = await WithdrawalBottomSheet.show(
                    provider: 'paypal',
                    availableBalance: controller.wallet.value?.paypalBalance ?? 0.0,
                  );
                  if (result == true) {
                    controller.refresh();
                  }
                },
              ),

              SizedBox(height: AppThemeSystem.getElementSpacing(context)),
            ],
          ),
        ),
      ),
      isDismissible: true,
      enableDrag: true,
    );
  }

  /// Option de retrait
  Widget _buildWithdrawalOption({
    required BuildContext context,
    required IconData iconData,
    required String emoji,
    required String title,
    required String subtitle,
    required double balance,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppThemeSystem.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icône avec emoji
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
                    color: color,
                    size: 24,
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.formatPrice(balance)} disponible',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppThemeSystem.getSecondaryTextColor(context),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
