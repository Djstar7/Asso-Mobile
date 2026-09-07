import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/diaspo_list_controller.dart';

class DiaspoListView extends GetView<DiaspoListController> {
  const DiaspoListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : Colors.grey[100],
      appBar: AppBar(
        title: const Text('DIASPO EXCHANGE'),
        centerTitle: true,
        ),
      body: Column(
        children: [
        //  Zone de recherche
        _buildSearchBar(context, isDark),

          Obx(() => _buildVerificationBanner(context, isDark)),

          // Tabs horizontaux (comme les catégories)
          _buildTabs(context, isDark),

          // Contenu du tab sélectionné
          Expanded(
            child: Obx(() => _buildTabContent(context, isDark)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.handleCreateOffer,
        backgroundColor: AppThemeSystem.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Créer mon offre'),
      ),
    );
  }

  Widget _buildVerificationBanner(BuildContext context, bool isDark) {
    final status = controller.verificationStatus.value;
    if (status == 'verified') return const SizedBox.shrink();

    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final color = isRejected ? Colors.red : Colors.orange;
    final title = isPending
        ? 'Vérification d\'identité en cours'
        : isRejected
            ? 'Vérification à compléter'
            : 'Vérifiez votre identité';
    final message = isPending
        ? 'Vos offres restent enregistrées et seront publiées après validation.'
        : 'Vous pouvez créer une offre, mais elle restera en attente jusqu\'à la validation de votre identité.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(isPending ? Icons.hourglass_top : Icons.verified_user_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 3),
                Text(message, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
          TextButton(
            onPressed: controller.handleVerification,
            child: Text(isPending ? 'Voir' : (isRejected ? 'Compléter' : 'Commencer')),
          ),
        ],
      ),
    );
  }

  /// Barre de recherche (remplace les filtres)
Widget _buildSearchBar(BuildContext context, bool isDark) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (value) => controller.searchQuery.value = value,
        decoration: InputDecoration(
          hintText: 'Rechercher par ville ou pays...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white54 : Colors.grey[500],
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white54 : Colors.grey[500],
          ),
          suffixIcon: Obx(
            () => controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDark ? Colors.white54 : Colors.grey[500],
                    ),
                    onPressed: () => controller.searchQuery.value = '',
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
  );
}

  /// Tabs horizontaux
  Widget _buildTabs(BuildContext context, bool isDark) {
    final tabs = ['Tous', 'Mes Offres', 'Mes Achats', 'Mes Ventes'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = controller.selectedTab.value == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => controller.changeTab(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppThemeSystem.primaryColor
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.grey[700]),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            )),
      ),
    );
  }

  /// Contenu du tab
  Widget _buildTabContent(BuildContext context, bool isDark) {
    switch (controller.selectedTab.value) {
      case 0:
        return _buildAllOffers(context, isDark);
      case 1:
        return _buildMyOffers(context, isDark);
      case 2:
        return _buildMyBookingsAsBuyer(context, isDark);
      case 3:
        return _buildMyBookingsAsSeller(context, isDark);
      default:
        return const SizedBox();
    }
  }

  /// Tab 1: Tous (toutes les offres) - With lazy loading
