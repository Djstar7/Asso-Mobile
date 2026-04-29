import 'post.dart';

class PostComment {
  final int id;
  final int postId;
  final int? userId;
  final int? parentId;
  final String content;
  final bool isAnonymous;
  final int likesCount;
  final String? userReaction; // 'like' ou null
  final bool isLiked;
  final bool isMyComment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostUser? user;
  final List<PostComment>? replies;

  PostComment({
    required this.id,
    required this.postId,
    this.userId,
    this.parentId,
    required this.content,
    required this.isAnonymous,
    required this.likesCount,
    this.userReaction,
    this.isLiked = false,
    this.isMyComment = false,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.replies,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      parentId: json['parent_id'],
      content: json['content'] ?? '',
      isAnonymous: json['is_anonymous'] ?? false,
      likesCount: json['likes_count'] ?? 0,
      userReaction: json['user_reaction'],
      isLiked: json['is_liked'] ?? false,
      isMyComment: json['is_my_comment'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? PostUser.fromJson(json['user']) : null,
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((reply) => PostComment.fromJson(reply))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'parent_id': parentId,
      'content': content,
      'is_anonymous': isAnonymous,
      'likes_count': likesCount,
      'user_reaction': userReaction,
      'is_liked': isLiked,
      'is_my_comment': isMyComment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user': user?.toJson(),
      'replies': replies?.map((reply) => reply.toJson()).toList(),
    };
  }

  PostComment copyWith({
    int? id,
    int? postId,
    int? userId,
    int? parentId,
    String? content,
    bool? isAnonymous,
    int? likesCount,
    String? userReaction,
    bool? isLiked,
    bool? isMyComment,
    DateTime? createdAt,
    DateTime? updatedAt,
    PostUser? user,
    List<PostComment>? replies,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      content: content ?? this.content,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      likesCount: likesCount ?? this.likesCount,
      userReaction: userReaction ?? this.userReaction,
      isLiked: isLiked ?? this.isLiked,
      isMyComment: isMyComment ?? this.isMyComment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      replies: replies ?? this.replies,
    );
  }
}
