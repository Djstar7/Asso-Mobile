import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:asso/app/core/values/constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../controllers/my_voice_controller.dart';
import '../../../data/models/post.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

class MyVoiceView extends GetView<MyVoiceController> {
  const MyVoiceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: Obx(() {
        final posts = controller.posts;
        final loading = controller.isLoading.value && posts.isEmpty;

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: AppDesign.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Invite à publier, en tête de fil : c'est ainsi qu'on lit un
              // réseau social — on voit d'abord ce qu'on peut y écrire.
              SliverToBoxAdapter(child: _buildComposer(context)),
              SliverToBoxAdapter(child: _buildSortBar(context)),

              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty(context))
              else
                SliverList.separated(
                  itemCount: posts.length + 1,
                  separatorBuilder: (_, _) => SizedBox(height: AppDesign.space3),
                  itemBuilder: (context, index) {
                    if (index == posts.length) {
                      return _buildFooter(context);
                    }
                    return _buildPostCard(context, posts[index]);
                  },
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Zone d'appel à publier.
  Widget _buildComposer(BuildContext context) {
    return Container(
      color: context.ds.surface,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space3,
        context.ds.gutter,
        AppDesign.space3,
      ),
      child: Row(
        children: [
          _Avatar(name: controller.currentUserInitials, size: 40),
          SizedBox(width: AppDesign.space3),
          Expanded(
            child: Material(
              color: context.ds.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              child: InkWell(
                onTap: () => _showCreatePostDialog(context),
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                child: Container(
                  height: AppDesign.minTapTarget,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: AppDesign.space4),
                  child: Text(
                    'Partagez votre avis sur ASSO…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: context.ds.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bascule entre fil chronologique et fil populaire.
  Widget _buildSortBar(BuildContext context) {
    const options = {'recent': 'Récents', 'popular': 'Populaires'};

    return Container(
      color: context.ds.surface,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        0,
        context.ds.gutter,
        AppDesign.space3,
      ),
      child: Obx(
        () => Row(
          children: [
            for (final entry in options.entries) ...[
              _SortChip(
                label: entry.value,
                selected: controller.sortBy.value == entry.key,
                onTap: () => controller.changeSorting(entry.key),
              ),
              SizedBox(width: AppDesign.space2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final error = controller.loadError.value;
    return AppEmptyState(
      icon: error != null ? Icons.cloud_off_outlined : Icons.forum_outlined,
      title: error != null
          ? 'Fil indisponible'
          : 'Personne n’a encore pris la parole',
      message: error ??
          'Posez une question, signalez un problème ou partagez une bonne expérience.',
      actionLabel: error != null ? 'Réessayer' : 'Écrire un message',
      onAction: error != null
          ? controller.refresh
          : () => _showCreatePostDialog(context),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space6),
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (!controller.hasMore.value && controller.posts.isNotEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space6),
          child: Center(
            child: Text(
              'Vous avez tout lu.',
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textTertiary,
              ),
            ),
          ),
        );
      }
      // Charge la page suivante dès que le pied de liste est construit.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
      return SizedBox(height: AppDesign.space10);
    });
  }

  /// Carte d'un message du fil.
  Widget _buildPostCard(BuildContext context, Post post) {
    final anonymous = post.isAnonymous && !post.isMyPost;
    final author = anonymous
        ? 'Membre anonyme'
        : (post.user == null
            ? 'Membre ASSO'
            : '${post.user!.firstName} ${post.user!.lastName}'.trim());

    return Container(
      color: context.ds.surface,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: anonymous ? '?' : author, size: 40),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.body2,
                              fontWeight: FontWeight.w600,
                              color: context.ds.textPrimary,
                            ),
                          ),
                        ),
                        if (post.isMyPost) ...[
                          SizedBox(width: AppDesign.space2),
                          const AppBadge(label: 'VOUS', tone: AppBadgeTone.accent),
                        ],
                      ],
                    ),
                    Text(
                      timeago.format(post.createdAt, locale: 'fr'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.overline,
                        color: context.ds.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.isMyPost)
                _PostMenu(
                  onEdit: () => _showCreatePostDialog(context, editing: post),
                  onDelete: () => controller.deletePost(post.id),
                ),
            ],
          ),
          SizedBox(height: AppDesign.space3),
          Text(
            post.content,
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textPrimary,
              height: 1.55,
            ),
          ),
          SizedBox(height: AppDesign.space2),
          Row(
            children: [
              _ReactionButton(
                icon: post.isLiked
                    ? Icons.thumb_up_rounded
                    : Icons.thumb_up_outlined,
                count: post.likesCount,
                active: post.isLiked,
                onTap: () =>
                    controller.reactToPost(postId: post.id, type: 'like'),
              ),
              _ReactionButton(
                icon: post.isDisliked
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
                count: post.dislikesCount,
                active: post.isDisliked,
                onTap: () =>
                    controller.reactToPost(postId: post.id, type: 'dislike'),
              ),
              _ReactionButton(
                icon: Icons.mode_comment_outlined,
                count: post.commentsCount,
                onTap: () => _openDetail(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(Post post) async {
    final result = await Get.toNamed(
      '/post-detail',
      arguments: {'postId': post.id, 'post': post},
    );
    if (result is Post) {
      controller.updatePostInList(result);
    }
  }

  void _showCreatePostDialog(BuildContext context, {Post? editing}) {
    final TextEditingController contentController =
        TextEditingController(text: editing?.content ?? '');
    final RxBool isAnonymous = false.obs;
    final isDark = AppThemeSystem.isDarkMode(context);

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editing == null ? 'Nouveau message' : 'Modifier le message',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  maxLength: 5000,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Partagez votre avis sur ASSO...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? AppThemeSystem.grey700 : Colors.grey,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? AppThemeSystem.grey700 : Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppThemeSystem.primaryColor,
                        width: 2,
                      ),
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                if (editing == null) Obx(
                  () => CheckboxListTile(
                    title: Text(
                      'Publier en mode anonyme',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Votre nom ne sera pas visible',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    value: isAnonymous.value,
                    onChanged: (value) => isAnonymous.value = value ?? false,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Obx(() => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () async {
                            final content = contentController.text.trim();
                            if (content.length < 2) {
                              Get.snackbar(
                                'Message trop court',
                                'Écrivez quelques mots avant de publier.',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }
                            final ok = editing == null
                                ? await controller.createPost(
                                    content: content,
                                    isAnonymous: isAnonymous.value,
                                  )
                                : await controller.updatePost(editing, content);
                            if (ok && (Get.isBottomSheetOpen ?? false)) {
                              Get.back();
                            }
                          },
                    child: controller.isSubmitting.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            editing == null ? 'Publier' : 'Enregistrer',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  )),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}


/// Pastille d'identité, construite sur les initiales.
///
/// L'API ne renvoie pas encore de photo de profil ; des initiales sur fond
/// teinté valent mieux qu'une silhouette générique répétée à chaque message.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 40});

  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppDesign.accentSubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: context.textStyle(
          FontSizeType.caption,
          fontWeight: FontWeight.w700,
          color: AppDesign.accentText,
        ),
      ),
    );
  }
}

/// Filtre du fil (récents / populaires).
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppDesign.accentSubtle : context.ds.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: AppDesign.space4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            border: Border.all(
              color: selected ? AppDesign.accentBorder : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: context.textStyle(
              FontSizeType.caption,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppDesign.accentText : context.ds.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton de réaction : icône, compteur, état actif.
class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppDesign.accent : context.ds.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: Container(
          // Cible tactile confortable : ces boutons sont les plus sollicités
          // du fil.
          height: AppDesign.minTapTarget,
          padding: EdgeInsets.symmetric(horizontal: AppDesign.space3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: context.textStyle(
                    FontSizeType.caption,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu contextuel d'un message dont on est l'auteur.
class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: context.ds.textTertiary),
      tooltip: 'Options',
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Supprimer',
            style: TextStyle(color: AppDesign.danger),
          ),
        ),
      ],
    );
  }
}
