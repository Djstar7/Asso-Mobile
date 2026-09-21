import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../controllers/my_voice_controller.dart';
import '../../../data/models/post.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

/// Limite acceptée par l'API (PostController::MAX_CONTENT_LENGTH).
const int _maxPostLength = 5000;

class MyVoiceView extends GetView<MyVoiceController> {
  const MyVoiceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      // La rubrique s'ouvre depuis le menu latéral et non plus comme onglet :
      // il lui faut son propre en-tête, sans quoi on ne peut plus en sortir.
      appBar: AppBar(
        backgroundColor: context.ds.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: context.ds.border)),
        title: Text(
          'Ma voix',
          style: context.textStyle(
            FontSizeType.h6,
            fontWeight: FontWeight.w700,
            color: context.ds.textPrimary,
          ),
        ),
      ),
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
                  separatorBuilder: (_, _) =>
                      SizedBox(height: AppDesign.space3),
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
      message:
          error ??
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.loadMore(),
      );
      return SizedBox(height: AppDesign.space10);
    });
  }

  /// Carte d'un message du fil.
  Widget _buildPostCard(BuildContext context, Post post) {
    // Un message anonyme reste anonyme y compris pour son auteur : le serveur
    // lui renvoie son propre profil, mais l'afficher ferait croire que le nom
    // est public. Le badge « Vous » suffit à s'y reconnaître.
    final anonymous = post.isAnonymous;
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
                        // Sur un message anonyme, « Vous » seul laisserait
                        // croire que le nom est visible : les deux badges se
                        // complètent.
                        if (anonymous) ...[
                          SizedBox(width: AppDesign.space2),
                          const AppBadge(
                            label: 'ANONYME',
                            tone: AppBadgeTone.neutral,
                          ),
                        ],
                        if (post.isMyPost) ...[
                          SizedBox(width: AppDesign.space2),
                          const AppBadge(
                            label: 'VOUS',
                            tone: AppBadgeTone.accent,
                          ),
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
          // Le texte ouvre la discussion : sur un fil social, on s'attend à
          // pouvoir toucher le message lui-même, pas seulement l'icône.
          InkWell(
            onTap: () => _openDetail(post),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppDesign.space1),
              child: Text(
                post.content,
                style: context.textStyle(
                  FontSizeType.body2,
                  color: context.ds.textPrimary,
                  height: 1.55,
                ),
              ),
            ),
          ),
          SizedBox(height: AppDesign.space1),
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
                // Un fil sans commentaire doit inviter à en écrire le premier.
                label: post.commentsCount == 0 ? 'Commenter' : null,
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

  /// Feuille de rédaction d'un message.
  ///
  /// Le mode anonyme y est présenté comme un choix visible — bascule, avatar et
  /// nom d'auteur changent ensemble — pour qu'on sache sous quelle identité on
  /// s'apprête à publier avant d'appuyer sur « Publier ».
  void _showCreatePostDialog(BuildContext context, {Post? editing}) {
    final contentController = TextEditingController(
      text: editing?.content ?? '',
    );
    // Une modification ne peut pas changer l'anonymat : on conserve celui du
    // message d'origine et la bascule n'est pas proposée.
    final isAnonymous = (editing?.isAnonymous ?? false).obs;
    final charCount = (editing?.content.length ?? 0).obs;
    final isEditing = editing != null;

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.ds.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDesign.radiusLg),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.ds.gutter,
                  AppDesign.space2,
                  context.ds.gutter,
                  AppDesign.space4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poignée : signale une feuille que l'on peut faire glisser.
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: EdgeInsets.only(bottom: AppDesign.space4),
                        decoration: BoxDecoration(
                          color: context.ds.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          isEditing ? 'Modifier le message' : 'Nouveau message',
                          style: context.textStyle(
                            FontSizeType.h6,
                            fontWeight: FontWeight.w700,
                            color: context.ds.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        AppIconButton(
                          icon: Icons.close_rounded,
                          onPressed: Get.back,
                          tooltip: 'Fermer',
                        ),
                      ],
                    ),
                    SizedBox(height: AppDesign.space4),

                    // Identité de publication : ce que les autres verront.
                    Obx(
                      () => Row(
                        children: [
                          _Avatar(
                            name: isAnonymous.value
                                ? '?'
                                : controller.currentUserInitials,
                            size: 36,
                          ),
                          SizedBox(width: AppDesign.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isAnonymous.value
                                      ? 'Membre anonyme'
                                      : controller.currentUserInitials,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    fontWeight: FontWeight.w600,
                                    color: context.ds.textPrimary,
                                  ),
                                ),
                                Text(
                                  isAnonymous.value
                                      ? 'Votre nom restera masqué'
                                      : 'Publié sous votre nom',
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
                          if (isAnonymous.value)
                            const AppBadge(
                              label: 'ANONYME',
                              tone: AppBadgeTone.neutral,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppDesign.space4),

                    AppTextField(
                      controller: contentController,
                      hint: 'Partagez votre avis sur ASSO…',
                      maxLines: 6,
                      onChanged: (value) => charCount.value = value.length,
                    ),
                    SizedBox(height: AppDesign.space2),

                    // Le compteur n'apparaît qu'à l'approche de la limite :
                    // affiché en permanence, il pousse à écrire court.
                    Obx(() {
                      final remaining = _maxPostLength - charCount.value;
                      if (remaining > 500) return const SizedBox.shrink();
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$remaining',
                          style: context.textStyle(
                            FontSizeType.caption,
                            fontWeight: FontWeight.w600,
                            color: remaining < 0
                                ? AppDesign.danger
                                : context.ds.textTertiary,
                          ),
                        ),
                      );
                    }),

                    if (!isEditing) ...[
                      SizedBox(height: AppDesign.space2),
                      Obx(
                        () => _AnonymousToggle(
                          value: isAnonymous.value,
                          onChanged: (v) => isAnonymous.value = v,
                        ),
                      ),
                    ],
                    SizedBox(height: AppDesign.space4),

                    Obx(() {
                      final length = charCount.value;
                      final valid = length >= 2 && length <= _maxPostLength;
                      return AppButton(
                        label: isEditing ? 'Enregistrer' : 'Publier',
                        isLoading: controller.isSubmitting.value,
                        // Bouton inerte tant que le message est invalide :
                        // plus clair qu'un refus après coup.
                        onPressed: valid
                            ? () async {
                                final content = contentController.text.trim();
                                final ok = isEditing
                                    ? await controller.updatePost(
                                        editing,
                                        content,
                                      )
                                    : await controller.createPost(
                                        content: content,
                                        isAnonymous: isAnonymous.value,
                                      );
                                if (ok && (Get.isBottomSheetOpen ?? false)) {
                                  Get.back();
                                }
                              }
                            : null,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille d'identité, construite sur les initiales.
///
/// L'API ne renvoie pas encore de photo de profil ; des initiales sur fond
/// teinté valent mieux qu'une silhouette générique répétée à chaque message.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 40});

  /// « ? » marque un auteur anonyme : la pastille prend alors une teinte
  /// neutre, pour ne pas ressembler à un profil identifié.
  final String name;
  final double size;

  bool get _isAnonymous => name.trim() == '?';

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
      decoration: BoxDecoration(
        color: _isAnonymous ? context.ds.surfaceMuted : AppDesign.accentSubtle,
        shape: BoxShape.circle,
        border: _isAnonymous ? Border.all(color: context.ds.border) : null,
      ),
      child: _isAnonymous
          ? Icon(
              Icons.visibility_off_rounded,
              size: size * 0.45,
              color: context.ds.textSecondary,
            )
          : Text(
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
    this.label,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool active;

  /// Affiché à la place du compteur quand celui-ci vaut zéro.
  final String? label;

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
              if (count > 0 || label != null) ...[
                const SizedBox(width: 6),
                Text(
                  count > 0 ? '$count' : label!,
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
          child: Text('Supprimer', style: TextStyle(color: AppDesign.danger)),
        ),
      ],
    );
  }
}

/// Bascule du mode anonyme.
///
/// Une case à cocher se remarque peu pour un choix qui engage l'identité :
/// l'encart se teinte et se borde quand il est actif, de sorte que l'état se
/// lise d'un coup d'œil avant de publier.
class _AnonymousToggle extends StatelessWidget {
  const _AnonymousToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? AppDesign.accentSubtle : context.ds.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            border: Border.all(
              color: value ? AppDesign.accentBorder : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
                color: value ? AppDesign.accentText : context.ds.textSecondary,
              ),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Text(
                  'Publier en mode anonyme',
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w600,
                    color: value
                        ? AppDesign.accentText
                        : context.ds.textPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppDesign.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
