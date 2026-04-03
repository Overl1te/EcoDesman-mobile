import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/error_message.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../profile/presentation/controllers/profile_controller.dart";
import "../../data/repositories/posts_repository_impl.dart";
import "../../domain/models/feed_post.dart";
import "../../domain/models/post_details.dart";
import "../../domain/models/posts_query.dart";

class FeedState {
  const FeedState({
    required this.items,
    required this.nextPage,
    required this.totalCount,
    this.isLoadingMore = false,
  });

  final List<FeedPost> items;
  final int? nextPage;
  final int totalCount;
  final bool isLoadingMore;

  bool get hasMore => nextPage != null;

  FeedState copyWith({
    List<FeedPost>? items,
    int? nextPage,
    int? totalCount,
    bool? isLoadingMore,
    bool clearNextPage = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      nextPage: clearNextPage ? null : nextPage ?? this.nextPage,
      totalCount: totalCount ?? this.totalCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

const feedPostsQuery = PostsQuery(ordering: "recommended");
const favoritePostsQuery = PostsQuery(favoritesOnly: true);
const defaultEventsQuery = PostsQuery(kind: "event", eventScope: "upcoming");

final postsCollectionControllerProvider =
    AsyncNotifierProvider.family<
      PostsCollectionController,
      FeedState,
      PostsQuery
    >(PostsCollectionController.new);

final feedControllerProvider = postsCollectionControllerProvider(
  feedPostsQuery,
);

final postDetailsControllerProvider =
    AsyncNotifierProvider.family<PostDetailsController, PostDetails, int>(
      PostDetailsController.new,
    );

class PostsCollectionController extends AsyncNotifier<FeedState> {
  PostsCollectionController(this._query);

  final PostsQuery _query;

  @override
  Future<FeedState> build() async {
    return _loadPage();
  }

  Future<void> refreshFeed() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadPage);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .fetchPosts(query: _query, page: current.nextPage!);

      state = AsyncData(
        FeedState(
          items: [...current.items, ...page.items],
          nextPage: page.nextPage,
          totalCount: page.totalCount,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(FeedPost post) async {
    final current = state.asData?.value;
    final authState = ref.read(authControllerProvider);
    if (current == null || !authState.isAuthenticated) {
      return;
    }

    final likeState = post.isLiked
        ? await ref.read(postsRepositoryProvider).unlikePost(post.id)
        : await ref.read(postsRepositoryProvider).likePost(post.id);

    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (item.id == post.id)
              item.copyWith(
                likesCount: likeState.likesCount,
                isLiked: likeState.isLiked,
              )
            else
              item,
        ],
      ),
    );
    ref.invalidate(postDetailsControllerProvider(post.id));
  }

  Future<void> toggleFavorite(FeedPost post) async {
    final current = state.asData?.value;
    final authState = ref.read(authControllerProvider);
    if (current == null || !authState.isAuthenticated) {
      return;
    }

    final favoriteState = post.isFavorited
        ? await ref.read(postsRepositoryProvider).unfavoritePost(post.id)
        : await ref.read(postsRepositoryProvider).favoritePost(post.id);

    final updatedItems = [
      for (final item in current.items)
        if (item.id == post.id)
          item.copyWith(
            favoritesCount: favoriteState.favoritesCount,
            isFavorited: favoriteState.isFavorited,
          )
        else
          item,
    ];

    state = AsyncData(current.copyWith(items: updatedItems));

    if (_query.favoritesOnly && !favoriteState.isFavorited) {
      removePost(post.id);
    }

    ref.invalidate(postDetailsControllerProvider(post.id));
    ref.invalidate(postsCollectionControllerProvider(favoritePostsQuery));
  }

  void upsertPost(PostDetails post) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final previewImageUrl = post.images.isEmpty
        ? null
        : post.images.first.imageUrl;
    final nextItem = FeedPost(
      id: post.id,
      title: post.title,
      body: post.body,
      previewText: post.body,
      kind: post.kind,
      publishedAt: post.publishedAt,
      isPublished: post.isPublished,
      author: post.author,
      previewImageUrl: previewImageUrl,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      favoritesCount: post.favoritesCount,
      viewCount: post.viewCount,
      isLiked: post.isLiked,
      isFavorited: post.isFavorited,
      hasImages: post.hasImages,
      isOwner: post.isOwner,
      canEdit: post.canEdit,
      eventStartsAt: post.eventStartsAt,
      eventEndsAt: post.eventEndsAt,
      eventLocation: post.eventLocation,
    );

    final hasPost = current.items.any((item) => item.id == post.id);
    final nextItems = hasPost
        ? [
            for (final item in current.items)
              if (item.id == post.id) nextItem else item,
          ]
        : [nextItem, ...current.items];

    state = AsyncData(
      current.copyWith(
        items: nextItems,
        totalCount: hasPost ? current.totalCount : current.totalCount + 1,
      ),
    );
  }

