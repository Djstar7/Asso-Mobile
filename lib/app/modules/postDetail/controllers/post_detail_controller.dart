import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/post.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/providers/post_service.dart';

class PostDetailController extends GetxController {
  final Rx<Post?> post = Rx<Post?>(null);
  final RxList<PostComment> comments = <PostComment>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingComments = false.obs;

  late final int postId;

  @override
  void onInit() {
    super.onInit();
    // Get post ID from arguments
    postId = Get.arguments['postId'] as int;

    // If post object is passed, use it
    if (Get.arguments['post'] != null) {
      post.value = Get.arguments['post'] as Post;
    }

    fetchPostDetails();
    fetchComments();
  }

  /// Fetch post details
  Future<void> fetchPostDetails() async {
    isLoading.value = true;
    try {
      final response = await PostService.getPost(postId);

      if (response.success && response.data != null) {
        post.value = Post.fromJson(response.data?['data']);
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger le post',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch comments for the post
  Future<void> fetchComments() async {
    isLoadingComments.value = true;
    try {
      final response = await PostService.getComments(postId);

      if (response.success && response.data != null) {
        final data = response.data?['data'] as List;
        comments.value = data.map((json) => PostComment.fromJson(json)).toList();
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger les commentaires',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingComments.value = false;
    }
  }

  /// Create a comment
  Future<void> createComment({
    required String content,
    bool isAnonymous = false,
    int? parentId,
  }) async {
    try {
      final response = await PostService.createComment(
        postId: postId,
        content: content,
        isAnonymous: isAnonymous,
        parentId: parentId,
      );

      if (response.success && response.data != null) {
        Get.back(); // Close bottom sheet

        // Refresh comments
        await fetchComments();

        // Update comment count in post
        if (post.value != null) {
          post.value = post.value!.copyWith(
            commentsCount: post.value!.commentsCount + 1,
          );
        }

        Get.snackbar(
          'Succès',
          'Commentaire ajouté avec succès',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible d\'ajouter le commentaire',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// React to a comment (like)
  Future<void> reactToComment(int commentId) async {
    try {
      final response = await PostService.reactToComment(
        postId: postId,
        commentId: commentId,
      );

      if (response.success && response.data != null) {
        final data = response.data?['data'];
        final index = comments.indexWhere((comment) => comment.id == commentId);

        if (index != -1) {
          comments[index] = comments[index].copyWith(
            likesCount: data['likes_count'],
            userReaction: data['user_reaction'],
            isLiked: data['user_reaction'] == 'like',
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de réagir au commentaire',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// React to the post (like/dislike)
  Future<void> reactToPost({required String type}) async {
    if (post.value == null) return;

    try {
      final response = await PostService.reactToPost(
        id: postId,
        type: type,
      );

      if (response.success && response.data != null) {
        final data = response.data?['data'];
        post.value = post.value!.copyWith(
          likesCount: data['likes_count'],
          dislikesCount: data['dislikes_count'],
          userReaction: data['user_reaction'],
          isLiked: data['user_reaction'] == 'like',
          isDisliked: data['user_reaction'] == 'dislike',
        );
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

  /// Refresh data
  @override
  Future<void> refresh() async {
    await Future.wait([
      fetchPostDetails(),
      fetchComments(),
    ]);
  }
}
