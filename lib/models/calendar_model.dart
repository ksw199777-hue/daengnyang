class CalendarModel {
  final String id;
  final String petId;
  final String title;
  final String type; // birthday/vaccine/checkup/medication
  final DateTime date;
  final bool isNotified;
  final String? note;

  CalendarModel({
    required this.id,
    required this.petId,
    required this.title,
    required this.type,
    required this.date,
    this.isNotified = false,
    this.note,
  });

  factory CalendarModel.fromMap(String id, Map<String, dynamic> map) {
    return CalendarModel(
      id: id,
      petId: map['petId'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      date: map['date'].toDate(),
      isNotified: map['isNotified'] ?? false,
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'title': title,
      'type': type,
      'date': date,
      'isNotified': isNotified,
      'note': note,
    };
  }
}