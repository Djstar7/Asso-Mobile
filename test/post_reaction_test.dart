import 'package:asso/app/data/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Post likedPost() => Post.fromJson({
        'id': 1,
        'content': 'Super service',
        'is_anonymous': false,
        'likes_count': 1,
        'dislikes_count': 0,
        'comments_count': 0,
        'user_reaction': 'like',
        'is_liked': true,
        'created_at': '2026-09-18T10:00:00+00:00',
        'updated_at': '2026-09-18T10:00:00+00:00',
      });

  test('retirer sa réaction remet l\'état à zéro', () {
    final post = likedPost().withReaction({'likes_count': 0, 'dislikes_count': 0, 'user_reaction': null});

    expect(post.userReaction, isNull);
    expect(post.isLiked, isFalse);
    expect(post.likesCount, 0);
  });

  test('basculer vers « je n\'aime pas » met à jour les deux compteurs', () {
    final post = likedPost().withReaction({'likes_count': 0, 'dislikes_count': 1, 'user_reaction': 'dislike'});

    expect(post.isLiked, isFalse);
    expect(post.isDisliked, isTrue);
    expect(post.dislikesCount, 1);
  });
}
