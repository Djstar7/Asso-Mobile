import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/post.dart';
import '../../../data/providers/post_service.dart';

class MyVoiceController extends GetxController {
  final RxList<Post> posts = <Post>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString loadError = RxnString();
  final RxString sortBy = 'recent'.obs; // 'recent' | 'popular'

  int currentPage = 1;
  final int perPage = 10;

  /// Incrémenté à chaque rafraîchissement : ignore les réponses d'une page
  /// demandée avant un changement de tri ou un rafraîchissement.
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    fetchPosts();
  }

  /// Fetch posts
  Future<void> fetchPosts({bool refresh = false}) async {
    if (refresh) {
      _generation++;
      currentPage = 1;
      hasMore.value = true;
    } else if (isLoading.value || isLoadingMore.value) {
      return;
    }

    final generation = _generation;
    final page = currentPage;
    if (page == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final response = await PostService.getPosts(
        page: page,
        perPage: perPage,
        sort: sortBy.value,
      );
      if (generation != _generation) return;

      final pagination = response.data?['data'];
      if (!response.success || pagination is! Map) {
        loadError.value = response.message.isNotEmpty
            ? response.message
            : 'Impossible de charger les publications';
        return;
      }

      loadError.value = null;
      final newPosts = (pagination['data'] as List? ?? [])
          .map((json) => Post.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      if (page == 1) {
        posts.assignAll(newPosts);
      } else {
        final known = posts.map((p) => p.id).toSet();
        posts.addAll(newPosts.where((p) => !known.contains(p.id)));
      }

      hasMore.value = pagination['next_page_url'] != null;
      currentPage = page + 1;
    } catch (e) {
      if (generation == _generation) {
        loadError.value = 'Impossible de charger les publications';
      }
    } finally {
      if (generation == _generation) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }

  /// Change sorting
  void changeSorting(String newSort) {
    if (sortBy.value == newSort) return;
    sortBy.value = newSort;
    fetchPosts(refresh: true);
  }

  void _snack(String title, String message, {bool error = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: error ? Colors.red : Colors.green,
      colorText: Colors.white,
    );
  }

  /// Publie un message. Retourne true en cas de succès : la feuille de saisie
  /// n'est fermée qu'à ce moment-là, le texte n'est donc jamais perdu.
  Future<bool> createPost({
    required String content,
    bool isAnonymous = false,
  }) async {
    if (isSubmitting.value) return false;
    isSubmitting.value = true;
    try {
      final response = await PostService.createPost(
        content: content,
        isAnonymous: isAnonymous,
      );

      final created = response.data?['data'];
      if (!response.success || created is! Map) {
        _snack(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Impossible de publier le message',
          error: true,
        );
        return false;
      }

      final post = Post.fromJson(Map<String, dynamic>.from(created));
      posts.removeWhere((p) => p.id == post.id);
      if (sortBy.value == 'recent') {
        posts.insert(0, post);
      } else {
        posts.add(post);
      }
      _snack('Succès', 'Votre message a été publié');
      return true;
    } catch (e) {
      _snack('Erreur', 'Impossible de publier le message', error: true);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Modifie un de mes messages.
  Future<bool> updatePost(Post post, String content) async {
    if (isSubmitting.value) return false;
    isSubmitting.value = true;
    try {
      final response = await PostService.updatePost(id: post.id, content: content);
      final updated = response.data?['data'];
      if (!response.success || updated is! Map) {
        _snack(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Modification impossible',
          error: true,
        );
        return false;
      }
      updatePostInList(Post.fromJson(Map<String, dynamic>.from(updated)));
      _snack('Succès', 'Message modifié');
      return true;
    } catch (_) {
      _snack('Erreur', 'Modification impossible', error: true);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Supprime un de mes messages après confirmation.
  Future<void> deletePost(int postId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer le message ?'),
        content: const Text('Il sera retiré du fil avec ses commentaires.'),
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
      final response = await PostService.deletePost(postId);
      if (response.success) {
        posts.removeWhere((post) => post.id == postId);
        _snack('Succès', 'Message supprimé');
      } else {
        _snack(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Suppression impossible',
          error: true,
        );
      }
    } catch (e) {
      _snack('Erreur', 'Suppression impossible', error: true);
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

      final data = response.data?['data'];
      if (response.success && data is Map) {
        final index = posts.indexWhere((post) => post.id == postId);
        if (index != -1) {
          posts[index] = posts[index].withReaction(data);
        }
      } else if (!response.success) {
        _snack('Erreur', response.message, error: true);
      }
    } catch (e) {
      _snack('Erreur', 'Impossible de réagir au message', error: true);
    }
  }

  /// Load more posts
  void loadMore() {
    if (!isLoading.value && !isLoadingMore.value && hasMore.value) {
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
