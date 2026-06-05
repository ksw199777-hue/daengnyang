import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/models/pet_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 내 반려동물 목록 가져오기
  Future<List<PetModel>> getMyPets() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((doc) => PetModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // 반려동물 단건 가져오기
  Future<PetModel?> getPet(String petId) async {
    final doc = await _firestore.collection('pets').doc(petId).get();
    if (!doc.exists) return null;
    return PetModel.fromMap(doc.id, doc.data()!);
  }
}