import 'package:asso/app/core/utils/app_feedback.dart';
  import 'dart:async';
  import 'package:asso/app/core/utils/auth_guard.dart';
import 'package:flutter/material.dart';
  import 'package:get/get.dart';

  import '../controllers/wallet_controller.dart';
  import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
  import '../widgets/withdrawal_bottom_sheet.dart';
  import '../widgets/recharge_bottom_sheet.dart';
  import '../widgets/payout_account_sheet.dart';
  import '../../../core/values/kpay_catalog.dart';
  import '../widgets/quick_confirm_code_dialog.dart';
  import '../widgets/confirm_code_parts.dart';
  import '../../payment/widgets/payment_method_selector.dart';
  import '../../../data/models/payment_method_option.dart';
  import '../../immo/views/immo_reservation_view.dart';
  import '../../immo/widgets/immo_widgets.dart';


  class WalletView extends GetView<WalletController> {
    const WalletView({super.key});

    @override
   Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppThemeSystem.getBackgroundColor(context),
    // En-tête fixe plutôt que dans le contenu : pendant le chargement ou
    // après une erreur, l'écran n'avait aucune sortie visible.
    appBar: AppBar(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      leading: const AppBackButton(),
      title: Text('wallet.title'.tr),
    ),
    body: SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
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
                          child: Text('wallet.retry'.tr),
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
                    const SizedBox(height: 8),

                    // Carte bancaire style VISA/ASSO
                    _buildAssoCard(context),

                    //Bannière IBAN (vendeur uniquement, absent ou refusé)
                    _buildIbanSyncBanner(context),

                    const SizedBox(height: 24),

                    // Actions rapides
                    _buildQuickActions(context),

                    const SizedBox(height: 24),

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

                    Obx(() => controller.lockedRealEstate.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildLockedRealEstateSection(context),
                          )),

                    _buildBalancesByProvider(context),

                    const SizedBox(height: 24),

                    // Où l'argent est versé lors d'un retrait
                    _buildPayoutAccountSection(context),

                    const SizedBox(height: 100),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );
}
    /// Bannière "chaude" invitant le vendeur à synchroniser son IBAN
    /// (compte de virement Stripe Connect) tant qu'il n'est pas approuvé.
    Widget _buildIbanSyncBanner(BuildContext context) {
      return Obx(() {
        // Vendeur ET acheteur : l'IBAN sert aux retraits et aux remboursements
        // de litige virés par ASSO. Seul un invité n'a rien à synchroniser.
        final status = controller.stripeWithdrawStatus.value; // null|pending|approved|rejected
        // Afficher uniquement quand l'IBAN est absent ou refusé (pas "en cours").
        final bool rejected = status == 'rejected';
        final bool absent = status == null || status.isEmpty;
        if (AuthGuard.isGuest || !(absent || rejected)) {
          return const SizedBox.shrink();
        }

        // Rouge sémantique : l'IBAN est absent ou refusé, c'est une
        // anomalie à corriger. (Renommé : « accent » désignait ici un rouge,
        // en collision avec l'accent orange de la marque.)
        const Color tone = AppDesign.danger;
        final Color bg = AppDesign.dangerSubtle;

        final String title =
            rejected
                ? 'wallet.iban_banner.rejected_title'.tr
                : 'wallet.iban_banner.missing_title'.tr;
        final String subtitle = rejected
            ? 'wallet.iban_banner.rejected_subtitle'.tr
            : 'wallet.iban_banner.missing_subtitle'.tr;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Get.toNamed('/stripe-connect'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tone.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: tone,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tone,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: AppThemeSystem.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: tone),
                  ],
                ),
              ),
            ),
          ),
        );
      });
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
            // La carte adopte un neutre sombre de la charte plutôt qu'un
            // dégradé bleu-violet sans lien avec la marque. Le montant y
            // ressort par contraste, et l'accent orange reste réservé aux
            // actions (recharger, retirer).
            decoration: BoxDecoration(
              color: AppDesign.neutral900,
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              boxShadow: context.ds.shadowMd,
            ),
            child: Stack(
              children: [
                // Un seul halo, teinté de l'accent, pour éviter une surface
                // parfaitement plate sans pour autant charger la carte.
                Positioned(
                  right: -60,
                  top: -60,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppDesign.accent.withValues(alpha: 0.10),
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
                                color: AppDesign.neutral900,
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
                                  'wallet.card.balance'.tr,
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
                label: 'wallet.actions.recharge'.tr,
                isPrimary: true,
                onTap: () => RechargeBottomSheet.show(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.arrow_circle_up_outlined,
                label: 'wallet.actions.withdraw'.tr,
                onTap: () => _showWithdrawalOptions(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(
                () => _buildActionButton(
                  context: context,
                  icon: Icons.history_rounded,
                  label: 'wallet.actions.history'.tr,
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
      required VoidCallback onTap,
      bool isPrimary = false,
      int? badgeCount,
    }) {
      final color = isPrimary ? AppDesign.accent : context.ds.textSecondary;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary ? AppDesign.accentSubtle : context.ds.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary ? AppDesign.accentBorder : context.ds.border,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon,
                      color: isPrimary
                          ? AppDesign.accentText
                          : context.ds.textSecondary,
                      size: 24),
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
        final tone = ToneColors.accent(context);

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
                  Icon(Icons.lock_clock_outlined, size: 20, color: AppDesign.icon(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'wallet.locked.title'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tone.background,
                      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                      border: Border.all(color: tone.border),
                    ),
                    child: Text(
                      controller.formatPrice(lockedBalance),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tone.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'wallet.locked.info'.tr,
                style: TextStyle(fontSize: 12, height: 1.4, color: AppDesign.textSecondary(context)),
              ),
              const SizedBox(height: 12),

              // Une seule réservation : carte pleine largeur. Plusieurs :
              // défilement horizontal.
              if (bookings.length == 1)
                _buildLockedBookingCard(context, bookings.first)
              else
                SizedBox(
                  height: 188,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 270,
                      child: _buildLockedBookingCard(context, bookings[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      });
    }

    /// Loyers et acomptes Immo bloqués jusqu'à la visite (ou la fin du litige).
    Widget _buildLockedRealEstateSection(BuildContext context) {
      final items = controller.lockedRealEstate;
      final total = items.fold<int>(0, (sum, r) => sum + (r.ownerAmount ?? 0));

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_work_outlined, size: 20, color: AppDesign.icon(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'wallet.locked.real_estate_title'.tr,
                    style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: AppDesign.textPrimary(context)),
                  ),
                ),
                Text(
                  controller.formatPrice(total.toDouble()),
                  style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: AppDesign.accent),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'wallet.locked.real_estate_info'.tr,
              style: context.textStyle(FontSizeType.body2, color: AppDesign.textSecondary(context)),
            ),
            const SizedBox(height: 12),
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () async {
                    await Get.to(() => ImmoReservationView(reservationId: r.id, standalone: true));
                    controller.refresh();
                  },
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(r.isLand ? Icons.landscape_outlined : Icons.home_outlined, color: AppDesign.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: AppDesign.textPrimary(context))),
                            Text(
                              r.status == 'disputed'
                                  ? 'wallet.locked.real_estate_disputed'.tr
                                  : r.visitDeadlineAt == null
                                      ? r.reference
                                      : 'wallet.locked.real_estate_until'.trParams({'date': immoDate(r.visitDeadlineAt!)}),
                              style: context.textStyle(FontSizeType.caption, color: AppDesign.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        controller.formatPrice((r.ownerAmount ?? 0).toDouble()),
                        style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: AppDesign.textPrimary(context)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    /// Card individuelle pour un booking avec fonds bloqués
    Widget _buildLockedBookingCard(BuildContext context, Map<String, dynamic> booking) {
      final subtotal = booking['subtotal'] as double;
      final kgBooked = booking['kg_booked'] as double;
      final buyerName = booking['buyer_name'] ?? 'wallet.default_client'.tr;
      final tone = ToneColors.accent(context);

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDesign.surface(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusMd),
          border: Border.all(color: AppDesign.border(context)),
          boxShadow: AppDesign.shadowSm(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  ),
                  child: Icon(Icons.luggage_outlined, size: 20, color: tone.foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${kgBooked.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppDesign.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppDesign.surfaceMuted(context),
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'wallet.locked.amount'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppDesign.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.formatPrice(subtotal),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppDesign.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showEnterCodeForUnlock(context),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(
                  'wallet.locked.unlock'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: AppThemeSystem.whiteColor,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
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
        barrierDismissible: false,
      );
    }

    Widget _buildBalancesByProvider(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'wallet.balances.title'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
            const SizedBox(height: 16),

            // KPay (Mobile Money multi-opérateurs)
            Obx(() {
              final balance = controller.kpayAvailableBalance;
              return _buildProviderCard(
                context: context,
                iconData: Icons.phone_android_rounded,
                title: 'Mobile Money',
                subtitle: 'MTN, Orange, Moov, Airtel, M-Pesa…',
                balance: balance,
                color: AppThemeSystem.kpayColor,
              );
            }),

            // Fonds bloqués : ventes en attente de validation du client (48 h
            // après la livraison), litiges en cours, commandes payées au Wallet.
            Obx(() {
              final locked = controller.wallet.value?.lockedKPayBalance ?? 0.0;
              if (locked <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock_outlined, size: 16, color: AppThemeSystem.getSecondaryTextColor(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'wallet.locked.pending_validation'.trParams({'amount': controller.formatPrice(locked)}),
                        style: TextStyle(fontSize: 12, color: AppThemeSystem.getSecondaryTextColor(context)),
                      ),
                    ),
                  ],
                ),
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
                'approved' => last4 != null ? 'IBAN ••••$last4' : 'wallet.balances.to_bank_account'.tr,
                'pending' => 'wallet.balances.iban_pending'.tr,
                'rejected' => 'wallet.balances.iban_rejected_resend'.tr,
                _ => 'wallet.balances.no_iban'.tr,
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProviderCard(
                    context: context,
                    iconData: Icons.account_balance_rounded,
                    title: 'wallet.balances.bank_transfer_iban'.tr,
                    subtitle: subtitle,
                    balance: available,
                    color: AppThemeSystem.bankColor,
                    balanceLabel: status == 'approved'
                        ? '${available.toStringAsFixed(2)} $currency'
                        : '—',
                  ),
                  if (status != 'approved') _buildIbanConfigLink(context, status), // 👈 ajoute cette ligne
                ],
              );
            }),
          ],
        ),
      );
    }
    /// Coordonnées de retrait Mobile Money enregistrées (pré-remplissent les retraits).
    Widget _buildPayoutAccountSection(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'wallet.payout.title'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final account = controller.payoutAccount.value;
              final hasAccount = account != null;
              final title = hasAccount
                  ? KPayCatalog.labelFor(account['provider']?.toString())
                  : 'wallet.payout.none'.tr;
              final subtitle = hasAccount
                  ? [
                      '+${account['masked_phone'] ?? account['phone_number']}',
                      if ((account['account_holder'] ?? '').toString().isNotEmpty)
                        account['account_holder'].toString(),
                    ].join(' · ')
                  : 'wallet.payout.none_hint'.tr;

              return InkWell(
                onTap: () => PayoutAccountSheet.show(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasAccount
                          ? AppThemeSystem.kpayColor.withValues(alpha: 0.3)
                          : AppThemeSystem.getBorderColor(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppThemeSystem.kpayColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          hasAccount ? Icons.phone_android_rounded : Icons.add_rounded,
                          color: AppThemeSystem.kpayColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
                      Text(
                        hasAccount ? 'wallet.payout.edit'.tr : 'wallet.payout.add'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }

    /// Petit lien texte discret sous la carte IBAN — pas de bouton
/// Petit lien texte discret sous la carte IBAN — pas de bouton
Widget _buildIbanConfigLink(BuildContext context, String? status) {
  if (status == 'approved') return const SizedBox.shrink();

  final color = status == 'rejected'
      ? AppDesign.danger
      : AppThemeSystem.primaryColor;

  final label = switch (status) {
    'pending' => 'wallet.balances.iban_pending'.tr,
    'rejected' => 'wallet.iban_link.rejected'.tr,
    _ => 'wallet.iban_link.configure'.tr,
  };

  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 4),
    child: InkWell(
      // Ouvert à tout compte connecté (vendeur comme acheteur) ; l'invité
      // doit d'abord se connecter.
      onTap: () {
        if (AuthGuard.isGuest) {
          AppDialogs.showLoginRequiredDialog(context, featureName: 'wallet.iban_link.bank_transfer_feature'.tr);
        } else {
          Get.toNamed('/stripe-connect');
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
              decoration: TextDecoration.underline,
              decorationColor: color.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    ),
  );
}
    Widget _buildProviderCard({
      required BuildContext context,
      required IconData iconData,
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
            // Icône
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
    /// Les deux rails (KPay / Virement IBAN) sont toujours affichés,
    /// grisés + non cliquables quand indisponibles (aucun solde, ou IBAN non validé).
    void _showWithdrawalOptions(BuildContext context) async {
      // Seul le disponible se retire : les fonds bloqués attendent la
      // confirmation du client ou l'issue d'une réclamation.
      final kpayBal = controller.kpayAvailableBalance;
      final stripeEligible = controller.stripeWithdrawEligible.value;
      final stripeBal = controller.stripeWithdrawAvailable.value;
      final stripeLast4 = controller.stripeIbanLast4.value;
      final stripeCurrency = controller.stripeWithdrawCurrency.value;

      // Un moyen non configuré côté plateforme est grisé (raison affichée au tap),
      // pour éviter que l'utilisateur tente un retrait qui échouerait par une erreur.
      final kpayConfigured = controller.kpayConfigured.value;
      final stripeConfigured = controller.stripeConfigured.value;

      final options = <PaymentMethodOption>[
        PaymentMethodOption(
          code: 'kpay',
          label: 'Mobile Money',
          subtitle: 'MTN, Orange, Moov, Airtel, M-Pesa…',
          flow: 'phone',
          enabled: kpayConfigured,
          available: kpayConfigured && kpayBal > 0,
          minCurrency: 'XAF',
          unavailableReason: (kpayConfigured && kpayBal > 0) ? null : 'disabled',
          hint: !kpayConfigured
              ? 'wallet.withdraw_options.temporarily_unavailable'.tr
              : (kpayBal > 0
                  ? 'wallet.withdraw_options.amount_available'
                      .trParams({'amount': controller.formatPrice(kpayBal)})
                  : 'wallet.withdraw_options.no_balance'.tr),
        ),
        PaymentMethodOption(
          code: 'stripe',
          label: 'wallet.balances.bank_transfer_iban'.tr,
          subtitle: stripeLast4 != null
              ? 'IBAN ••••$stripeLast4'
              : 'wallet.balances.to_bank_account'.tr,
          flow: 'redirect',
          enabled: stripeConfigured,
          available: stripeConfigured && stripeEligible && stripeBal > 0,
          minCurrency: 'EUR',
          unavailableReason:
              (stripeConfigured && stripeEligible && stripeBal > 0) ? null : 'disabled',
          hint: !stripeConfigured
              ? 'wallet.withdraw_options.temporarily_unavailable'.tr
              : (!stripeEligible
                  ? 'wallet.withdraw_options.iban_not_validated'.tr
                  : (stripeBal > 0
                      ? 'wallet.withdraw_options.amount_available'.trParams({
                          'amount':
                              '${stripeBal.toStringAsFixed(2)} $stripeCurrency'
                        })
                      : 'wallet.withdraw_options.no_balance'.tr)),
        ),
      ];

      final selected = await PaymentMethodSelector.show(
        amount: kpayBal,
        currency: 'FCFA',
        amountLabel: 'wallet.withdraw_options.available_balance'.tr,
        title: 'wallet.withdraw_options.title'.tr,
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
          // Montant, conversion et frais s'empilent : clavier ouvert, le
          // contenu défile et le bouton de validation reste visible.
          scrollable: true,
          backgroundColor: AppThemeSystem.getSurfaceColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(
                Icons.account_balance_rounded,
                color: AppThemeSystem.bankColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'wallet.stripe_dialog.title'.tr,
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
                  'wallet.stripe_dialog.to_iban'.trParams({'last4': last4}),
                  style: TextStyle(color: AppThemeSystem.getSecondaryTextColor(context)),
                ),
              const SizedBox(height: 4),
              Text(
                converts
                    ? 'wallet.stripe_dialog.available_converted'.trParams({
                        'amount': money(available, sourceCurrency),
                        'converted': money(payoutAvailable, payoutCurrency),
                      })
                    : 'wallet.stripe_dialog.available'
                        .trParams({'amount': money(available, payoutCurrency)}),
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
                  labelText: 'wallet.stripe_dialog.amount_label'
                      .trParams({'currency': sourceCurrency}),
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
                          'wallet.stripe_dialog.converting'.tr,
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
                      'wallet.stripe_dialog.enter_amount_hint'.tr,
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
                                'wallet.stripe_dialog.you_will_receive'
                                    .trParams({'amount': money(quote, payoutCurrency)}),
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
                'wallet.stripe_dialog.delay_info'.tr,
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
              child: Text('wallet.stripe_dialog.cancel'.tr),
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
                            AppFeedback.show('wallet.stripe_dialog.invalid_amount_title'.tr,
                                'wallet.stripe_dialog.invalid_amount_message'.tr,
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          if (amount > available) {
                            AppFeedback.show(
                                'wallet.stripe_dialog.insufficient_balance'.tr,
                                'wallet.stripe_dialog.available'.trParams({
                                  'amount': money(available,
                                      converts ? sourceCurrency : payoutCurrency)
                                }),
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          debounce?.cancel();
                          final result = await controller.withdrawStripe(
                            amount: amount,
                            currency: sourceCurrency,
                          );
                          Get.back();
                          AppFeedback.show(
                            result['success'] == true
                                ? 'wallet.stripe_dialog.transfer_in_progress'.tr
                                : 'wallet.stripe_dialog.error'.tr,
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
                      : Text('wallet.actions.withdraw'.tr),
                )),
          ],
        ),
      );
    }
  }