Widget _buildAllOffers(BuildContext context, bool isDark) {
  return RefreshIndicator(
    onRefresh: controller.refresh,
    child: Obx(() {
      final displayedOffers = controller.filteredOffers;
      final isInitialOrRefresh = controller.isLoading.value && controller.offers.isEmpty;

      if (isInitialOrRefresh) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (context, index) => _buildSkeletonCard(isDark),
        );
      }

      if (displayedOffers.isEmpty) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_takeoff_rounded, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 24),
                Text(
                  controller.searchQuery.value.isNotEmpty
                      ? 'Aucun résultat pour "${controller.searchQuery.value}"'
                      : 'Aucune offre disponible',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  controller.searchQuery.value.isNotEmpty
                      ? 'Essayez une autre ville ou un autre pays.'
                      : 'Soyez le premier à publier une offre de transport!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                if (controller.searchQuery.value.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => controller.searchQuery.value = '',
                    icon: const Icon(Icons.clear),
                    label: const Text('Effacer la recherche'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: controller.handleCreateOffer,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer mon offre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                    ),
                  ),
              ],
            ),
          ],
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            if (controller.hasMore && !controller.isLoadingMore.value &&
                controller.searchQuery.value.isEmpty) {
              controller.loadMore();
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: displayedOffers.length +
              (controller.hasMore && controller.searchQuery.value.isEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == displayedOffers.length) {
              return Obx(() => controller.isLoadingMore.value
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox());
            }
            return _buildOfferCard(context, displayedOffers[index], isDark);
          },
        ),
      );
    }),
  );
}
  /// Tab 2: Mes Offres
  Widget _buildMyOffers(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() {
        if (controller.isLoading.value && controller.myOffers.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 3,
            itemBuilder: (context, index) => _buildSkeletonCard(isDark),
          );
        }

        if (controller.myOffers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Vous n\'avez pas encore d\'offres',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: controller.handleCreateOffer,
                  icon: const Icon(Icons.add),
                  label: const Text('Créer une offre'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.myOffers.length,
          itemBuilder: (context, index) {
            final offer = controller.myOffers[index];
            return _buildOfferCard(context, offer, isDark, isMyOffer: true);
          },
        );
      }),
    );
  }

  /// Tab 3: Mes Achats
  Widget _buildMyBookingsAsBuyer(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() {
        if (controller.isLoading.value && controller.myBookingsAsBuyer.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 3,
            itemBuilder: (context, index) => _buildSkeletonBookingCard(isDark),
          );
        }

        if (controller.myBookingsAsBuyer.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Vous n\'avez pas encore d\'achats',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.myBookingsAsBuyer.length,
          itemBuilder: (context, index) {
            final booking = controller.myBookingsAsBuyer[index];
            return _buildBookingCard(context, booking, isDark, role: 'buyer');
          },
        );
      }),
    );
  }

  /// Tab 4: Mes Ventes
  Widget _buildMyBookingsAsSeller(BuildContext context, bool isDark) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() {
        if (controller.isLoading.value && controller.myBookingsAsSeller.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 3,
            itemBuilder: (context, index) => _buildSkeletonBookingCard(isDark),
          );
        }

        if (controller.myBookingsAsSeller.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sell_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Vous n\'avez pas encore de ventes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.myBookingsAsSeller.length,
          itemBuilder: (context, index) {
            final booking = controller.myBookingsAsSeller[index];
            return _buildBookingCard(context, booking, isDark, role: 'seller');
          },
        );
      }),
    );
  }

  /// Carte d'offre
  Widget _buildOfferCard(BuildContext context, offer, bool isDark, {bool isMyOffer = false}) {
    // Check if this is the user's own offer (in "Tous" tab)
    final isOwnOffer = controller.isMyOffer(offer);
    final showMine = isMyOffer || isOwnOffer;

    final muted = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFECECEF),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed('/diaspo/detail', arguments: {'offer': offer}),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trajet compact : Départ → Arrivée + badge éventuel
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flight_takeoff, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${offer.departureCity}, ${offer.departureCountry}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              width: 2,
                              height: 14,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              color: muted.withValues(alpha: 0.3),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.flight_land, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${offer.arrivalCity}, ${offer.arrivalCountry}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (showMine) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 13, color: AppThemeSystem.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Mon offre',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppThemeSystem.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (showMine) ...[
                  const SizedBox(height: 12),
                  _buildOfferStatusBadge(offer),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: muted.withValues(alpha: 0.15), height: 1),
                ),
                // Prix + disponibilité
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prix par kilo', style: TextStyle(fontSize: 12, color: muted)),
                        const SizedBox(height: 2),
                        Text(
                          '${offer.formattedPricePerKg} ${offer.currencySymbol}/kg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Text(
                            '${offer.remainingKg.toStringAsFixed(1)} kg dispo',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
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

  Widget _buildOfferStatusBadge(dynamic offer) {
    late final Color color;
    late final IconData icon;
    late final String label;

    if (offer.verificationStatus == 'rejected' || offer.status == 'rejected') {
      color = Colors.red;
      icon = Icons.cancel_outlined;
      label = 'Offre refusée';
    } else if (offer.verificationStatus != 'verified') {
      color = Colors.orange;
      icon = Icons.badge_outlined;
      label = 'En attente de vérification d\'identité';
    } else if (offer.status == 'pending') {
      color = Colors.orange;
      icon = Icons.hourglass_top;
      label = 'En attente d\'approbation';
    } else if (offer.status == 'approved' || offer.status == 'active') {
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_outline;
      label = 'Offre publiée';
    } else {
      color = Colors.grey;
      icon = Icons.info_outline;
      label = offer.status.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }

  /// Carte de réservation
  Widget _buildBookingCard(BuildContext context, booking, bool isDark, {required String role}) {
    final offer = booking.diaspoOffer;
    final isBuyer = role == 'buyer';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(booking.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(booking.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  isBuyer ? 'Achat' : 'Vente',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Route
            if (offer != null) ...[
              Text(
                '${offer.departureCity} → ${offer.arrivalCity}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kilos réservés',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${booking.kgBooked.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Prix total',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    Text(
                      booking.formattedTotal,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Confirmation code for buyer (for paid and pending bookings)
            if (isBuyer && (booking.status == 'paid' || booking.status == 'pending')) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade50,
                      Colors.indigo.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.key,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Votre code secret',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                booking.confirmationCode,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Donnez ce code au voyageur au moment de la remise',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Voyageur (vendeur d'espace) : valider le code remis par l'acheteur.
            if (!isBuyer && booking.status == 'paid') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showValidateCodeDialog(context, booking),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Valider le code de livraison'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            // Voyageur : code déjà validé, colis en transit.
            if (!isBuyer && booking.status == 'confirmed') ...[
              const SizedBox(height: 12),
              _buildInlineNote(
                Icons.check_circle_outline,
                AppThemeSystem.infoColor,
                'Code validé. En attente de la confirmation de réception par l\'acheteur.',
              ),
            ],

            // Acheteur : confirmer la réception (libère les fonds au voyageur).
            if (isBuyer && booking.status == 'confirmed') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmReceipt(context, booking),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('J\'ai bien reçu mon colis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Petite note d'information inline (icône + texte) aux couleurs de la marque.
  Widget _buildInlineNote(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialogue de saisie du code par le voyageur (validation de la livraison).
  void _showValidateCodeDialog(BuildContext context, dynamic booking) {
    final codeController = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.verified_outlined, color: AppThemeSystem.primaryColor),
            const SizedBox(width: 10),
            const Expanded(child: Text('Valider la livraison')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisissez le code à 6 chiffres que l\'acheteur vous a communiqué.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: controller.isValidatingCode.value
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) {
                          Get.snackbar('Code invalide', 'Le code doit contenir 6 chiffres',
                              snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        await controller.sellerConfirmCode(booking.id, code);
                      },
                child: controller.isValidatingCode.value
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Valider'),
              )),
        ],
      ),
    );
  }

  /// L'acheteur confirme avoir reçu son colis (libère les fonds au voyageur).
  void _confirmReceipt(BuildContext context, dynamic booking) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réception'),
        content: const Text(
          'Confirmez-vous avoir bien reçu votre colis ? Le voyageur sera crédité et la réservation sera clôturée.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Pas encore')),
          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.successColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: controller.isValidatingCode.value
                    ? null
                    : () async => controller.confirmReceipt(booking.id, booking.confirmationCode),
                child: const Text('Oui, confirmer'),
              )),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppThemeSystem.successColor;
      case 'confirmed':
        return AppThemeSystem.infoColor;
      case 'paid':
        return AppThemeSystem.primaryColor;
      case 'pending':
        return AppThemeSystem.warningColor;
      case 'cancelled':
        return AppThemeSystem.errorColor;
      case 'refunded':
        return AppThemeSystem.grey600;
      default:
        return AppThemeSystem.grey500;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Terminé';
      case 'confirmed':
        return 'En transit';
      case 'paid':
        return 'Payé';
      case 'pending':
        return 'En attente de paiement';
      case 'cancelled':
        return 'Annulé';
      case 'refunded':
        return 'Remboursé';
      default:
        return status;
    }
  }

  /// Build info item for empty state
  Widget _buildInfoItem(IconData icon, String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppThemeSystem.primaryColor, size: 22),
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
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Skeleton card for loading state
  Widget _buildSkeletonCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Departure skeleton
            Row(
              children: [
                _buildShimmerBox(20, 20, isDark),
                const SizedBox(width: 8),
                Expanded(child: _buildShimmerBox(16, double.infinity, isDark)),
              ],
            ),
            const SizedBox(height: 8),
            // Arrival skeleton
            Row(
              children: [
                _buildShimmerBox(20, 20, isDark),
                const SizedBox(width: 8),
                Expanded(child: _buildShimmerBox(16, double.infinity, isDark)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 8),
            const SizedBox(height: 16),
            // Price and availability skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(12, 80, isDark),
                    const SizedBox(height: 4),
                    _buildShimmerBox(18, 100, isDark),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildShimmerBox(12, 70, isDark),
                    const SizedBox(height: 4),
                    _buildShimmerBox(18, 80, isDark),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer box with animation
  Widget _buildShimmerBox(double height, double width, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.grey[800]!.withValues(alpha: 0.3),
                      Colors.grey[700]!.withValues(alpha: 0.5),
                      Colors.grey[800]!.withValues(alpha: 0.3),
                    ]
                  : [
                      Colors.grey[300]!.withValues(alpha: 0.5),
                      Colors.grey[200]!.withValues(alpha: 0.7),
                      Colors.grey[300]!.withValues(alpha: 0.5),
                    ],
              stops: [
                0.0,
                value,
                1.0,
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
      onEnd: () {
        // Animation loops automatically by rebuilding
      },
    );
  }

  /// Skeleton card for booking loading state
  Widget _buildSkeletonBookingCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildShimmerBox(20, 100, isDark),
                _buildShimmerBox(12, 60, isDark),
              ],
            ),
            const SizedBox(height: 12),
            // Route skeleton
            _buildShimmerBox(16, double.infinity, isDark),
            const SizedBox(height: 12),
            // Details skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(12, 90, isDark),
                    const SizedBox(height: 4),
                    _buildShimmerBox(16, 70, isDark),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildShimmerBox(12, 80, isDark),
                    const SizedBox(height: 4),
                    _buildShimmerBox(16, 80, isDark),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
