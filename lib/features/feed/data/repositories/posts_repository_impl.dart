import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../domain/models/favorite_state.dart";
import "../../domain/models/like_state.dart";
import "../../domain/models/paginated_posts.dart";
import "../../domain/models/post_comment.dart";
import "../../domain/models/post_details.dart";
import "../../domain/models/posts_query.dart";
import "../../domain/models/post_write_input.dart";
import "../../domain/repositories/posts_repository.dart";
import "../datasources/posts_remote_data_source.dart";

final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  return PostsRepositoryImpl(
    remoteDataSource: ref.watch(postsRemoteDataSourceProvider),
  );
});

class PostsRepositoryImpl implements PostsRepository {
  PostsRepositoryImpl({required PostsRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final PostsRemoteDataSource _remoteDataSource;

  @override
  Future<PostDetails> fetchPostDetails(int postId) {
    return _remoteDataSource.fetchPostDetails(postId);
  }

  @override
  Future<PaginatedPosts> fetchPosts({
    PostsQuery query = const PostsQuery(),
    int page = 1,
  }) {
    return _remoteDataSource.fetchPosts(query: query, page: page);
  }

  @override
  Future<LikeState> likePost(int postId) {
    return _remoteDataSource.likePost(postId);
  }

  @override
  Future<LikeState> unlikePost(int postId) {
    return _remoteDataSource.unlikePost(postId);
  }

  @override
  Future<FavoriteState> favoritePost(int postId) {
    return _remoteDataSource.favoritePost(postId);
  }

  @override
  Future<FavoriteState> unfavoritePost(int postId) {
    return _remoteDataSource.unfavoritePost(postId);
  }

  @override
  Future<PostComment> addComment({required int postId, required String body}) {
    return _remoteDataSource.addComment(postId: postId, body: body);
  }

  @override
  Future<PostComment> updateComment({
    required int postId,
    required int commentId,
    required String body,
  }) {
    return _remoteDataSource.updateComment(
      postId: postId,
      commentId: commentId,
      body: body,
    );
  }

  @override
  Future<void> deleteComment({required int postId, required int commentId}) {
    return _remoteDataSource.deleteComment(
      postId: postId,
      commentId: commentId,
    );
  }

  @override
  Future<PostDetails> createPost(PostWriteInput input) {
    return _remoteDataSource.createPost(input);
  }

  @override
  Future<PostDetails> updatePost({
    required int postId,
    required PostWriteInput input,
  }) {
    return _remoteDataSource.updatePost(postId: postId, input: input);
  }

  @override
  Future<void> deletePost(int postId) {
    return _remoteDataSource.deletePost(postId);
  }
}
