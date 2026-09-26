import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/storage_service.dart';
import '../controllers/chat_controller.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  ChatController get controller => Get.find<ChatController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rafraîchir quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed && StorageService.isAuthenticated) {
      controller.refreshConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      // Un en-tête en bonne et due forme : sans lui, la liste commençait au
      // tout premier pixel et la barre de recherche passait sous l'heure et
      // les icônes de réseau.
      appBar: AppBar(
        backgroundColor: AppThemeSystem.getBackgroundColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        titleSpacing: AppThemeSystem.getHorizontalPadding(context),
        title: Text(
          'Messages',
          style: context.textStyle(
            FontSizeType.h5,
            fontWeight: FontWeight.w700,
            color: AppThemeSystem.getPrimaryTextColor(context),
          ),
        ),
        actions: [
          Obx(
            () => IconButton(
              icon: controller.isLoading.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppThemeSystem.getSecondaryTextColor(context),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
              // Recharger pendant un chargement relançait une seconde
              // requête par-dessus la première.
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.loadConversations(refresh: true),
              tooltip: 'Recharger',
            ),
          ),
          SizedBox(width: AppDesign.space1),
        ],
      ),
      body: Obx(() {
        final conversations = controller.filteredConversations;

        // Aucune conversation du tout : l'écran est vide pour de bon, la
        // barre de recherche n'aurait rien à filtrer.
        if (controller.conversations.isEmpty) {
          return controller.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: controller.refreshConversations,
                  color: AppDesign.accent,
                  child: ListView(
                    // La liste ne déborde pas : sans cela, on ne peut pas la
                    // tirer pour réessayer.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.6,
                        child: _buildEmptyState(context),
                      ),
                    ],
                  ),
                );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshConversations,
          color: AppDesign.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Parcourir les conversations referme le clavier de la recherche.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              _buildStickySearchBar(context),
              if (conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildSearchEmptyState(context),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(bottom: AppDesign.space6),
                  sliver: SliverList.separated(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) =>
                        _buildConversationItem(context, conversations[index]),
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 88,
                      endIndent: AppThemeSystem.getHorizontalPadding(context),
                      color: AppThemeSystem.getBorderColor(context),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ================================
  // BARRE DE RECHERCHE ÉPINGLÉE
  // ================================

  /// Recherche épinglée en tête de liste.
  ///
  /// Le bouton « Recharger » qui la doublait est remonté dans l'en-tête : il
  /// prenait la largeur d'un carré de 48 px en permanence, alors qu'on s'en
  /// sert une fois de loin en loin.
  Widget _buildStickySearchBar(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SearchBarDelegate(controller: controller, context: context),
    );
  }

  // ================================
  // ITEM DE CONVERSATION
  // ================================

  Widget _buildConversationItem(
    BuildContext context,
    Map<String, dynamic> conversation,
  ) {
    final hasUnread = conversation['unreadCount'] > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.openConversation(conversation),
        onLongPress: () => _showDeleteConversationDialog(context, conversation),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppThemeSystem.getHorizontalPadding(context),
            vertical: 12,
          ),
          child: Row(
            children: [
              // Avatar avec statut en ligne
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    // Aplat uni, sans ombre colorée : c'est le même avatar que
                    // dans l'écran de conversation, et l'ombre teintée
                    // contrevenait à la règle « jamais d'ombre colorée ».
                    decoration: const BoxDecoration(
                      color: AppDesign.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        conversation['avatar'],
                        style: context.textStyle(
                          FontSizeType.h5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (conversation['isOnline'])
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppDesign.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppThemeSystem.getBackgroundColor(context),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(width: 16),

              // Contenu de la conversation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation['name'],
                            style: context.textStyle(
                              FontSizeType.subtitle1,
                              fontWeight:
                                  hasUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          conversation['timestamp'],
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: hasUnread
                                ? AppThemeSystem.primaryColor
                                : AppThemeSystem.getSecondaryTextColor(context),
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation['lastMessage'],
                            style: context.textStyle(
                              FontSizeType.body2,
                              color: hasUnread
                                  ? AppThemeSystem.getPrimaryTextColor(context)
                                  : AppThemeSystem.getSecondaryTextColor(
                                      context),
                              fontWeight:
                                  hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppDesign.accent,
                              borderRadius:
                                  BorderRadius.circular(AppDesign.radiusPill),
                            ),
                            child: Center(
                              child: Text(
                                conversation['unreadCount'].toString(),
                                style: context.textStyle(
                                  FontSizeType.caption,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Image du produit (optionnel)
              if (conversation['productImage'] != null) ...[
                SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppThemeSystem.getBorderRadius(
                      context,
                      BorderRadiusType.small,
                    ),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: conversation['productImage'],
                    width: 48,
                    height: 48,
                    // Vignette de 48 px : décodée à sa taille, pas en
                    // pleine résolution.
                    memCacheWidth:
                        (48 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 48,
                      height: 48,
                      color: AppThemeSystem.grey200,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppThemeSystem.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 48,
                      height: 48,
                      color: AppThemeSystem.grey200,
                      child: Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: AppThemeSystem.grey600,
                      ),
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

  // ================================
  // ÉTATS VIDES
  // ================================

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Aucune conversation',
      message:
          'Vos échanges avec les acheteurs et les vendeurs apparaîtront ici.',
      actionLabel: 'Parcourir les produits',
      onAction: () => Get.toNamed('/search'),
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'Aucun résultat',
      message: 'Aucune conversation ne correspond à votre recherche.',
    );
  }

  // ================================
  // DELETE CONVERSATION DIALOG
  // ================================

  void _showDeleteConversationDialog(
    BuildContext context,
    Map<String, dynamic> conversation,
  ) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getBackgroundColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeSystem.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              // Icône et titre
              Icon(
                Icons.delete_outline_rounded,
                color: AppDesign.danger,
                size: 48,
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Supprimer cette conversation ?',
                  style: context.textStyle(
                    FontSizeType.h6,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'La conversation sera masquée de votre liste. L\'autre personne pourra toujours la voir.',
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 32),

              // Boutons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Annuler
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppThemeSystem.grey300,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: context.textStyle(
                            FontSizeType.button,
                            fontWeight: FontWeight.w600,
                            color: AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Supprimer
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back(); // Fermer le dialog
                          controller.deleteConversation(conversation);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.danger,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Supprimer',
                          style: context.textStyle(
                            FontSizeType.button,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
// ================================
// EN-TÊTE ÉPINGLÉ DE LA RECHERCHE
// ================================

/// Porte la barre de recherche en tête de liste.
///
/// Sa hauteur se mesure sur le texte réellement rendu plutôt que d'être fixée
/// à l'avance : une valeur en dur déborde dès que l'appareil grossit
/// l'écriture, et un en-tête épinglé doit annoncer sa hauteur d'avance.
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  _SearchBarDelegate({required this.controller, required BuildContext context})
      : _height = _measure(context);

  final ChatController controller;
  final double _height;

  static double _measure(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontSize: AppThemeSystem.getFontSize(context, FontSizeType.body2),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // Le champ : une ligne de texte, son rembourrage vertical, sa bordure ;
    // puis les marges de la barre elle-même.
    return painter.height + AppDesign.space3 * 2 + 2 + AppDesign.space3 * 2;
  }

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_SearchBarDelegate oldDelegate) =>
      oldDelegate._height != _height || oldDelegate.controller != controller;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      // Opaque : les conversations défilent dessous.
      color: AppThemeSystem.getBackgroundColor(context),
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: AppDesign.space3,
      ),
      alignment: Alignment.center,
      child: Obx(() {
        final hasQuery = controller.searchQuery.value.isNotEmpty;

        return TextField(
          onChanged: (value) => controller.searchQuery.value = value,
          textInputAction: TextInputAction.search,
          style: context.textStyle(FontSizeType.body2),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Rechercher une conversation',
            hintStyle: context.textStyle(
              FontSizeType.body2,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppThemeSystem.getSecondaryTextColor(context),
                    tooltip: 'Effacer',
                    onPressed: () => controller.searchQuery.value = '',
                  )
                : null,
            filled: true,
            fillColor: context.ds.surfaceMuted,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDesign.space3,
              vertical: AppDesign.space3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              borderSide: BorderSide(color: AppDesign.accent, width: 1.5),
            ),
          ),
        );
      }),
    );
  }
}
