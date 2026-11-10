class AnnouncementModel {
  final int id;
  final String title;
  final String content;
  final String badge;
  final String type;
  final String? actionUrl;
  final String? actionLabel;
  final int priority;
  final bool isActive;
  final DateTime? createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    this.badge = 'PENGUMUMAN',
    this.type = 'info',
    this.actionUrl,
    this.actionLabel,
    this.priority = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      badge: json['badge']?.toString() ?? 'PENGUMUMAN',
      type: json['type']?.toString() ?? 'info',
      actionUrl: json['action_url']?.toString(),
      actionLabel: json['action_label']?.toString(),
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == null || json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'badge': badge,
      'type': type,
      'action_url': actionUrl,
      'action_label': actionLabel,
      'priority': priority,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

