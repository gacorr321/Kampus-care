class ComplaintModel {
  final String id;
  final String reportId;
  final String ownerName;
  final String ownerContact;
  final String description;
  final List<String> proofImageUrls;
  final DateTime submittedAt;
  final String status; // 'pending' | 'reviewed' | 'resolved'

  ComplaintModel({
    required this.id,
    required this.reportId,
    required this.ownerName,
    required this.ownerContact,
    required this.description,
    required this.proofImageUrls,
    required this.submittedAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'ownerName': ownerName,
      'ownerContact': ownerContact,
      'description': description,
      'proofImageUrls': proofImageUrls,
      'submittedAt': submittedAt.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map) {
    return ComplaintModel(
      id: map['id'] ?? '',
      reportId: map['reportId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerContact: map['ownerContact'] ?? '',
      description: map['description'] ?? '',
      proofImageUrls: List<String>.from(map['proofImageUrls'] ?? []),
      submittedAt: DateTime.fromMillisecondsSinceEpoch(map['submittedAt'] ?? 0),
      status: map['status'] ?? 'pending',
    );
  }
}
