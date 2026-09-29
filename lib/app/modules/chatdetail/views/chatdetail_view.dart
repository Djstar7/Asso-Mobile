import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/chatdetail_controller.dart';
import '../../../core/widgets/scoped_controller_page.dart';

/// Page ouverte par la route : chaque conversation empilée a son propre
/// [ChatdetailController] (voir [ScopedControllerPage]).
class ChatdetailPage extends StatelessWidget {
  const ChatdetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedControllerPage<ChatdetailController>(
      create: ChatdetailController.new,
      builder: (controller) => ChatdetailView(pageController: controller),
    );
  }
}

class ChatdetailView extends GetView<ChatdetailController> {
  const ChatdetailView({super.key, this.pageController});

  /// Contrôleur propre à la page ; sans lui, celui enregistré dans GetX.
  final ChatdetailController? pageController;

  @override
  ChatdetailController get controller => pageController ?? super.controller;

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      appBar: AppBar(
        // `darkCardColor` est un bleu-gris froid, hors de l'échelle neutre
        // chaude du design system : en sombre, l'en-tête du chat n'avait pas
        // la même teinte que le reste de l'application.
        backgroundColor: AppDesign.surface(context),
        elevation: 0,
        leading: const AppBackButton(),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesign.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      controller.conversation['avatar'] ?? 'U',
                      style: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (controller.conversation['isOnline'] == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppDesign.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppDesign.surface(context),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.conversation['name'] ?? 'chatdetail.default_user_name'.tr,
                    style: context.textStyle(
                      FontSizeType.body1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(() => controller.otherUserTyping.value
                      ? Text(
                          'chatdetail.typing'.tr,
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: AppThemeSystem.primaryColor,
                          ),
                        )
                      : Text(
                          controller.conversation['isOnline'] == true ? 'chatdetail.online'.tr : 'chatdetail.offline'.tr,
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: AppThemeSystem.grey600,
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Fil des messages
          Expanded(
            child: Obx(() {
              // Trois situations bien distinctes, qui donnaient toutes la
              // même page blanche : le chargement, la conversation encore
              // vierge, et le fil garni.
              if (controller.isLoading.value && controller.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.messages.isEmpty) {
                return _buildConversationStart(context);
              }

              return ListView.builder(
                controller: controller.scrollController,
                // Remonter le fil range le clavier, comme dans toute
                // messagerie : il cachait la moitié des messages.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(16),
                itemCount: controller.messages.length,
                itemBuilder: (context, index) {
                  final message = controller.messages[index];
                  return _buildMessageBubble(context, message);
                },
              );
            }),
          ),

          // Typing indicator (for other user)
          Obx(() {
            if (!controller.otherUserTyping.value) return SizedBox.shrink();
            return _buildTypingIndicator(context);
          }),

          // Input bar
          _buildInputBar(context, isDark),
        ],
      ),
    );
  }

