import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyGroupModel {
  final String id;
  final String ownerId;
  final String inviteCode;
  final List<String> memberIds;
  final DateTime createdAt;

  FamilyGroupModel({
    required this.id,
    required this.ownerId,
    required this.inviteCode,
    required this.memberIds,
    required this.createdAt,
  });

  factory FamilyGroupModel.fromMap(String id, Map<String, dynamic> map) {
    return FamilyGroupModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'inviteCode': inviteCode,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
