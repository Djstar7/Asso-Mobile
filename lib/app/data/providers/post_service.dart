import 'api_provider.dart';

class PostService {
  static const String postsUrl = '/v1/posts';

  /// Get posts with pagination and sorting
  static Future<ApiResponse> getPosts({
    int page = 1,
    int perPage = 20,
    String sort = 'recent', // recent | popular
  }) async {
    return await ApiProvider.get(postsUrl, queryParams: {
      'page': page,
      'per_page': perPage,
      'sort': sort,
    });
  }

  /// Get my posts
  static Future<ApiResponse> getMyPosts({
    int page = 1,
    int perPage = 20,
  }) async {
    return await ApiProvider.get('$postsUrl/my-posts', queryParams: {
      'page': page,
      'per_page': perPage,
    });
  }

  /// Get single post details
  static Future<ApiResponse> getPost(int id) async {
    return await ApiProvider.get('$postsUrl/$id');
  }

  /// Create a new post
  static Future<ApiResponse> createPost({
    required String content,
    bool isAnonymous = false,
  }) async {
    return await ApiProvider.post(postsUrl, body: {
      'content': content,
      'is_anonymous': isAnonymous,
    });
  }

  /// Update a post
  static Future<ApiResponse> updatePost({
    required int id,
    required String content,
  }) async {
    return await ApiProvider.put('$postsUrl/$id', body: {
      'content': content,
    });
  }

  /// Delete a post
  static Future<ApiResponse> deletePost(int id) async {
    return await ApiProvider.delete('$postsUrl/$id');
  }

  /// React to a post (like or dislike)
  static Future<ApiResponse> reactToPost({
    required int id,
    required String type, // 'like' | 'dislike'
  }) async {
    return await ApiProvider.post('$postsUrl/$id/react', body: {
      'type': type,
    });
  }

  /// Remove reaction from a post
  static Future<ApiResponse> unreactToPost(int id) async {
    return await ApiProvider.delete('$postsUrl/$id/react');
  }

  // ==================== COMMENTS ====================

  /// Get comments for a post
  static Future<ApiResponse> getComments(int postId) async {
    return await ApiProvider.get('$postsUrl/$postId/comments');
  }

  /// Create a comment
  static Future<ApiResponse> createComment({
    required int postId,
    required String content,
    bool isAnonymous = false,
    int? parentId,
  }) async {
    return await ApiProvider.post('$postsUrl/$postId/comments', body: {
      'content': content,
      'is_anonymous': isAnonymous,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  /// Update a comment
  static Future<ApiResponse> updateComment({
    required int postId,
    required int commentId,
    required String content,
  }) async {
    return await ApiProvider.put('$postsUrl/$postId/comments/$commentId',
        body: {
          'content': content,
        });
  }

  /// Delete a comment
  static Future<ApiResponse> deleteComment({
    required int postId,
    required int commentId,
  }) async {
    return await ApiProvider.delete('$postsUrl/$postId/comments/$commentId');
  }

  /// React to a comment (like only)
  static Future<ApiResponse> reactToComment({
    required int postId,
    required int commentId,
  }) async {
    return await ApiProvider.post('$postsUrl/$postId/comments/$commentId/react');
  }

  /// Remove reaction from a comment
  static Future<ApiResponse> unreactToComment({
    required int postId,
    required int commentId,
  }) async {
    return await ApiProvider.delete(
        '$postsUrl/$postId/comments/$commentId/react');
  }
}
