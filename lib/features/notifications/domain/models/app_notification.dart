class NotificationActor {
  const NotificationActor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.role,
  });

  final int id;
  final String name;
  final String avatarUrl;
  final String role;

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      id: json["id"] as int,
      name: json["name"] as String? ?? "",
      avatarUrl: json["avatar_url"] as String? ?? "",
      role: json["role"] as String? ?? "user",
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.actor,
    required this.postId,
    required this.commentId,
  });

  final int id;
  final String kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final NotificationActor actor;
  final int? postId;
  final int? commentId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actor: actor,
      postId: postId,
      commentId: commentId,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json["id"] as int,
      kind: json["kind"] as String? ?? "",
      title: json["title"] as String? ?? "",
      body: json["body"] as String? ?? "",
      isRead: json["is_read"] as bool? ?? false,
      createdAt: DateTime.parse(json["created_at"] as String),
      actor: NotificationActor.fromJson(
        Map<String, dynamic>.from(json["actor"] as Map),
      ),
      postId: json["post_id"] as int?,
      commentId: json["comment_id"] as int?,
    );
  }
}
