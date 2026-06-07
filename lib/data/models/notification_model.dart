class NotificationModel {
  final String id;
  final String targetUserId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedItemId;

  NotificationModel({
    required this.id,
    required this.targetUserId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.relatedItemId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      targetUserId: map['targetUserId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      relatedItemId: map['relatedItemId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetUserId': targetUserId,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'relatedItemId': relatedItemId,
    };
  }
}
