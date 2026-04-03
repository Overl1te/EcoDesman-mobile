class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.role,
    required this.statusText,
  });

  final int id;
  final String name;
  final String avatarUrl;
  final String role;
  final String statusText;

  String get displayName => name.isNotEmpty ? name : "ЭкоВыхухоль";

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json["id"] as int,
      name: json["name"] as String? ?? "",
      avatarUrl: json["avatar_url"] as String? ?? "",
      role: json["role"] as String? ?? "user",
      statusText: json["status_text"] as String? ?? "",
    );
  }
}
