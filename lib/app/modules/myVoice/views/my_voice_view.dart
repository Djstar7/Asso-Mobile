import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:asso/app/core/values/constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../controllers/my_voice_controller.dart';
import '../../../data/models/post.dart';

class MyVoiceView extends GetView<MyVoiceController> {
  const MyVoiceView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : Colors.grey[100],
      body: Column(
        children: [
          // Content
          Expanded(
            child: Obx(() {
        if (controller.isLoading.value && controller.posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun post pour le moment',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount:
                controller.posts.length +
                (controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.posts.length) {
                controller.loadMore();
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final post = controller.posts[index];
              return _buildPostCard(context, post);
            },
          ),
        );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau post'),
        backgroundColor: AppThemeSystem.primaryColor,
      ),
    );
  }

  /// Build full avatar URL
  String _buildAvatarUrl(String avatar) {
    if (avatar.startsWith('http')) {
      return avatar;
    }
    // Remove leading slash if present
    final cleanAvatar = avatar.startsWith('/') ? avatar.substring(1) : avatar;
    return '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/$cleanAvatar';
  }

  Widget _buildPostCard(BuildContext context, Post post) {
    // 🔍 LOG: Afficher les infos du post dans la vue
    print('🎨 RENDERING POST ${post.id}:');
    print('   - isAnonymous: ${post.isAnonymous}');
    print('   - isMyPost: ${post.isMyPost}');
    print('   - userName: ${post.user?.fullName}');
    print('   - Should show badge: ${post.isAnonymous && post.isMyPost}');
    print('   - Should mask identity: ${post.isAnonymous && !post.isMyPost}');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec avatar et nom
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
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
                          // Afficher le badge "Anonyme" uniquement sur MES posts anonymes
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
            const SizedBox(height: 12),

            // Content
            Text(
              post.content,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Actions (like, dislike, comment)
            Row(
              children: [
                // Like button
                InkWell(
                  onTap: () =>
                      controller.reactToPost(postId: post.id, type: 'like'),
                  child: Row(
                    children: [
                      Icon(
                        post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 20,
                        color: post.isLiked
                            ? AppThemeSystem.primaryColor
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(
                          color: post.isLiked
                              ? AppThemeSystem.primaryColor
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Dislike button
                InkWell(
                  onTap: () =>
                      controller.reactToPost(postId: post.id, type: 'dislike'),
                  child: Row(
                    children: [
                      Icon(
                        post.isDisliked
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
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

                // Comment button
                InkWell(
                  onTap: () async {
                    final result = await Get.toNamed(
                      '/post-detail',
                      arguments: {
                        'postId': post.id,
                        'post': post,
                      },
                    );

                    // Update post with latest data if returned
                    if (result != null && result is Post) {
                      controller.updatePostInList(result);
                    }
                  },
                  child: Row(
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
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
                      'Nouveau post',
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
                Obx(
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
                        controller.createPost(
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