  void removePost(int postId) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        items: current.items.where((item) => item.id != postId).toList(),
        totalCount: current.totalCount > 0 ? current.totalCount - 1 : 0,
      ),
    );
  }

  Future<FeedState> _loadPage() async {
    final page = await ref
        .read(postsRepositoryProvider)
        .fetchPosts(query: _query);
    return FeedState(
      items: page.items,
      nextPage: page.nextPage,
      totalCount: page.totalCount,
    );
  }

  String toErrorMessage(Object error) {
    return humanizeNetworkError(
      error,
      fallback: "Не удалось загрузить публикации",
    );
  }
}

class PostDetailsController extends AsyncNotifier<PostDetails> {
  PostDetailsController(this.postId);

  final int postId;

  @override
  Future<PostDetails> build() {
    return ref.read(postsRepositoryProvider).fetchPostDetails(postId);
  }

  Future<void> refreshPost() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(postsRepositoryProvider).fetchPostDetails(postId);
    });
  }

  void _invalidateCoreCollections(PostDetails post) {
    ref.invalidate(feedControllerProvider);
    ref.invalidate(postsCollectionControllerProvider(favoritePostsQuery));
    if (post.kind == "event") {
      ref.invalidate(postsCollectionControllerProvider(defaultEventsQuery));
    }
    ref.invalidate(userPostsProvider(post.author.id));
    ref.invalidate(publicProfileProvider(post.author.id));
  }

  Future<void> toggleLike() async {
    final current = state.asData?.value;
    final authState = ref.read(authControllerProvider);
    if (current == null || !authState.isAuthenticated) {
      return;
    }

    final likeState = current.isLiked
        ? await ref.read(postsRepositoryProvider).unlikePost(postId)
        : await ref.read(postsRepositoryProvider).likePost(postId);
    final updated = current.copyWith(
      likesCount: likeState.likesCount,
      isLiked: likeState.isLiked,
    );
    state = AsyncData(updated);
    ref.read(feedControllerProvider.notifier).upsertPost(updated);
    _invalidateCoreCollections(updated);
  }

  Future<void> toggleFavorite() async {
    final current = state.asData?.value;
    final authState = ref.read(authControllerProvider);
    if (current == null || !authState.isAuthenticated) {
      return;
    }

    final favoriteState = current.isFavorited
        ? await ref.read(postsRepositoryProvider).unfavoritePost(postId)
        : await ref.read(postsRepositoryProvider).favoritePost(postId);
    final updated = current.copyWith(
      favoritesCount: favoriteState.favoritesCount,
      isFavorited: favoriteState.isFavorited,
    );
    state = AsyncData(updated);
    ref.read(feedControllerProvider.notifier).upsertPost(updated);
    _invalidateCoreCollections(updated);
  }

  Future<void> addComment(String body) async {
    final current = state.asData?.value;
    final authState = ref.read(authControllerProvider);
    if (current == null || !authState.isAuthenticated) {
      return;
    }

    final comment = await ref
        .read(postsRepositoryProvider)
        .addComment(postId: postId, body: body);
    final updated = current.copyWith(
      comments: [...current.comments, comment],
      commentsCount: current.commentsCount + 1,
    );
    state = AsyncData(updated);
    ref.read(feedControllerProvider.notifier).upsertPost(updated);
    _invalidateCoreCollections(updated);
  }

  Future<void> updateComment({
    required int commentId,
    required String body,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final comment = await ref
        .read(postsRepositoryProvider)
        .updateComment(postId: postId, commentId: commentId, body: body);
    final updated = current.copyWith(
      comments: [
        for (final item in current.comments)
          if (item.id == commentId) comment else item,
      ],
    );
    state = AsyncData(updated);
    _invalidateCoreCollections(updated);
  }

  Future<void> deleteComment(int commentId) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    await ref
        .read(postsRepositoryProvider)
        .deleteComment(postId: postId, commentId: commentId);
    final updated = current.copyWith(
      comments: current.comments.where((item) => item.id != commentId).toList(),
      commentsCount: current.commentsCount > 0 ? current.commentsCount - 1 : 0,
    );
    state = AsyncData(updated);
    ref.read(feedControllerProvider.notifier).upsertPost(updated);
    _invalidateCoreCollections(updated);
  }

  void replacePost(PostDetails post) {
    state = AsyncData(post);
    ref.read(feedControllerProvider.notifier).upsertPost(post);
    _invalidateCoreCollections(post);
  }

  Future<void> deletePost() async {
    final current = state.asData?.value;
    await ref.read(postsRepositoryProvider).deletePost(postId);
    ref.read(feedControllerProvider.notifier).removePost(postId);
    ref.invalidate(postsCollectionControllerProvider(favoritePostsQuery));
    ref.invalidate(postsCollectionControllerProvider(defaultEventsQuery));
    if (current != null) {
      ref.invalidate(userPostsProvider(current.author.id));
      ref.invalidate(publicProfileProvider(current.author.id));
    }
  }
}
