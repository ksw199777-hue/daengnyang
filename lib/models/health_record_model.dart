class HealthRecordModel {
  final String id;
  final String petId;
  final String type; // weight/disease/vaccine/visit
  final String title;
  final double? value; // 체중값
  final String? note;
  final String? status;
  final int? cost; // 진료비
  final DateTime recordedAt;

  HealthRecordModel({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    this.value,
    this.note,
    this.status,
    this.cost,
    required this.recordedAt,
  });

  factory HealthRecordModel.fromMap(String id, Map<String, dynamic> map) {
    return HealthRecordModel(
      id: id,
      petId: map['petId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      value: map['value']?.toDouble(),
      note: map['note'],
      status: map['status'],
      cost: map['cost'],
      recordedAt: map['recordedAt'].toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'type': type,
      'title': title,
      'value': value,
      'note': note,
      'status': status,
      'cost': cost,
      'recordedAt': recordedAt,
    };
  }
}