import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/storage_service.dart';
import '../controllers/chat_controller.dart';

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
      body: Obx(() {
        final conversations = controller.filteredConversations;

        // Si vide, afficher l'état vide avec barre de recherche
        if (conversations.isEmpty &&
            controller.conversations.isNotEmpty &&
            controller.searchQuery.value.isNotEmpty) {
          return CustomScrollView(
            slivers: [
              _buildStickySearchBar(context),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildSearchEmptyState(context),
              ),
            ],
          );
        }

        // Si aucune conversation du tout
        if (controller.conversations.isEmpty) {
          return _buildEmptyState(context);
        }

        // Affichage normal avec conversations
        return CustomScrollView(
          slivers: [
            // Barre de recherche épinglée
            _buildStickySearchBar(context),

            // Liste des conversations
            SliverPadding(
              padding: const EdgeInsets.only(top: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conversation = conversations[index];
                    return Column(
                      children: [
                        _buildConversationItem(context, conversation),
                        if (index < conversations.length - 1)
                          Divider(
                            height: 1,
                            indent: 88,
                            color: AppThemeSystem.getBorderColor(context)
                                .withOpacity(0.3),
                          ),
                      ],
                    );
                  },
                  childCount: conversations.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ================================
  // BARRE DE RECHERCHE ÉPINGLÉE
  // ================================

  Widget _buildStickySearchBar(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 80,
        maxHeight: 80,
        child: Container(
          color: AppThemeSystem.getBackgroundColor(context),
          padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppThemeSystem.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(
                AppThemeSystem.getBorderRadius(
                  context,
                  BorderRadiusType.medium,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => controller.searchQuery.value = value,
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation...',
                hintStyle: context.textStyle(
                  FontSizeType.body2,
                  color: AppThemeSystem.getSecondaryTextColor(context),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppThemeSystem.getSecondaryTextColor(context),
                ),
                suffixIcon: Obx(
                  () => controller.searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => controller.searchQuery.value = '',
                          color: AppThemeSystem.getSecondaryTextColor(context),
                        )
                      : const SizedBox.shrink(),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: context.textStyle(FontSizeType.body2),
            ),
          ),
        ),
      ),
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
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppThemeSystem.primaryColor,
                          AppThemeSystem.tertiaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeSystem.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                          color: const Color(0xFF4CAF50),
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
                              color: AppThemeSystem.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppThemeSystem.primaryColor
                                      .withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 80,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
            Text(
              'Aucune conversation',
              style: context.h4,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeSystem.getElementSpacing(context)),
            Text(
              'Vos conversations avec les acheteurs\net vendeurs apparaîtront ici',
              style: context.textStyle(
                FontSizeType.body1,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
            ElevatedButton.icon(
              onPressed: () => Get.toNamed('/search'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Parcourir les produits'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: AppThemeSystem.whiteColor,
                padding: EdgeInsets.symmetric(
                  horizontal: AppThemeSystem.getHorizontalPadding(context),
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
            Text(
              'Aucun résultat',
              style: context.h5,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeSystem.getElementSpacing(context)),
            Text(
              'Aucune conversation ne correspond à votre recherche',
              style: context.textStyle(
                FontSizeType.body1,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
                color: Colors.red,
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
                          backgroundColor: Colors.red,
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
// SLIVER PERSISTENT HEADER DELEGATE
// ================================

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
