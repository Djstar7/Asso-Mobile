import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/post.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/providers/post_service.dart';

class MyVoiceController extends GetxController {
  final RxList<Post> posts = <Post>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxString sortBy = 'recent'.obs; // 'recent' | 'popular'

  int currentPage = 1;
  final int perPage = 10;

  @override
  void onInit() {
    super.onInit();
    fetchPosts();
  }

  /// Fetch posts
  Future<void> fetchPosts({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      hasMore.value = true;
    }

    if (currentPage == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final response = await PostService.getPosts(
        page: currentPage,
        perPage: perPage,
        sort: sortBy.value,
      );

      if (response.success && response.data != null) {
        // La réponse contient un objet de pagination Laravel enveloppé
        final pagination = response.data?['data'];
        final data = pagination['data'] as List;

        // 🔍 LOG: Afficher la réponse brute
        print('📦 RESPONSE DATA: ${response.data}');
        print('📋 POSTS COUNT: ${data.length}');

        final newPosts = data.map((json) {
          // 🔍 LOG: Afficher chaque post reçu
          print('🔍 POST JSON: $json');
          print('   - is_anonymous: ${json['is_anonymous']}');
          print('   - is_my_post: ${json['is_my_post']}');
          print('   - user: ${json['user']}');

          final post = Post.fromJson(json);

          // 🔍 LOG: Afficher le post parsé
          print('✅ POST PARSED:');
          print('   - isAnonymous: ${post.isAnonymous}');
          print('   - isMyPost: ${post.isMyPost}');
          print('   - user.firstName: ${post.user?.firstName}');
          print('   - user.avatar: ${post.user?.avatar}');

          return post;
        }).toList();

        if (refresh || currentPage == 1) {
          posts.value = newPosts;
        } else {
          posts.addAll(newPosts);
        }

        // Vérifier s'il y a plus de pages
        final nextPageUrl = pagination['next_page_url'];
        hasMore.value = nextPageUrl != null;
        currentPage++;
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger les posts',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Change sorting
  void changeSorting(String newSort) {
    sortBy.value = newSort;
    fetchPosts(refresh: true);
  }

  /// Create a new post
  Future<void> createPost({
    required String content,
    bool isAnonymous = false,
  }) async {
    try {
      final response = await PostService.createPost(
        content: content,
        isAnonymous: isAnonymous,
      );

      if (response.success && response.data != null) {
        Get.back();

        // Refresh the posts list to get the latest data
        await fetchPosts(refresh: true);

        Get.snackbar(
          'Succès',
          'Votre post a été créé avec succès',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de créer le post',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Delete a post
  Future<void> deletePost(int postId) async {
    try {
      final response = await PostService.deletePost(postId);

      if (response.success) {
        posts.removeWhere((post) => post.id == postId);

        Get.snackbar(
          'Succès',
          'Post supprimé avec succès',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de supprimer le post',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// React to a post (like/dislike)
  Future<void> reactToPost({
    required int postId,
    required String type, // 'like' | 'dislike'
  }) async {
    try {
      final response = await PostService.reactToPost(
        id: postId,
        type: type,
      );

      if (response.success && response.data != null) {
        final data = response.data?['data'];
        final index = posts.indexWhere((post) => post.id == postId);

        if (index != -1) {
          posts[index] = posts[index].copyWith(
            likesCount: data['likes_count'],
            dislikesCount: data['dislikes_count'],
            userReaction: data['user_reaction'],
            isLiked: data['user_reaction'] == 'like',
            isDisliked: data['user_reaction'] == 'dislike',
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de réagir au post',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Load more posts
  void loadMore() {
    if (!isLoadingMore.value && hasMore.value) {
      fetchPosts();
    }
  }

  /// Update a post in the list (e.g., after returning from post detail)
  void updatePostInList(Post updatedPost) {
    final index = posts.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      posts[index] = updatedPost;
    }
  }

  /// Refresh posts
  @override
  Future<void> refresh() async {
    await fetchPosts(refresh: true);
  }
}
