import 'package:cloud_firestore/cloud_firestore.dart';

class PetModel {
  final String id;
  final String userId;
  final String name;
  final String species; // dog/cat
  final String breed;
  final String gender; // male/female
  final DateTime? birthDate;
  final double weight;
  final String? profileImage;
  final DateTime createdAt;

  PetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    this.birthDate,
    required this.weight,
    this.profileImage,
    required this.createdAt,
  });

  factory PetModel.fromMap(String id, Map<String, dynamic> map) {
    return PetModel(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      species: map['species'] ?? 'dog',
      breed: map['breed'] ?? '',
      gender: map['gender'] ?? 'male',
      birthDate: (map['birthDate'] as Timestamp?)?.toDate(),
      weight: (map['weight'] ?? 0).toDouble(),
      profileImage: map['profileImage'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'species': species,
      'breed': breed,
      'gender': gender,
      'birthDate': birthDate,
      'weight': weight,
      'profileImage': profileImage,
      'createdAt': createdAt,
    };
  }
}
