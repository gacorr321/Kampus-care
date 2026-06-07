class ItemModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String status; 
  final String reportedBy;
  final String reportedByName;
  final String reportedByPhone;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final DateTime reportedAt;
  final DateTime? incidentDate;
  final String? returnProofImageUrl; 
  final String? claimerProofImageUrl;
  final DateTime? returnedAt;   
  final String? claimedBy; 
  final String? claimerName;

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.status,
    required this.reportedBy,
    required this.reportedByName,
    required this.reportedByPhone,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.reportedAt,
    this.incidentDate,
    this.returnProofImageUrl,
    this.claimerProofImageUrl,
    this.returnedAt,
    this.claimedBy,
    this.claimerName,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      status: map['status'] ?? 'hilang',
      reportedBy: map['reportedBy'] ?? '',
      reportedByName: map['reportedByName'] ?? '',
      reportedByPhone: map['reportedByPhone'] ?? '',
      locationName: map['locationName'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      reportedAt: DateTime.fromMillisecondsSinceEpoch(map['reportedAt'] ?? 0),
      incidentDate: map['incidentDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['incidentDate']) : null,
      returnProofImageUrl: map['returnProofImageUrl'],
      claimerProofImageUrl: map['claimerProofImageUrl'],
      returnedAt: map['returnedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['returnedAt'])
          : null,
      claimedBy: map['claimedBy'],
      claimerName: map['claimerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'status': status,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'reportedByPhone': reportedByPhone,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'reportedAt': reportedAt.millisecondsSinceEpoch,
      'incidentDate': incidentDate?.millisecondsSinceEpoch,
      'returnProofImageUrl': returnProofImageUrl,
      'claimerProofImageUrl': claimerProofImageUrl,
      'returnedAt': returnedAt?.millisecondsSinceEpoch,
      'claimedBy': claimedBy,
      'claimerName': claimerName,
    };
  }
}
