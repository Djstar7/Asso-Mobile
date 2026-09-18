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
    final arguments = Map<String, dynamic>.from(Get.arguments as Map);
    postId = arguments['postId'] as int;

    // If post object is passed, use it
    final passedPost = arguments['post'];
    if (passedPost is Post) {
      post.value = passedPost;
    } else {
      fetchPostDetails();
    }

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

  /// Envoi en cours (désactive le bouton « Publier »)
  final RxBool isSubmitting = false.obs;

  void _applyCommentsCount(dynamic serverCount, {int fallbackDelta = 0}) {
    final current = post.value;
    if (current == null) return;
    final count = serverCount is num
        ? serverCount.toInt()
        : (current.commentsCount + fallbackDelta).clamp(0, 1 << 31);
    post.value = current.copyWith(commentsCount: count);
  }

  void _showError(String message) {
    Get.snackbar(
      'Erreur',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  /// Ajoute un commentaire (ou une réponse si [parentId]). Retourne true si
  /// l'envoi a réussi : la feuille de saisie n'est fermée qu'à ce moment-là,
  /// pour ne jamais perdre le texte saisi.
  Future<bool> createComment({
    required String content,
    bool isAnonymous = false,
    int? parentId,
  }) async {
    if (isSubmitting.value) return false;
    isSubmitting.value = true;
    try {
      final response = await PostService.createComment(
        postId: postId,
        content: content,
        isAnonymous: isAnonymous,
        parentId: parentId,
      );

      if (!response.success) {
        _showError(response.message.isNotEmpty
            ? response.message
            : 'Impossible d\'ajouter le commentaire');
        return false;
      }

      _applyCommentsCount(response.data?['comments_count'], fallbackDelta: 1);
      await fetchComments();

      Get.snackbar(
        'Succès',
        parentId == null ? 'Commentaire ajouté' : 'Réponse ajoutée',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      _showError('Impossible d\'ajouter le commentaire');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Supprime un de mes commentaires (et ses réponses).
  Future<void> deleteComment(PostComment comment) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer le commentaire ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await PostService.deleteComment(postId: postId, commentId: comment.id);
      if (!response.success) {
        _showError(response.message.isNotEmpty ? response.message : 'Suppression impossible');
        return;
      }
      _applyCommentsCount(
        response.data?['comments_count'],
        fallbackDelta: -(1 + (comment.replies?.length ?? 0)),
      );
      await fetchComments();
    } catch (_) {
      _showError('Suppression impossible');
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
        if (data is Map) post.value = post.value!.withReaction(data);
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
