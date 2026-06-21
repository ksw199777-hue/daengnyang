import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/models/pet_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 가족 그룹 멤버 전체 userId 반환 (그룹 없으면 자신만)
  Future<List<String>> getFamilyMemberIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final groupId = userDoc.data()?['familyGroupId'] as String?;

    if (groupId == null || groupId.isEmpty) return [userId];

    final groupDoc = await _firestore.collection('familyGroups').doc(groupId).get();
    if (!groupDoc.exists) return [userId];

    final memberIds = List<String>.from(groupDoc.data()?['memberIds'] ?? []);
    return memberIds.isNotEmpty ? memberIds : [userId];
  }

  // 내 반려동물 목록 가져오기 (가족 그룹 있으면 전체 멤버 펫 포함)
  // 정렬: 그룹장 펫 → memberIds 배열 순서 → 각 멤버 내 createdAt 오름차순
  Future<List<PetModel>> getMyPets() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final groupId = userDoc.data()?['familyGroupId'] as String?;

    final List<String> memberIds;
    final String ownerId;

    if (groupId != null && groupId.isNotEmpty) {
      final groupDoc = await _firestore
          .collection('familyGroups')
          .doc(groupId)
          .get();
      if (groupDoc.exists) {
        final data = groupDoc.data()!;
        final ids = List<String>.from(data['memberIds'] ?? []);
        memberIds = ids.isNotEmpty ? ids : [userId];
        ownerId = (data['ownerId'] as String?) ?? userId;
      } else {
        memberIds = [userId];
        ownerId = userId;
      }
    } else {
      memberIds = [userId];
      ownerId = userId;
    }

    final snapshot = await _firestore
        .collection('pets')
        .where('userId', whereIn: memberIds)
        .get();

    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aUserId = a.data()['userId'] as String? ?? '';
        final bUserId = b.data()['userId'] as String? ?? '';

        // 그룹장은 항상 최우선(-1), 나머지는 memberIds 배열 순서
        final aOrder = aUserId == ownerId ? -1 : memberIds.indexOf(aUserId);
        final bOrder = bUserId == ownerId ? -1 : memberIds.indexOf(bUserId);
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);

        // 같은 멤버 내에서는 createdAt 오름차순
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

    return docs.map((doc) => PetModel.fromMap(doc.id, doc.data())).toList();
  }

  // 반려동물 단건 가져오기
  Future<PetModel?> getPet(String petId) async {
    final doc = await _firestore.collection('pets').doc(petId).get();
    if (!doc.exists) return null;
    return PetModel.fromMap(doc.id, doc.data()!);
  }
}