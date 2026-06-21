import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/models/family_group_model.dart';

class FamilyGroupService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<FamilyGroupModel> createGroup() async {
    final userId = _auth.currentUser!.uid;

    String code;
    do {
      code = _generateCode();
      final existing = await _firestore
          .collection('familyGroups')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) break;
    } while (true);

    final docRef = await _firestore.collection('familyGroups').add({
      'ownerId': userId,
      'inviteCode': code,
      'memberIds': [userId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(userId).update({
      'familyGroupId': docRef.id,
    });

    final doc = await docRef.get();
    return FamilyGroupModel.fromMap(doc.id, doc.data()!);
  }

  Future<FamilyGroupModel?> getMyGroup() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final groupId = userDoc.data()?['familyGroupId'] as String?;
    if (groupId == null || groupId.isEmpty) return null;

    final groupDoc = await _firestore.collection('familyGroups').doc(groupId).get();
    if (!groupDoc.exists) return null;

    return FamilyGroupModel.fromMap(groupDoc.id, groupDoc.data()!);
  }

  // null: 코드 없음, throw: 이미 가입 중
  Future<FamilyGroupModel?> joinGroup(String code) async {
    final userId = _auth.currentUser!.uid;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.data()?['familyGroupId'] != null) {
      throw Exception('already_in_group');
    }

    final results = await _firestore
        .collection('familyGroups')
        .where('inviteCode', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get();

    if (results.docs.isEmpty) return null;

    final groupDoc = results.docs.first;
    final memberIds = List<String>.from(groupDoc.data()['memberIds'] ?? []);

    if (!memberIds.contains(userId)) {
      memberIds.add(userId);
      await groupDoc.reference.update({'memberIds': memberIds});
    }

    await _firestore.collection('users').doc(userId).update({
      'familyGroupId': groupDoc.id,
    });

    final updated = await groupDoc.reference.get();
    return FamilyGroupModel.fromMap(updated.id, updated.data()!);
  }

  Future<void> kickMember(String groupId, String memberId) async {
    final groupRef = _firestore.collection('familyGroups').doc(groupId);
    final groupDoc = await groupRef.get();
    final memberIds = List<String>.from(groupDoc.data()!['memberIds'] ?? []);
    memberIds.remove(memberId);
    await groupRef.update({'memberIds': memberIds});
    await _firestore.collection('users').doc(memberId).update({
      'familyGroupId': FieldValue.delete(),
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = _auth.currentUser!.uid;
    final groupRef = _firestore.collection('familyGroups').doc(groupId);
    final groupDoc = await groupRef.get();
    final data = groupDoc.data()!;
    final memberIds = List<String>.from(data['memberIds'] ?? []);
    final ownerId = data['ownerId'] as String;

    memberIds.remove(userId);

    if (memberIds.isEmpty) {
      await groupRef.delete();
    } else {
      final newOwnerId = ownerId == userId ? memberIds.first : ownerId;
      await groupRef.update({
        'memberIds': memberIds,
        'ownerId': newOwnerId,
      });
    }

    await _firestore.collection('users').doc(userId).update({
      'familyGroupId': FieldValue.delete(),
    });
  }

  Future<List<Map<String, dynamic>>> getMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    final futures = memberIds.map((id) => _firestore.collection('users').doc(id).get());
    final docs = await Future.wait(futures);
    return docs
        .where((doc) => doc.exists)
        .map((doc) => {'id': doc.id, ...doc.data()!})
        .toList();
  }
}
