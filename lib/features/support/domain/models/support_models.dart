class SupportKnowledgeEntry {
  const SupportKnowledgeEntry({
    required this.id,
    required this.category,
    required this.title,
    required this.answer,
    required this.keywords,
    required this.isFeatured,
  });

  final String id;
  final String category;
  final String title;
  final String answer;
  final List<String> keywords;
  final bool isFeatured;

  factory SupportKnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return SupportKnowledgeEntry(
      id: json["id"] as String? ?? "",
      category: json["category"] as String? ?? "",
      title: json["title"] as String? ?? "",
      answer: json["answer"] as String? ?? "",
      keywords: (json["keywords"] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      isFeatured: json["is_featured"] as bool? ?? false,
    );
  }
}

class HelpCenterOverviewCard {
  const HelpCenterOverviewCard({
    required this.title,
    required this.titleEn,
    required this.body,
    required this.bodyEn,
  });

  final String title;
  final String titleEn;
  final String body;
  final String bodyEn;

  factory HelpCenterOverviewCard.fromJson(Map<String, dynamic> json) {
    return HelpCenterOverviewCard(
      title: json["title"] as String? ?? "",
      titleEn: json["title_en"] as String? ?? "",
      body: json["body"] as String? ?? "",
      bodyEn: json["body_en"] as String? ?? "",
    );
  }
}

class HelpCenterOverview {
  const HelpCenterOverview({
    required this.title,
    required this.titleEn,
    required this.description,
    required this.descriptionEn,
    required this.cards,
  });

  final String title;
  final String titleEn;
  final String description;
  final String descriptionEn;
  final List<HelpCenterOverviewCard> cards;

