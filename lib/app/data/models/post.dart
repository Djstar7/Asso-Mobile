class Post {
  final int id;
  final int? userId;
  final String content;
  final bool isAnonymous;
  final int likesCount;
  final int dislikesCount;
  final int commentsCount;
  final String? userReaction; // 'like', 'dislike', ou null
  final bool isLiked;
  final bool isDisliked;
  final bool isMyPost;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostUser? user;

  Post({
    required this.id,
    this.userId,
    required this.content,
    required this.isAnonymous,
    required this.likesCount,
    required this.dislikesCount,
    required this.commentsCount,
    this.userReaction,
    this.isLiked = false,
    this.isDisliked = false,
    this.isMyPost = false,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'] ?? '',
      isAnonymous: json['is_anonymous'] ?? false,
      likesCount: json['likes_count'] ?? 0,
      dislikesCount: json['dislikes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      userReaction: json['user_reaction'],
      isLiked: json['is_liked'] ?? false,
      isDisliked: json['is_disliked'] ?? false,
      isMyPost: json['is_my_post'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? PostUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'is_anonymous': isAnonymous,
      'likes_count': likesCount,
      'dislikes_count': dislikesCount,
      'comments_count': commentsCount,
      'user_reaction': userReaction,
      'is_liked': isLiked,
      'is_disliked': isDisliked,
      'is_my_post': isMyPost,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user': user?.toJson(),
    };
  }

  Post copyWith({
    int? id,
    int? userId,
    String? content,
    bool? isAnonymous,
    int? likesCount,
    int? dislikesCount,
    int? commentsCount,
    String? userReaction,
    bool? isLiked,
    bool? isDisliked,
    bool? isMyPost,
    DateTime? createdAt,
    DateTime? updatedAt,
    PostUser? user,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      userReaction: userReaction ?? this.userReaction,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      isMyPost: isMyPost ?? this.isMyPost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }
}

class PostUser {
  final int? id;
  final String firstName;
  final String lastName;
  final String? avatar;

  PostUser({
    this.id,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  factory PostUser.fromJson(Map<String, dynamic> json) {
    return PostUser(
      id: json['id'],
      firstName: json['first_name'] ?? 'Anonyme',
      lastName: json['last_name'] ?? '',
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'avatar': avatar,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
}
