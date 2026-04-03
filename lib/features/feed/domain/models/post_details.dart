import "post_author.dart";
import "post_comment.dart";
import "post_image.dart";

class PostDetails {
  const PostDetails({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.publishedAt,
    required this.author,
    required this.images,
    required this.comments,
    required this.likesCount,
    required this.commentsCount,
    required this.favoritesCount,
    required this.viewCount,
    required this.isLiked,
    required this.isFavorited,
    required this.hasImages,
    required this.isOwner,
    required this.canEdit,
    required this.isPublished,
    required this.eventStartsAt,
    required this.eventEndsAt,
    required this.eventLocation,
  });

  final int id;
  final String title;
  final String body;
  final String kind;
  final DateTime publishedAt;
  final PostAuthor author;
  final List<PostImage> images;
  final List<PostComment> comments;
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final int viewCount;
  final bool isLiked;
  final bool isFavorited;
  final bool hasImages;
  final bool isOwner;
  final bool canEdit;
  final bool isPublished;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final String eventLocation;

  bool get isEvent => kind == "event";

  PostDetails copyWith({
    String? title,
    String? body,
    String? kind,
    DateTime? publishedAt,
    PostAuthor? author,
    List<PostImage>? images,
    List<PostComment>? comments,
    int? likesCount,
    int? commentsCount,
    int? favoritesCount,
    int? viewCount,
    bool? isLiked,
    bool? isFavorited,
    bool? hasImages,
    bool? isOwner,
    bool? canEdit,
    bool? isPublished,
    DateTime? eventStartsAt,
    DateTime? eventEndsAt,
    String? eventLocation,
  }) {
    return PostDetails(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      publishedAt: publishedAt ?? this.publishedAt,
      author: author ?? this.author,
      images: images ?? this.images,
      comments: comments ?? this.comments,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      viewCount: viewCount ?? this.viewCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      hasImages: hasImages ?? this.hasImages,
      isOwner: isOwner ?? this.isOwner,
      canEdit: canEdit ?? this.canEdit,
      isPublished: isPublished ?? this.isPublished,
      eventStartsAt: eventStartsAt ?? this.eventStartsAt,
      eventEndsAt: eventEndsAt ?? this.eventEndsAt,
      eventLocation: eventLocation ?? this.eventLocation,
    );
  }

  factory PostDetails.fromJson(Map<String, dynamic> json) {
    return PostDetails(
      id: json["id"] as int,
      title: json["title"] as String? ?? "",
      body: json["body"] as String? ?? "",
      kind: json["kind"] as String? ?? "",
      publishedAt: DateTime.parse(json["published_at"] as String),
      author: PostAuthor.fromJson(
        Map<String, dynamic>.from(json["author"] as Map),
      ),
      images: (json["images"] as List<dynamic>? ?? [])
          .map(
            (item) =>
                PostImage.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      comments: (json["comments"] as List<dynamic>? ?? [])
          .map(
            (item) =>
                PostComment.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      likesCount: json["likes_count"] as int? ?? 0,
      commentsCount: json["comments_count"] as int? ?? 0,
      favoritesCount: json["favorites_count"] as int? ?? 0,
      viewCount: json["view_count"] as int? ?? 0,
      isLiked: json["is_liked"] as bool? ?? false,
      isFavorited: json["is_favorited"] as bool? ?? false,
      hasImages: json["has_images"] as bool? ?? false,
      isOwner: json["is_owner"] as bool? ?? false,
      canEdit: json["can_edit"] as bool? ?? false,
      isPublished: json["is_published"] as bool? ?? true,
      eventStartsAt: _parseDateTime(json["event_starts_at"]),
      eventEndsAt: _parseDateTime(json["event_ends_at"]),
      eventLocation: json["event_location"] as String? ?? "",
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