  factory HelpCenterOverview.fromJson(Map<String, dynamic> json) {
    return HelpCenterOverview(
      title: json["title"] as String? ?? "",
      titleEn: json["title_en"] as String? ?? "",
      description: json["description"] as String? ?? "",
      descriptionEn: json["description_en"] as String? ?? "",
      cards: (json["cards"] as List<dynamic>? ?? const [])
          .map(
            (item) => HelpCenterOverviewCard.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class HelpCenterServiceBlock {
  const HelpCenterServiceBlock({
    required this.title,
    required this.titleEn,
    required this.body,
    required this.bodyEn,
  });

  final String title;
  final String titleEn;
  final String body;
  final String bodyEn;

  factory HelpCenterServiceBlock.fromJson(Map<String, dynamic> json) {
    return HelpCenterServiceBlock(
      title: json["title"] as String? ?? "",
      titleEn: json["title_en"] as String? ?? "",
      body: json["body"] as String? ?? "",
      bodyEn: json["body_en"] as String? ?? "",
    );
  }
}

class HelpDocumentApproval {
  const HelpDocumentApproval({
    required this.status,
    required this.statusEn,
    required this.revision,
    required this.revisionEn,
    required this.effectiveDate,
    required this.effectiveDateEn,
    required this.approvedBy,
    required this.approvedByEn,
    required this.approvedRole,
    required this.approvedRoleEn,
    required this.approvalBasis,
    required this.approvalBasisEn,
    required this.contact,
    required this.contactEn,
    required this.note,
    required this.noteEn,
  });

  final String status;
  final String statusEn;
  final String revision;
  final String revisionEn;
  final String effectiveDate;
  final String effectiveDateEn;
  final String approvedBy;
  final String approvedByEn;
  final String approvedRole;
  final String approvedRoleEn;
  final String approvalBasis;
  final String approvalBasisEn;
  final String contact;
  final String contactEn;
  final String note;
  final String noteEn;

  factory HelpDocumentApproval.fromJson(Map<String, dynamic> json) {
    return HelpDocumentApproval(
      status: json["status"] as String? ?? "",
      statusEn: json["status_en"] as String? ?? "",
      revision: json["revision"] as String? ?? "",
      revisionEn: json["revision_en"] as String? ?? "",
      effectiveDate: json["effective_date"] as String? ?? "",
      effectiveDateEn: json["effective_date_en"] as String? ?? "",
      approvedBy: json["approved_by"] as String? ?? "",
      approvedByEn: json["approved_by_en"] as String? ?? "",
      approvedRole: json["approved_role"] as String? ?? "",
      approvedRoleEn: json["approved_role_en"] as String? ?? "",
      approvalBasis: json["approval_basis"] as String? ?? "",
      approvalBasisEn: json["approval_basis_en"] as String? ?? "",
      contact: json["contact"] as String? ?? "",
      contactEn: json["contact_en"] as String? ?? "",
      note: json["note"] as String? ?? "",
      noteEn: json["note_en"] as String? ?? "",
    );
  }
}

class HelpDocumentSection {
  const HelpDocumentSection({
    required this.title,
    required this.titleEn,
    required this.paragraphs,
    required this.paragraphsEn,
    required this.bullets,
    required this.bulletsEn,
  });

  final String title;
  final String titleEn;
  final List<String> paragraphs;
  final List<String> paragraphsEn;
  final List<String> bullets;
  final List<String> bulletsEn;

  factory HelpDocumentSection.fromJson(Map<String, dynamic> json) {
    return HelpDocumentSection(
      title: json["title"] as String? ?? "",
      titleEn: json["title_en"] as String? ?? "",
      paragraphs: (json["paragraphs"] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      paragraphsEn: (json["paragraphs_en"] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      bullets: (json["bullets"] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      bulletsEn: (json["bullets_en"] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

class HelpDocument {
  const HelpDocument({
    required this.id,
    required this.label,
    required this.labelEn,
    required this.summary,
    required this.summaryEn,
    required this.pdfFileName,
    required this.pdfDownloadUrl,
    required this.approval,
    required this.sections,
  });

  final String id;
  final String label;
  final String labelEn;
  final String summary;
  final String summaryEn;
  final String pdfFileName;
  final String pdfDownloadUrl;
  final HelpDocumentApproval approval;
  final List<HelpDocumentSection> sections;

  factory HelpDocument.fromJson(Map<String, dynamic> json) {
    return HelpDocument(
      id: json["id"] as String? ?? "",
      label: json["label"] as String? ?? "",
      labelEn: json["label_en"] as String? ?? "",
      summary: json["summary"] as String? ?? "",
      summaryEn: json["summary_en"] as String? ?? "",
      pdfFileName: json["pdf_file_name"] as String? ?? "",
      pdfDownloadUrl: json["pdf_download_url"] as String? ?? "",
      approval: HelpDocumentApproval.fromJson(
        Map<String, dynamic>.from(json["approval"] as Map? ?? const {}),
      ),
      sections: (json["sections"] as List<dynamic>? ?? const [])
          .map(
            (item) => HelpDocumentSection.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class HelpCenterContent {
  const HelpCenterContent({
    required this.overview,
    required this.serviceBlocks,
    required this.documents,
  });

  final HelpCenterOverview overview;
  final List<HelpCenterServiceBlock> serviceBlocks;
  final List<HelpDocument> documents;

  factory HelpCenterContent.fromJson(Map<String, dynamic> json) {
    return HelpCenterContent(
      overview: HelpCenterOverview.fromJson(
        Map<String, dynamic>.from(json["overview"] as Map? ?? const {}),
      ),
      serviceBlocks: (json["service_blocks"] as List<dynamic>? ?? const [])
          .map(
            (item) => HelpCenterServiceBlock.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      documents: (json["documents"] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                HelpDocument.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class SupportKnowledgeResponse {
  const SupportKnowledgeResponse({
    required this.featured,
    required this.faq,
    required this.suggestedPrompts,
  });

  const SupportKnowledgeResponse.empty()
    : featured = const [],
      faq = const [],
      suggestedPrompts = const [];

  final List<SupportKnowledgeEntry> featured;
  final List<SupportKnowledgeEntry> faq;
  final List<String> suggestedPrompts;

  factory SupportKnowledgeResponse.fromJson(Map<String, dynamic> json) {
    return SupportKnowledgeResponse(
      featured: (json["featured"] as List<dynamic>? ?? const [])
          .map(
            (item) => SupportKnowledgeEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      faq: (json["faq"] as List<dynamic>? ?? const [])
          .map(
            (item) => SupportKnowledgeEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      suggestedPrompts:
          (json["suggested_prompts"] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
    );
  }
}

class SupportParticipant {
  const SupportParticipant({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.role,
  });

  final int id;
  final String name;
  final String username;
  final String avatarUrl;
  final String role;

  String get displayName => name.isNotEmpty ? name : username;

  factory SupportParticipant.fromJson(Map<String, dynamic> json) {
    return SupportParticipant(
      id: json["id"] as int,
      name: json["name"] as String? ?? "",
      username: json["username"] as String? ?? "",
      avatarUrl: json["avatar_url"] as String? ?? "",
      role: json["role"] as String? ?? "user",
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.createdAt,
    required this.author,
  });

  final int id;
  final String senderType;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final SupportParticipant? author;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json["author"];
    return SupportMessage(
      id: json["id"] as int,
      senderType: json["sender_type"] as String? ?? "user",
      senderName: json["sender_name"] as String? ?? "",
      body: json["body"] as String? ?? "",
      createdAt: _parseDateTime(json["created_at"]),
      author: rawAuthor is Map
          ? SupportParticipant.fromJson(Map<String, dynamic>.from(rawAuthor))
          : null,
    );
  }
}

class SupportReportBadge {
  const SupportReportBadge({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String targetType;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory SupportReportBadge.fromJson(Map<String, dynamic> json) {
    return SupportReportBadge(
      id: json["id"] as int,
      targetType: json["target_type"] as String? ?? "",
      reason: json["reason"] as String? ?? "",
      status: json["status"] as String? ?? "",
      createdAt: _parseDateTime(json["created_at"]),
    );
  }
}

class SupportThreadSummary {
  const SupportThreadSummary({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.createdBy,
    required this.assignedTo,
    required this.report,
  });

  final int id;
  final String subject;
  final String category;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final String lastMessagePreview;
  final int unreadCount;
  final SupportParticipant createdBy;
  final SupportParticipant? assignedTo;
  final SupportReportBadge? report;

  bool get hasUnread => unreadCount > 0;

  factory SupportThreadSummary.fromJson(Map<String, dynamic> json) {
    final rawAssignedTo = json["assigned_to"];
    final rawReport = json["report"];

    return SupportThreadSummary(
      id: json["id"] as int,
      subject: json["subject"] as String? ?? "",
      category: json["category"] as String? ?? "general",
      status: json["status"] as String? ?? "open",
      createdAt: _parseDateTime(json["created_at"]),
      updatedAt: _parseDateTime(json["updated_at"]),
      lastMessageAt: _parseDateTime(json["last_message_at"]),
      lastMessagePreview: json["last_message_preview"] as String? ?? "",
      unreadCount: json["unread_count"] as int? ?? 0,
      createdBy: SupportParticipant.fromJson(
        Map<String, dynamic>.from(json["created_by"] as Map),
      ),
      assignedTo: rawAssignedTo is Map
          ? SupportParticipant.fromJson(
              Map<String, dynamic>.from(rawAssignedTo),
            )
          : null,
      report: rawReport is Map
          ? SupportReportBadge.fromJson(Map<String, dynamic>.from(rawReport))
          : null,
    );
  }
}

class SupportThreadDetail extends SupportThreadSummary {
  const SupportThreadDetail({
    required super.id,
    required super.subject,
    required super.category,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    required super.lastMessageAt,
    required super.lastMessagePreview,
    required super.unreadCount,
    required super.createdBy,
    required super.assignedTo,
    required super.report,
    required this.messages,
  });

  final List<SupportMessage> messages;

  factory SupportThreadDetail.fromJson(Map<String, dynamic> json) {
    final summary = SupportThreadSummary.fromJson(json);

    return SupportThreadDetail(
      id: summary.id,
      subject: summary.subject,
      category: summary.category,
      status: summary.status,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      lastMessageAt: summary.lastMessageAt,
      lastMessagePreview: summary.lastMessagePreview,
      unreadCount: summary.unreadCount,
      createdBy: summary.createdBy,
      assignedTo: summary.assignedTo,
      report: summary.report,
      messages: (json["messages"] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                SupportMessage.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class SupportBotReply {
  const SupportBotReply({
    required this.reply,
    required this.matchedArticle,
    required this.suggestions,
  });

  final String reply;
  final SupportKnowledgeEntry? matchedArticle;
  final List<SupportKnowledgeEntry> suggestions;

  factory SupportBotReply.fromJson(Map<String, dynamic> json) {
    final rawMatchedArticle = json["matched_article"];
    return SupportBotReply(
      reply: json["reply"] as String? ?? "",
      matchedArticle: rawMatchedArticle is Map
          ? SupportKnowledgeEntry.fromJson(
              Map<String, dynamic>.from(rawMatchedArticle),
            )
          : null,
      suggestions: (json["suggestions"] as List<dynamic>? ?? const [])
          .map(
            (item) => SupportKnowledgeEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class SupportReport {
  const SupportReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.reason,
    required this.details,
    required this.status,
    required this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
    required this.reporter,
    required this.reviewedBy,
    required this.threadId,
    required this.postId,
    required this.commentId,
    required this.reviewId,
    required this.userMarkerId,
    required this.userMarkerCommentId,
  });

  final int id;
  final String targetType;
  final int? targetId;
  final String targetLabel;
  final String reason;
  final String details;
  final String status;
  final String resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SupportParticipant reporter;
  final SupportParticipant? reviewedBy;
  final int? threadId;
  final int? postId;
  final int? commentId;
  final int? reviewId;
  final int? userMarkerId;
  final int? userMarkerCommentId;

  factory SupportReport.fromJson(Map<String, dynamic> json) {
    final rawReviewedBy = json["reviewed_by"];

    return SupportReport(
      id: json["id"] as int,
      targetType: json["target_type"] as String? ?? "",
      targetId: json["target_id"] as int?,
      targetLabel: json["target_label"] as String? ?? "",
      reason: json["reason"] as String? ?? "",
      details: json["details"] as String? ?? "",
      status: json["status"] as String? ?? "",
      resolutionNote: json["resolution_note"] as String? ?? "",
      createdAt: _parseDateTime(json["created_at"]),
      updatedAt: _parseDateTime(json["updated_at"]),
      reporter: SupportParticipant.fromJson(
        Map<String, dynamic>.from(json["reporter"] as Map),
      ),
      reviewedBy: rawReviewedBy is Map
          ? SupportParticipant.fromJson(
              Map<String, dynamic>.from(rawReviewedBy),
            )
          : null,
      threadId: json["thread_id"] as int?,
      postId: json["post_id"] as int?,
      commentId: json["comment_id"] as int?,
      reviewId: json["review_id"] as int?,
      userMarkerId: json["user_marker_id"] as int?,
      userMarkerCommentId: json["user_marker_comment_id"] as int?,
    );
  }
}

DateTime _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String getSupportThreadCategoryLabel(String value) {
  switch (value) {
    case "account":
      return "Аккаунт";
    case "content":
      return "Контент";
    case "map":
      return "Карта";
    case "report":
      return "Жалоба";
    default:
      return "Общее";
  }
}

String getSupportThreadStatusLabel(String value) {
  switch (value) {
    case "waiting_support":
      return "Ждёт поддержки";
    case "waiting_user":
      return "Ждёт пользователя";
    case "closed":
      return "Закрыт";
    default:
      return "Открыт";
  }
}

String getSupportReportStatusLabel(String value) {
  switch (value) {
    case "in_review":
      return "В работе";
    case "resolved":
      return "Решено";
    case "rejected":
      return "Отклонено";
    default:
      return "Новая";
  }
}

String getSupportReportTargetLabel(String value) {
  switch (value) {
    case "comment":
      return "Комментарий";
    case "map_review":
      return "Отзыв на карте";
    case "user_marker":
      return "Метка на карте";
    case "user_marker_comment":
      return "Комментарий к метке";
    default:
      return "Пост";
  }
}

String getSupportReportReasonLabel(String value) {
  switch (value) {
    case "abuse":
      return "Оскорбления";
    case "misinformation":
      return "Недостоверная информация";
    case "dangerous":
      return "Опасный контент";
    case "copyright":
      return "Нарушение авторских прав";
    case "other":
      return "Другое";
    default:
      return "Спам";
  }
}
