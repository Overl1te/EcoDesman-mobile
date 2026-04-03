class EcoMapPointReview {
  const EcoMapPointReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String authorName;
  final int rating;
  final String body;
  final DateTime createdAt;

  factory EcoMapPointReview.fromJson(Map<String, dynamic> json) {
    return EcoMapPointReview(
      id: json["id"] as int,
      authorName: json["author_name"] as String? ?? "",
      rating: json["rating"] as int? ?? 0,
      body: json["body"] as String? ?? "",
      createdAt:
          DateTime.tryParse(json["created_at"] as String? ?? "") ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
