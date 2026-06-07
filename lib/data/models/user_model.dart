class UserModel {
  final String uid;
  final String name;
  final String email;
  final String nim;
  final String phone;
  final String? photoUrl;
  final String? ktmUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.nim,
    required this.phone,
    this.photoUrl,
    this.ktmUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      nim: map['nim'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      ktmUrl: map['ktmUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'nim': nim,
      'phone': phone,
      'photoUrl': photoUrl,
      'ktmUrl': ktmUrl,
    };
  }
}
