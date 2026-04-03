import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../feed/data/repositories/posts_repository_impl.dart";
import "../../../feed/domain/models/paginated_posts.dart";
import "../../../feed/domain/models/posts_query.dart";

final publicProfileProvider = FutureProvider.family<AppUser, int>((
  ref,
  userId,
) {
  return ref.watch(authRepositoryProvider).fetchPublicProfile(userId);
});

final userPostsProvider = FutureProvider.family<PaginatedPosts, int>((
  ref,
  userId,
) {
  return ref
      .watch(postsRepositoryProvider)
      .fetchPosts(query: PostsQuery(authorId: userId));
});
