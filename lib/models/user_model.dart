class UserModel {
  final String id;
  final String email;
  final String nickname;
  final String? profileImage;
  final String subscriptionType;
  final DateTime createdAt;
  final String? familyGroupId;

  UserModel({
    required this.id,
    required this.email,
    required this.nickname,
    this.profileImage,
    this.subscriptionType = 'free',
    required this.createdAt,
    this.familyGroupId,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      nickname: map['nickname'] ?? '',
      profileImage: map['profileImage'],
      subscriptionType: map['subscriptionType'] ?? 'free',
      createdAt: map['createdAt'].toDate(),
      familyGroupId: map['familyGroupId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'profileImage': profileImage,
      'subscriptionType': subscriptionType,
      'createdAt': createdAt,
      if (familyGroupId != null) 'familyGroupId': familyGroupId,
    };
  }
}