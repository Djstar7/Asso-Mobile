import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/wallet_controller.dart';
import '../../../core/utils/app_theme_system.dart';
import '../widgets/withdrawal_bottom_sheet.dart';
import '../widgets/quick_confirm_code_dialog.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../../data/models/payment_method_option.dart';

class WalletView extends GetView<WalletController> {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      // SafeArea: pas d'AppBar ici, on ajoute le padding de la status bar
      // pour que le contenu ne colle pas sous l'encoche.
      body: SafeArea(
        child: RefreshIndicator(
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

  /// Actions rapides (Retirer, Historique)
  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
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

          // KPay (Mobile Money multi-opérateurs)
          Obx(() {
            final balance = controller.wallet.value?.kpayBalance ?? 0.0;
            return _buildProviderCard(
              context: context,
              iconData: Icons.phone_android_rounded,
              emoji: '📱',
              title: 'KPay',
              subtitle: 'MTN, Orange, Moov, Airtel, M-Pesa…',
              balance: balance,
              color: AppThemeSystem.kpayColor,
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

          const SizedBox(height: 12),

          // Virement bancaire (IBAN) : le montant est exprimé dans la devise du
          // compte bancaire, pas en FCFA — il vient de la conversion du portefeuille.
          Obx(() {
            final status = controller.stripeWithdrawStatus.value;
            final last4 = controller.stripeIbanLast4.value;
            final currency = controller.stripeWithdrawCurrency.value;
            final available = controller.stripeWithdrawAvailable.value;

            final subtitle = switch (status) {
              'approved' => last4 != null ? 'IBAN ••••$last4' : 'Vers votre compte bancaire',
              'pending' => 'IBAN en cours de vérification',
              'rejected' => 'IBAN refusé — à renvoyer',
              _ => 'Aucun IBAN enregistré',
            };

            return _buildProviderCard(
              context: context,
              iconData: Icons.account_balance_rounded,
              emoji: '🏦',
              title: 'Virement bancaire (IBAN)',
              subtitle: subtitle,
              balance: available,
              color: AppThemeSystem.bankColor,
              // Montant déjà exprimé dans la devise du compte bancaire.
              balanceLabel: status == 'approved'
                  ? '${available.toStringAsFixed(2)} $currency'
                  : '—',
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
    String? balanceLabel,
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
                // `formatPrice` convertit depuis le FCFA : un montant déjà exprimé
                // dans une autre devise passe par `balanceLabel`.
                balanceLabel ?? controller.formatPrice(balance),
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
  /// Sélecteur de méthode de retrait — réutilise EXACTEMENT le widget de paiement
  /// (PaymentMethodSelector) avec des options construites depuis les soldes de retrait.
  /// Les trois rails (KPay / Cartes-PayPal / Virement IBAN) sont toujours affichés,
  /// grisés + non cliquables quand indisponibles (aucun solde, ou IBAN non validé).
  void _showWithdrawalOptions(BuildContext context) async {
    final kpayBal = controller.wallet.value?.kpayBalance ?? 0.0;
    final paypalBal = controller.wallet.value?.paypalBalance ?? 0.0;
    final stripeEligible = controller.stripeWithdrawEligible.value;
    final stripeBal = controller.stripeWithdrawAvailable.value;
    final stripeLast4 = controller.stripeIbanLast4.value;
    final stripeCurrency = controller.stripeWithdrawCurrency.value;

    // Un moyen non configuré côté plateforme est grisé (raison affichée au tap),
    // pour éviter que l'utilisateur tente un retrait qui échouerait par une erreur.
    final kpayConfigured = controller.kpayConfigured.value;
    final paypalConfigured = controller.paypalConfigured.value;
    final stripeConfigured = controller.stripeConfigured.value;

    final options = <PaymentMethodOption>[
      PaymentMethodOption(
        code: 'kpay',
        label: 'KPay',
        subtitle: 'MTN, Orange, Moov, Airtel, M-Pesa…',
        flow: 'phone',
        enabled: kpayConfigured,
        available: kpayConfigured && kpayBal > 0,
        minCurrency: 'XAF',
        unavailableReason: (kpayConfigured && kpayBal > 0) ? null : 'disabled',
        hint: !kpayConfigured
            ? 'Momentanément indisponible'
            : (kpayBal > 0
                ? '${controller.formatPrice(kpayBal)} disponible'
                : 'Aucun solde à retirer'),
      ),
      PaymentMethodOption(
        code: 'paypal',
        label: 'Cartes Bancaires',
        subtitle: 'VISA, MasterCard, PayPal',
        flow: 'redirect',
        enabled: paypalConfigured,
        available: paypalConfigured && paypalBal > 0,
        minCurrency: 'XAF',
        unavailableReason: (paypalConfigured && paypalBal > 0) ? null : 'disabled',
        hint: !paypalConfigured
            ? 'Momentanément indisponible'
            : (paypalBal > 0
                ? '${controller.formatPrice(paypalBal)} disponible'
                : 'Aucun solde à retirer'),
      ),
      PaymentMethodOption(
        code: 'stripe',
        label: 'Virement bancaire (IBAN)',
        subtitle: stripeLast4 != null
            ? 'IBAN ••••$stripeLast4'
            : 'Vers votre compte bancaire',
        flow: 'redirect',
        enabled: stripeConfigured,
        available: stripeConfigured && stripeEligible && stripeBal > 0,
        minCurrency: 'EUR',
        unavailableReason:
            (stripeConfigured && stripeEligible && stripeBal > 0) ? null : 'disabled',
        hint: !stripeConfigured
            ? 'Momentanément indisponible'
            : (!stripeEligible
                ? 'IBAN non validé'
                : (stripeBal > 0
                    ? '${stripeBal.toStringAsFixed(2)} $stripeCurrency disponible'
                    : 'Aucun solde à retirer')),
      ),
    ];

    final selected = await PaymentMethodSelector.show(
      amount: kpayBal + paypalBal,
      currency: 'FCFA',
      amountLabel: 'Solde disponible',
      title: 'Choisir une méthode de retrait',
      options: options,
    );
    if (selected == null || !context.mounted) return;

    switch (selected.code) {
      case 'kpay':
        final result = await WithdrawalBottomSheet.show(
          provider: 'kpay',
          availableBalance: kpayBal,
        );
        if (result == true) controller.refresh();
        break;
      case 'paypal':
        final result = await WithdrawalBottomSheet.show(
          provider: 'paypal',
          availableBalance: paypalBal,
        );
        if (result == true) controller.refresh();
        break;
      case 'stripe':
        _showStripeWithdrawalDialog(context);
        break;
    }
  }

  /// Dialogue de retrait par virement bancaire (Stripe Connect).
  ///
  /// Le vendeur saisit un montant dans la devise de SON PORTEFEUILLE (ex. FCFA) ;
  /// la conversion vers la devise de son compte bancaire (ex. EUR) est calculée par
  /// le serveur et affichée en direct sous le champ, avant toute validation.
  void _showStripeWithdrawalDialog(BuildContext context) {
    final amountController = TextEditingController();
    final payoutCurrency = controller.stripeWithdrawCurrency.value;
    final payoutAvailable = controller.stripeWithdrawAvailable.value;
    final last4 = controller.stripeIbanLast4.value;

    // Devise débitée : celle du portefeuille (repli sur la devise du compte
    // bancaire si le serveur n'a pas encore renvoyé le détail).
    final sourceCurrency = controller.stripeSourceCurrency.value ?? payoutCurrency;
    final available = controller.stripeSourceAvailable.value > 0
        ? controller.stripeSourceAvailable.value
        : payoutAvailable;
    final converts = sourceCurrency != payoutCurrency;

    // Formatage explicite : `formatPrice` reconvertirait le montant dans la devise
    // d'affichage de l'app, ce qui fausserait un solde déjà exprimé en devise source.
    String money(double value, String currency) {
      final decimals = (currency == 'XAF' || currency == 'XOF') ? 0 : 2;
      return '${value.toStringAsFixed(decimals)} $currency';
    }

    // Le devis est redemandé au serveur après chaque saisie, pas à chaque frappe.
    Timer? debounce;
    controller.stripeQuoteAmount.value = 0;
    controller.stripeQuoteMessage.value = null;
    amountController.addListener(() {
      debounce?.cancel();
      final amount = double.tryParse(
              amountController.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ??
          0;
      debounce = Timer(const Duration(milliseconds: 450), () {
        controller.quoteStripeWithdrawal(amount);
      });
    });

    Get.dialog(
      AlertDialog(
        backgroundColor: AppThemeSystem.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🏦', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Virement bancaire',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppThemeSystem.getPrimaryTextColor(context),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (last4 != null)
              Text(
                'Vers votre IBAN ••••$last4',
                style: TextStyle(color: AppThemeSystem.getSecondaryTextColor(context)),
              ),
            const SizedBox(height: 4),
            Text(
              converts
                  ? 'Disponible : ${money(available, sourceCurrency)} '
                      '(≈ ${money(payoutAvailable, payoutCurrency)})'
                  : 'Disponible : ${money(available, payoutCurrency)}',
              style: TextStyle(
                color: AppThemeSystem.getSecondaryTextColor(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Montant ($sourceCurrency)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(
                  converts ? Icons.account_balance_wallet_outlined : Icons.euro_rounded,
                ),
              ),
            ),
            // Conversion affichée AVANT validation : le vendeur voit exactement
            // ce qui arrivera sur son compte bancaire.
            if (converts) ...[
              const SizedBox(height: 10),
              Obx(() {
                if (controller.isQuotingStripe.value) {
                  return Row(
                    children: [
                      const SizedBox(
                          height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(
                        'Conversion en cours…',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppThemeSystem.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  );
                }

                final quote = controller.stripeQuoteAmount.value;
                final warning = controller.stripeQuoteMessage.value;

                if (quote <= 0 && warning == null) {
                  return Text(
                    'Saisissez un montant pour voir le total converti.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (quote > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vous recevrez ${money(quote, payoutCurrency)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppThemeSystem.primaryColor,
                              ),
                            ),
                            if (controller.stripeSourceRate.value > 0)
                              Text(
                                '1 $sourceCurrency = '
                                '${controller.stripeSourceRate.value.toStringAsFixed(6)} $payoutCurrency',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppThemeSystem.getSecondaryTextColor(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (warning != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        warning,
                        style: TextStyle(fontSize: 12, color: AppThemeSystem.errorColor),
                      ),
                    ],
                  ],
                );
              }),
            ],
            const SizedBox(height: 8),
            Text(
              'Les fonds arrivent sous 1 à 3 jours ouvrés.',
              style: TextStyle(
                color: AppThemeSystem.getSecondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: controller.isProcessingPayment.value
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text.trim().replaceAll(',', '.')) ?? 0;
                        if (amount <= 0) {
                          Get.snackbar('Montant invalide', 'Saisissez un montant valide',
                              snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        if (amount > available) {
                          Get.snackbar(
                              'Solde insuffisant',
                              'Disponible : ${money(available, converts ? sourceCurrency : payoutCurrency)}',
                              snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        debounce?.cancel();
                        final result = await controller.withdrawStripe(
                          amount: amount,
                          currency: sourceCurrency,
                        );
                        Get.back();
                        Get.snackbar(
                          result['success'] == true ? 'Virement en cours' : 'Erreur',
                          result['message']?.toString() ?? '',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: result['success'] == true
                              ? AppThemeSystem.successColor
                              : AppThemeSystem.errorColor,
                          colorText: Colors.white,
                        );
                      },
                child: controller.isProcessingPayment.value
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Retirer'),
              )),
        ],
      ),
    );
  }
}
