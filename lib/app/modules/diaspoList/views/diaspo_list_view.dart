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
        actions: [
          // Filter button with badge
          Obx(() => Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: controller.showFiltersBottomSheet,
                  ),
                  if (controller.hasActiveFilters.value)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              )),
          // Clear filters button (only show if filters are active)
          Obx(() => controller.hasActiveFilters.value
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Effacer les filtres',
                  onPressed: controller.clearFilters,
                )
              : const SizedBox()),
        ],
      ),
      body: Column(
        children: [
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
        // Smart skeleton loader for initial load or refresh
        final isInitialOrRefresh = controller.isLoading.value && controller.offers.isEmpty;

        if (isInitialOrRefresh) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5, // Show 5 skeleton cards
            itemBuilder: (context, index) => _buildSkeletonCard(isDark),
          );
        }

        if (controller.offers.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flight_takeoff_rounded,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Aucune offre disponible',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.hasActiveFilters.value
                        ? 'Aucune offre ne correspond à vos critères de recherche.'
                        : 'Soyez le premier à publier une offre de transport!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (controller.hasActiveFilters.value)
                    ElevatedButton.icon(
                      onPressed: controller.clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Effacer les filtres'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: controller.handleCreateOffer,
                      icon: const Icon(Icons.add),
                      label: const Text('Créer mon offre'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  // Info card explaining the marketplace
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Comment ça marche?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoItem(
                          '📦',
                          'Publiez votre offre',
                          'Indiquez votre itinéraire et le poids disponible',
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          '🛒',
                          'Recevez des réservations',
                          'Les acheteurs réservent des kilos sur votre trajet',
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          '💰',
                          'Gagnez de l\'argent',
                          'Rentabilisez votre voyage en transportant des colis',
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            // Detect when user scrolls to bottom
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
              if (controller.hasMore && !controller.isLoadingMore.value) {
                controller.loadMore();
              }
            }
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.offers.length + (controller.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Loading indicator at the bottom
              if (index == controller.offers.length) {
                return Obx(() => controller.isLoadingMore.value
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const SizedBox());
              }

              final offer = controller.offers[index];
              return _buildOfferCard(context, offer, isDark);
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
      child: InkWell(
        onTap: () => Get.toNamed('/diaspo/detail', arguments: {'offer': offer}),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route with "My Offer" badge
              Row(
                children: [
                  const Icon(Icons.flight_takeoff, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${offer.departureCity}, ${offer.departureCountry}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Show badge for own offers in "Tous" tab
                  if (isOwnOffer && !isMyOffer) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppThemeSystem.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppThemeSystem.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Moi',
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.flight_land, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${offer.arrivalCity}, ${offer.arrivalCountry}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Price and availability
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prix par kilo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${offer.pricePerKg} ${offer.currency}/kg',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Disponible',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${offer.remainingKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (isMyOffer) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Mon offre',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
                      '${booking.totalPrice.toStringAsFixed(0)} €',
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

            // Confirmation code for buyer
            if (isBuyer && booking.status == 'pending') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Code de confirmation',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          booking.confirmationCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Complété';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  /// Build info item for empty state
  Widget _buildInfoItem(String emoji, String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
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