  /// Conversation ouverte mais encore sans message.
  ///
  /// Mieux vaut une invitation à écrire qu'une page blanche : on vient
  /// souvent ici depuis une fiche produit, sans savoir par quoi commencer.
  Widget _buildConversationStart(BuildContext context) {
    final name = controller.conversation['name'] ?? 'chatdetail.default_interlocutor'.tr;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            SizedBox(height: 16),
            Text(
              'chatdetail.start.title'.tr,
              style: context.textStyle(
                FontSizeType.h6,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'chatdetail.start.message'.trParams({'name': '$name'}),
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.getSecondaryTextColor(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> message) {
    final isSystem = message['isSystem'] as bool? ?? false;

    // Si c'est un message système, afficher dans un style spécial
    if (isSystem) {
      return _buildSystemMessage(context, message);
    }

    final isSentByMe = message['isSentByMe'] as bool;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe)
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppDesign.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  controller.conversation['avatar'] ?? 'U',
                  style: context.textStyle(
                    FontSizeType.caption,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSentByMe
                    ? AppThemeSystem.primaryColor
                    : AppThemeSystem.getSurfaceColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                  bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Afficher le produit taggué si présent (style WhatsApp)
                  if (message['product'] != null)
                    _buildProductQuote(
                      context,
                      message['product'],
                      isSentByMe,
                    ),

                  // Afficher l'offre Diaspo taguée si présente (style WhatsApp)
                  if (message['diaspo_offer'] != null)
                    _buildDiaspoOfferQuote(
                      context,
                      message['diaspo_offer'],
                      isSentByMe,
                    ),

                  // Afficher l'image si présente
                  if (message['image_path'] != null)
                    _buildMessageImage(
                      context,
                      message['image_path'],
                    ),

                  // Afficher le texte seulement s'il est présent
                  if (message['text'] != null && message['text'].toString().isNotEmpty)
                    Text(
                      message['text'],
                      style: context.textStyle(
                        FontSizeType.body2,
                        color: isSentByMe
                            ? Colors.white
                            : AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message['timestamp'],
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: isSentByMe
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppThemeSystem.grey600,
                        ),
                      ),
                      if (isSentByMe) ...[
                        SizedBox(width: 4),
                        Icon(
                          message['isRead']
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: message['isRead']
                              ? AppDesign.info
                              : Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isSentByMe) SizedBox(width: 40),
          if (!isSentByMe) SizedBox(width: 40),
        ],
      ),
    );
  }

  /// Widget pour afficher une image dans un message
  Widget _buildMessageImage(BuildContext context, String imagePath) {
    final isLocalPath = !imagePath.startsWith('http');

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      constraints: BoxConstraints(
        maxWidth: 250,
        maxHeight: 300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isLocalPath
            // Sur le web, un fichier local sélectionné est une URL blob :
            // on la charge via Image.network. Sur mobile, via Image.file (dart:io).
            ? (kIsWeb
                ? Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: AppThemeSystem.grey200,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppThemeSystem.grey600,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: AppThemeSystem.grey200,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppThemeSystem.grey600,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ))
            : CachedNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.cover,
                // Bulle de 250 px au plus : une conversation riche en photos
                // ne les garde plus toutes en pleine résolution.
                memCacheWidth:
                    (250 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                placeholder: (context, url) => Container(
                  height: 150,
                  color: AppThemeSystem.grey200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: AppThemeSystem.grey200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppThemeSystem.grey600,
                      size: 48,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppDesign.accent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                controller.conversation['avatar'] ?? 'U',
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppThemeSystem.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                SizedBox(width: 4),
                _buildDot(1),
                SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value + delay) % 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppThemeSystem.grey600.withValues(
              alpha: 0.3 + (animValue * 0.7),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesign.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge du produit sélectionné
            Obx(() {
              if (controller.selectedProduct.value == null) {
                return SizedBox.shrink();
              }

              final product = controller.selectedProduct.value!;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: AppThemeSystem.primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product['name'] ?? 'chatdetail.product'.tr,
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: AppThemeSystem.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppThemeSystem.grey600,
                      ),
                      onPressed: controller.clearSelectedProduct,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),

            // Badge de l'offre Diaspo sélectionnée
            Obx(() {
              if (controller.selectedDiaspoOffer.value == null) {
                return SizedBox.shrink();
              }

              final diaspoOffer = controller.selectedDiaspoOffer.value!;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flight,
                      color: AppThemeSystem.primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${diaspoOffer['departure_city']} → ${diaspoOffer['arrival_city']}',
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: AppThemeSystem.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppThemeSystem.grey600,
                      ),
                      onPressed: controller.clearSelectedDiaspoOffer,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),

            // Barre de saisie
            Row(
              children: [
                // Le chat support ne permet pas l'envoi d'images.
                if (!controller.isSupport)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      color: AppThemeSystem.primaryColor,
                      size: 28,
                    ),
                    onPressed: () {
                      _showImageSourceDialog(context);
                    },
                  )
                else
                  const SizedBox.shrink(),
                SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: controller.messageController,
                      // Le clavier réduit le fil par le bas : sans ce
                      // recalage, il recouvrait les derniers messages, ceux
                      // auxquels on s'apprête à répondre.
                      onTap: _scrollToLatestOnceKeyboardIsUp,
                      decoration: InputDecoration(
                        hintText: 'chatdetail.message_hint'.tr,
                        hintStyle: context.textStyle(
                          FontSizeType.body2,
                          color: AppThemeSystem.grey600,
                        ),
                        border: InputBorder.none,
                      ),
                      style: context.textStyle(FontSizeType.body2),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Le bouton reflète l'état du champ : actif seulement quand il
                // y a quelque chose à envoyer.
                Obx(() {
                  final enabled = controller.canSend.value;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppDesign.accent
                          : AppDesign.surfaceMuted(context),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: enabled
                            ? Colors.white
                            : AppDesign.textTertiary(context),
                        size: 22,
                      ),
                      onPressed: enabled ? controller.sendMessage : null,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Ramène le fil au dernier message une fois le clavier monté.
  void _scrollToLatestOnceKeyboardIsUp() {
    Future.delayed(const Duration(milliseconds: 300), () {
      final scroll = controller.scrollController;
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Dialog pour sélectionner la source de l'image
  void _showImageSourceDialog(BuildContext context) {
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
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeSystem.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'chatdetail.image_source.title'.tr,
                  style: context.textStyle(
                    FontSizeType.h6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    context,
                    Icons.camera_alt_rounded,
                    'chatdetail.camera'.tr,
                    AppThemeSystem.primaryColor,
                    () {
                      Get.back();
                      controller.pickImageFromCamera();
                    },
                  ),
                  _buildImageSourceOption(
                    context,
                    Icons.photo_library_rounded,
                    'chatdetail.gallery'.tr,
                    AppDesign.neutral500,
                    () {
                      Get.back();
                      controller.pickImageFromGallery();
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            SizedBox(height: 12),
            Text(
              label,
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog pour sélectionner un produit à taguer
  void _showProductSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('chatdetail.tag_product.title'.tr),
        content: Text(
          'chatdetail.tag_product.message'.tr,
          style: context.textStyle(FontSizeType.body2),
        ),
        actions: [
          if (controller.conversation['product'] != null)
            TextButton(
              onPressed: () {
                controller.selectProduct(controller.conversation['product']);
                Navigator.pop(context);
              },
              child: Text('chatdetail.tag_product.conversation_product'.tr),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('chatdetail.cancel'.tr),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
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
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeSystem.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              _buildMenuItem(
                context,
                Icons.search_rounded,
                'chatdetail.menu.search'.tr,
                () {
                  Get.back();
                  Get.snackbar('chatdetail.menu.search_title'.tr, 'chatdetail.feature_in_progress'.tr);
                },
              ),
              _buildMenuItem(
                context,
                Icons.notifications_off_rounded,
                'chatdetail.menu.mute'.tr,
                () {
                  Get.back();
                  Get.snackbar('chatdetail.menu.notifications_title'.tr, 'chatdetail.menu.notifications_muted'.tr);
                },
              ),
              _buildMenuItem(
                context,
                Icons.block_rounded,
                'chatdetail.menu.block'.tr,
                () {
                  Get.back();
                  Get.snackbar('chatdetail.menu.block_title'.tr, 'chatdetail.menu.user_blocked'.tr);
                },
              ),
              _buildMenuItem(
                context,
                Icons.delete_rounded,
                'chatdetail.menu.delete'.tr,
                () {
                  Get.back(); // Fermer le menu
                  controller.hideConversation(); // Cacher la conversation
                },
                isDestructive: true,
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
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
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppThemeSystem.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Le chat support ne permet pas l'envoi d'images (Photo/Caméra).
                    if (!controller.isSupport)
                      _buildAttachmentOption(
                        context,
                        Icons.image_rounded,
                        'chatdetail.attachment.photo'.tr,
                        AppThemeSystem.primaryColor,
                      ),
                    if (!controller.isSupport)
                      _buildAttachmentOption(
                        context,
                        Icons.camera_alt_rounded,
                        'chatdetail.camera'.tr,
                        AppDesign.neutral500,
                      ),
                    _buildAttachmentOption(
                      context,
                      Icons.insert_drive_file_rounded,
                      'chatdetail.attachment.document'.tr,
                      AppDesign.info,
                    ),
                    _buildAttachmentOption(
                      context,
                      Icons.location_on_rounded,
                      'chatdetail.attachment.location'.tr,
                      AppDesign.success,
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppThemeSystem.errorColor : AppThemeSystem.grey700,
      ),
      title: Text(
        title,
        style: context.textStyle(
          FontSizeType.body1,
          color: isDestructive
              ? AppThemeSystem.errorColor
              : AppThemeSystem.getPrimaryTextColor(context),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Get.back();
        Get.snackbar(label, 'chatdetail.feature_in_progress'.tr);
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: context.textStyle(
              FontSizeType.caption,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget pour afficher le produit comme une citation dans le message (style WhatsApp)
  Widget _buildProductQuote(
    BuildContext context,
    Map<String, dynamic> product,
    bool isSentByMe,
  ) {
    return GestureDetector(
      onTap: () {
        // Naviguer vers la page du produit
        Get.toNamed('/product', arguments: product);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSentByMe
              ? Colors.white.withValues(alpha: 0.2)
              : AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isSentByMe
                  ? Colors.white
                  : AppThemeSystem.primaryColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Image du produit
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildProductImageSmall(product),
            ),
            SizedBox(width: 8),
            // Infos du produit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'chatdetail.product'.tr,
                    style: context.textStyle(
                      FontSizeType.overline,
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    product['name'] ?? 'chatdetail.product'.tr,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.95)
                          : AppThemeSystem.getPrimaryTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatPrice(product),
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Icône
            Icon(
              Icons.chevron_right,
              size: 16,
              color: isSentByMe
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppThemeSystem.grey600,
            ),
          ],
        ),
      ),
    );
  }

  /// Construire petite image du produit (pour citation)
  Widget _buildProductImageSmall(Map<String, dynamic> product) {
    final imageUrl = product['primary_image'] ??
                     (product['images'] is List && (product['images'] as List).isNotEmpty
                         ? product['images'][0]
                         : null) ??
                     product['image'];

    if (imageUrl != null && imageUrl.toString().startsWith('http')) {
      return Image(
        image: AppNetworkImage.provider(
          Get.context!,
          imageUrl.toString(),
          const Size.square(40),
        ),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderSmall(),
      );
    } else if (imageUrl != null) {
      return Image.asset(
        imageUrl.toString(),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderSmall(),
      );
    }

    return _buildPlaceholderSmall();
  }

  Widget _buildPlaceholderSmall() {
    return Container(
      width: 40,
      height: 40,
      color: AppThemeSystem.grey200,
      child: Icon(
        Icons.image_outlined,
        color: AppThemeSystem.grey600,
        size: 20,
      ),
    );
  }

  /// Widget pour afficher le produit taggé (comme sur WhatsApp)
  Widget _buildProductTag(BuildContext context, Map<String, dynamic> product) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Container(
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesign.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Naviguer vers la page du produit
            Get.back(); // Fermer le chat
            Get.toNamed('/product', arguments: product);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Image du produit
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildProductImage(product),
                ),
                SizedBox(width: 12),
                // Infos du produit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge "Produit"
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'chatdetail.product'.tr,
                          style: context.textStyle(
                            FontSizeType.overline,
                            color: AppThemeSystem.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      // Nom du produit
                      Text(
                        product['name'] ?? 'chatdetail.product'.tr,
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // Prix
                      Text(
                        _formatPrice(product),
                        style: context.textStyle(
                          FontSizeType.subtitle2,
                          color: AppThemeSystem.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Icône de redirection
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppThemeSystem.primaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construire l'image du produit
  Widget _buildProductImage(Map<String, dynamic> product) {
    final imageUrl = product['primary_image'] ??
                     (product['images'] is List && (product['images'] as List).isNotEmpty
                         ? product['images'][0]
                         : null) ??
                     product['image'];

    if (imageUrl != null && imageUrl.toString().startsWith('http')) {
      return Image(
        image: AppNetworkImage.provider(
          Get.context!,
          imageUrl.toString(),
          const Size.square(80),
        ),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (imageUrl != null) {
      return Image.asset(
        imageUrl.toString(),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: AppThemeSystem.grey200,
      child: Icon(
        Icons.image_outlined,
        color: AppThemeSystem.grey600,
        size: 32,
      ),
    );
  }

  /// Formater le prix
  String _formatPrice(Map<String, dynamic> product) {
    final price = product['price'];
    if (price != null) {
      final priceValue = price is num ? price.toDouble() : double.tryParse(price.toString());
      if (priceValue != null) {
        return controller.formatPrice(priceValue);
      }
      return '$price ${controller.currencySymbol}';
    }
    return 'chatdetail.price_undefined'.tr;
  }

  /// Widget pour afficher l'offre Diaspo comme une citation dans le message (style WhatsApp)
  /// Widget pour afficher un message système (message d'avertissement de sécurité)
  Widget _buildSystemMessage(BuildContext context, Map<String, dynamic> message) {
    final text = message['text'] as String;
    final parts = text.split('→ En savoir plus');
    final mainText = parts[0].trim();
    final hasLearnMore = parts.length > 1;
    final isDark = AppThemeSystem.isDarkMode(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppDesign.neutral800.withValues(alpha: 0.7),
                      AppDesign.neutral900.withValues(alpha: 0.7),
                    ]
                  : [
                      AppDesign.warningSubtle,
                      AppDesign.warningSubtle,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppThemeSystem.primaryColor.withValues(alpha: 0.3)
                  : AppDesign.warningSubtle,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec badge "Sécurité ASSO"
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppThemeSystem.primaryColor.withValues(alpha: 0.2)
                      : AppDesign.warningSubtle,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'chatdetail.security_title'.tr,
                      style: context.textStyle(
                        FontSizeType.subtitle2,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppThemeSystem.primaryColor
                            : AppDesign.warningText,
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu du message
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Titre principal avec icône d'alerte
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppDesign.warning.withValues(alpha: 0.15)
                                : AppDesign.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: isDark ? AppDesign.warning : AppDesign.warningText,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mainText.split('\n\n')[0],
                            style: context.textStyle(
                              FontSizeType.body1,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppDesign.warning
                                  : AppDesign.warningText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Texte explicatif
                    if (mainText.split('\n\n').length > 1) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppDesign.warningSubtle,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          mainText.split('\n\n').sublist(1).join('\n\n'),
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: AppThemeSystem.getPrimaryTextColor(context),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Footer avec timestamp
              Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppDesign.warningSubtle,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  message['timestamp'] ?? '',
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiaspoOfferQuote(
    BuildContext context,
    Map<String, dynamic> diaspoOffer,
    bool isSentByMe,
  ) {
    return GestureDetector(
      onTap: () {
        // Naviguer vers la page de détails de l'offre Diaspo
        Get.toNamed('/diaspo/detail', arguments: {'offerId': diaspoOffer['id']});
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSentByMe
              ? Colors.white.withValues(alpha: 0.2)
              : AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isSentByMe
                  ? Colors.white
                  : AppThemeSystem.primaryColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Icône de l'offre
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSentByMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.flight,
                color: isSentByMe
                    ? Colors.white
                    : AppThemeSystem.primaryColor,
                size: 24,
              ),
            ),
            SizedBox(width: 8),
            // Infos de l'offre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'chatdetail.diaspo_offer'.tr,
                    style: context.textStyle(
                      FontSizeType.overline,
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${diaspoOffer['departure_city']} → ${diaspoOffer['arrival_city']}',
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.95)
                          : AppThemeSystem.getPrimaryTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${controller.formatPrice(double.tryParse(diaspoOffer['price_per_kg']?.toString() ?? '0') ?? 0)}/kg',
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Icône
            Icon(
              Icons.chevron_right,
              size: 16,
              color: isSentByMe
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppThemeSystem.grey600,
            ),
          ],
        ),
      ),
    );
  }
}
