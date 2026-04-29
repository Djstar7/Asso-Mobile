import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:asso/app/core/values/constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../controllers/post_detail_controller.dart';
import '../../../data/models/post_comment.dart';

class PostDetailView extends GetView<PostDetailController> {
  const PostDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return WillPopScope(
      onWillPop: () async {
        // Return the updated post when going back
        Get.back(result: controller.post.value);
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : Colors.grey[100],
        appBar: AppBar(
          title: const Text('Discussion'),
          backgroundColor: isDark ? AppThemeSystem.darkCardColor : AppThemeSystem.primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Return the updated post when pressing back button
              Get.back(result: controller.post.value);
            },
          ),
        ),
        body: Obx(() {
        if (controller.isLoading.value && controller.post.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final post = controller.post.value;
        if (post == null) {
          return const Center(child: Text('Post introuvable'));
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post card
                _buildPostCard(context, post),

                const Divider(height: 1),

                // Comments section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Commentaires (${post.commentsCount})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_comment),
                        onPressed: () => _showAddCommentDialog(context),
                        color: AppThemeSystem.primaryColor,
                      ),
                    ],
                  ),
                ),

                // Comments list
                Obx(() {
                  if (controller.isLoadingComments.value) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (controller.comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.comment_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Aucun commentaire',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.comments.length,
                    itemBuilder: (context, index) {
                      final comment = controller.comments[index];
                      return _buildCommentCard(context, comment);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      }),
      ),
    );
  }

  /// Build post card
  Widget _buildPostCard(BuildContext context, post) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: (post.isAnonymous && !post.isMyPost)
                      ? Colors.grey[400]
                      : AppThemeSystem.primaryColor,
                  backgroundImage: post.user?.avatar != null && !(post.isAnonymous && !post.isMyPost)
                      ? NetworkImage(_buildAvatarUrl(post.user!.avatar!))
                      : null,
                  child: post.user?.avatar == null || (post.isAnonymous && !post.isMyPost)
                      ? Text(
                          (post.isAnonymous && !post.isMyPost)
                              ? '?'
                              : (post.user?.firstName[0].toUpperCase() ?? '?'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            (post.isAnonymous && !post.isMyPost)
                                ? 'ANONYME'
                                : (post.user?.fullName ?? 'Anonyme'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (post.isAnonymous && post.isMyPost) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeSystem.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Anonyme',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        timeago.format(post.createdAt, locale: 'fr'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Text(
              post.content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),

            // Actions (like, dislike, comment)
            Row(
              children: [
                // Like button
                InkWell(
                  onTap: () => controller.reactToPost(type: 'like'),
                  child: Row(
                    children: [
                      Icon(
                        post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 20,
                        color: post.isLiked ? AppThemeSystem.primaryColor : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(
                          color: post.isLiked ? AppThemeSystem.primaryColor : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Dislike button
                InkWell(
                  onTap: () => controller.reactToPost(type: 'dislike'),
                  child: Row(
                    children: [
                      Icon(
                        post.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                        size: 20,
                        color: post.isDisliked ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.dislikesCount}',
                        style: TextStyle(
                          color: post.isDisliked ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Comment count
                Row(
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build comment card
  Widget _buildCommentCard(BuildContext context, PostComment comment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (comment.isAnonymous && !comment.isMyComment)
                      ? Colors.grey[400]
                      : AppThemeSystem.primaryColor,
                  backgroundImage: comment.user?.avatar != null && !(comment.isAnonymous && !comment.isMyComment)
                      ? NetworkImage(_buildAvatarUrl(comment.user!.avatar!))
                      : null,
                  child: comment.user?.avatar == null || (comment.isAnonymous && !comment.isMyComment)
                      ? Text(
                          (comment.isAnonymous && !comment.isMyComment)
                              ? '?'
                              : (comment.user?.firstName[0].toUpperCase() ?? '?'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            (comment.isAnonymous && !comment.isMyComment)
                                ? 'ANONYME'
                                : (comment.user?.fullName ?? 'Anonyme'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (comment.isAnonymous && comment.isMyComment) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeSystem.primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Anonyme',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        timeago.format(comment.createdAt, locale: 'fr'),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content
            Text(
              comment.content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),

            // Like button
            InkWell(
              onTap: () => controller.reactToComment(comment.id),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    comment.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 16,
                    color: comment.isLiked ? AppThemeSystem.primaryColor : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${comment.likesCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: comment.isLiked ? AppThemeSystem.primaryColor : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Replies (if any)
            if (comment.replies != null && comment.replies!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(left: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comment.replies!.map((reply) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (reply.isAnonymous && !reply.isMyComment)
                                    ? 'ANONYME'
                                    : (reply.user?.fullName ?? 'Anonyme'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '· ${timeago.format(reply.createdAt, locale: 'fr')}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reply.content,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build avatar URL
  String _buildAvatarUrl(String avatar) {
    if (avatar.startsWith('http')) {
      return avatar;
    }
    final cleanAvatar = avatar.startsWith('/') ? avatar.substring(1) : avatar;
    return '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/$cleanAvatar';
  }

  /// Show add comment dialog
  void _showAddCommentDialog(BuildContext context) {
    final TextEditingController contentController = TextEditingController();
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
                      'Ajouter un commentaire',
                      style: TextStyle(
                        fontSize: 18,
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
                  maxLines: 4,
                  maxLength: 2000,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Écrivez votre commentaire...',
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
                Obx(
                  () => CheckboxListTile(
                    title: Text(
                      'Commenter en mode anonyme',
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final content = contentController.text.trim();
                      if (content.isNotEmpty) {
                        controller.createComment(
                          content: content,
                          isAnonymous: isAnonymous.value,
                        );
                      }
                    },
                    child: const Text(
                      'Publier',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
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
