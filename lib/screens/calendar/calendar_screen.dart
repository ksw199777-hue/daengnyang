import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final pets = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> events = {};

    for (final pet in pets.docs) {
      final petData = pet.data();

      final birthDate = (petData['birthDate'] as Timestamp).toDate();
      final birthdayThisYear = DateTime(
        _focusedDay.year,
        birthDate.month,
        birthDate.day,
      );
      final birthdayKey = DateTime(
          birthdayThisYear.year, birthdayThisYear.month, birthdayThisYear.day);
      events[birthdayKey] = [
        ...?events[birthdayKey],
        {
          'title': '${petData['name']} 생일',
          'type': 'birthday',
          'petName': petData['name'],
          'petId': pet.id,
          'docId': null,
        },
      ];

      final calendars = await FirebaseFirestore.instance
          .collection('calendars')
          .where('petId', isEqualTo: pet.id)
          .get();

      for (final cal in calendars.docs) {
        final calData = cal.data();
        final date = (calData['date'] as Timestamp).toDate();
        final key = DateTime(date.year, date.month, date.day);
        events[key] = [
          ...?events[key],
          {
            'title': calData['title'],
            'type': calData['type'],
            'petName': petData['name'],
            'petId': pet.id,
            'docId': cal.id,
          },
        ];
      }
    }

    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'birthday':
        return const Color(0xFFFF6B9D);
      case 'vaccine':
        return const Color(0xFF4CAF50);
      case 'checkup':
        return AppColors.primary;
      case 'medication':
        return const Color(0xFFFF9800);
      default:
        return AppColors.textMid;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'birthday':
        return '생일';
      case 'vaccine':
        return '접종';
      case 'checkup':
        return '건강검진';
      case 'medication':
        return '투약';
      default:
        return '기타';
    }
  }

  void _showEventOptions(Map<String, dynamic> event) {
    if (event['docId'] == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('수정', style: TextStyle(color: AppColors.textDark)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEventDialog(editEvent: event);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('calendars')
                      .doc(event['docId'])
                      .delete();
                  if (mounted) {
                    Navigator.pop(context);
                    _loadEvents();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddEventDialog({Map<String, dynamic>? editEvent}) {
    final titleController =
        TextEditingController(text: editEvent?['title'] ?? '');
    String selectedType = editEvent?['type'] ?? 'vaccine';
    DateTime selectedDate = _selectedDay ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editEvent != null ? '일정 수정' : '일정 추가',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['vaccine', 'checkup', 'medication', 'etc']
                          .map((type) {
                        final isSelected = selectedType == type;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedType = type),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: Text(
                              _getTypeLabel(type),
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMid,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: '일정 제목',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedDate.year}.${selectedDate.month}.${selectedDate.day}',
                            style: const TextStyle(color: AppColors.textDark),
                          ),
                          const Icon(Icons.calendar_today,
                              color: AppColors.textMid, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty) return;

                        final userId =
                            FirebaseAuth.instance.currentUser?.uid;
                        if (userId == null) return;

                        final pets = await FirebaseFirestore.instance
                            .collection('pets')
                            .where('userId', isEqualTo: userId)
                            .limit(1)
                            .get();

                        if (pets.docs.isEmpty) return;

                        if (editEvent != null && editEvent['docId'] != null) {
                          await FirebaseFirestore.instance
                              .collection('calendars')
                              .doc(editEvent['docId'])
                              .update({
                            'title': titleController.text.trim(),
                            'type': selectedType,
                            'date': Timestamp.fromDate(selectedDate),
                          });
                        } else {
                          await FirebaseFirestore.instance
                              .collection('calendars')
                              .add({
                            'petId': pets.docs.first.id,
                            'title': titleController.text.trim(),
                            'type': selectedType,
                            'date': Timestamp.fromDate(selectedDate),
                            'isNotified': false,
                          });
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          _loadEvents();
                        }
                      },
                      child: Text(
                        editEvent != null ? '수정하기' : '저장',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddEventDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                    _loadEvents();
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  locale: 'ko_KR',
                ),
                const Divider(height: 1),
                Expanded(
                  child: _selectedDay == null
                      ? const Center(
                          child: Text('날짜를 선택해주세요',
                              style: TextStyle(color: AppColors.textLight)))
                      : _getEventsForDay(_selectedDay!).isEmpty
                          ? const Center(
                              child: Text('일정이 없어요',
                                  style: TextStyle(color: AppColors.textLight)))
                          : ListView.builder(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).padding.bottom + 16,
                              ),
                              itemCount: _getEventsForDay(_selectedDay!).length,
                              itemBuilder: (context, index) {
                                final event = _getEventsForDay(_selectedDay!)[index];
                                return Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _showEventOptions(event),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.cardBorder, width: 0.5),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _getTypeColor(event['type']),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(event['title'],
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.textDark,
                                                    )),
                                                Text(event['petName'],
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textMid,
                                                    )),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getTypeColor(event['type']).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getTypeLabel(event['type']),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _getTypeColor(event['type']),
                                              ),
                                            ),
                                          ),
                                          if (event['docId'] != null) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.more_vert, color: AppColors.textLight, size: 18),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}