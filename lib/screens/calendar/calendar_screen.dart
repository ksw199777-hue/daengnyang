import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/services/notification_service.dart';
import 'package:daengnyang/core/empty_widget.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _pets = [];
  Map<String, Color> _petColors = {};
  bool _isLoading = true;

  static const List<Color> _colorPalette = [
    Color(0xFFE8895A),
    Color(0xFFE8C45A),
    Color(0xFF7CB87A),
    Color(0xFF5A8FD4),
    Color(0xFF9B7DC8),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final petsSnapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();

    final pets = petsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    // 반려동물별 색상 지정
    final Map<String, Color> petColors = {};
    for (int i = 0; i < pets.length; i++) {
      petColors[pets[i]['id']] = _colorPalette[i % _colorPalette.length];
    }

    final Map<DateTime, List<Map<String, dynamic>>> events = {};

    for (final pet in pets) {
      final petColor = petColors[pet['id']]!;

      // 생일 추가 (생일 미등록 시 스킵)
      final birthTimestamp = pet['birthDate'] as Timestamp?;
      if (birthTimestamp != null) {
        final birthDate = birthTimestamp.toDate();
        final birthdayKey = DateTime(
          _focusedDay.year,
          birthDate.month,
          birthDate.day,
        );
        events[birthdayKey] = [
          ...?events[birthdayKey],
          {
            'title': '${pet['name']} 생일',
            'type': 'birthday',
            'petName': pet['name'],
            'petId': pet['id'],
            'petColor': petColor.value,
            'docId': null,
          },
        ];
      }

      // 캘린더 일정
      final calendars = await FirebaseFirestore.instance
          .collection('calendars')
          .where('petId', isEqualTo: pet['id'])
          .get();

      for (final cal in calendars.docs) {
        final calData = cal.data();
        final date = (calData['date'] as Timestamp).toDate();

        // 반복 일정 처리
        if (calData['repeatDays'] != null &&
            (calData['repeatDays'] as List).isNotEmpty) {
          // 현재 월 기준으로 반복 일정 생성
          final repeatDays = List<int>.from(calData['repeatDays']);
          final startDate = date;
          final endOfYear = DateTime(_focusedDay.year, 12, 31);

          DateTime current = startDate;
          while (current.isBefore(endOfYear)) {
            if (repeatDays.contains(current.weekday)) {
              final key = DateTime(current.year, current.month, current.day);
              events[key] = [
                ...?events[key],
                {
                  'title': calData['title'],
                  'type': calData['type'],
                  'petName': pet['name'],
                  'petId': pet['id'],
                  'petColor': petColor.value,
                  'docId': cal.id,
                  'time': calData['time'],
                  'repeatDays': calData['repeatDays'],
                },
              ];
            }
            current = current.add(const Duration(days: 1));
          }
        } else {
          final key = DateTime(date.year, date.month, date.day);
          events[key] = [
            ...?events[key],
            {
              'title': calData['title'],
              'type': calData['type'],
              'petName': pet['name'],
              'petId': pet['id'],
              'petColor': petColor.value,
              'docId': cal.id,
              'time': calData['time'],
            },
          ];
        }
      }
    }

    if (mounted) {
      setState(() {
        _pets = pets;
        _petColors = petColors;
        _events = events;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'birthday':
        return '생일';
      case 'vaccine':
        return '접종';
      case 'checkup':
        return '진료';
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
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEventDialog(editEvent: event);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final docId = event['docId'];
                  await FirebaseFirestore.instance
                      .collection('calendars')
                      .doc(docId)
                      .delete();

                  // 알림 취소
                  NotificationService().cancelAppointmentNotifications(docId);
                  NotificationService().cancelMedicationNotifications(docId);
                  NotificationService().cancelEtcNotification(docId);

                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
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
    final titleController = TextEditingController(
      text: editEvent?['title'] ?? '',
    );
    String selectedType = editEvent?['type'] ?? 'vaccine';
    String? selectedPetId =
        editEvent?['petId'] ?? (_pets.isNotEmpty ? _pets.first['id'] : null);
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay? selectedTime;
    bool noTime = editEvent?['time'] == null;
    List<int> repeatDays = editEvent?['repeatDays'] != null
        ? List<int>.from(editEvent!['repeatDays'])
        : [];

    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

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
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editEvent != null ? '일정 수정' : '일정 추가',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 반려동물 선택
                    if (_pets.length > 1) ...[
                      const Text(
                        '반려동물',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _pets.map((pet) {
                            final isSelected = selectedPetId == pet['id'];
                            final color =
                                _petColors[pet['id']] ?? AppColors.primary;
                            return GestureDetector(
                              onTap: () => setModalState(
                                () => selectedPetId = pet['id'],
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color
                                      : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : AppColors.cardBorder,
                                  ),
                                ),
                                child: Text(
                                  pet['name'],
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
                    ],

                    // 일정 종류
                    const Text(
                      '종류',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                    const SizedBox(height: 8),
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
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
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
                            })
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 제목
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '일정 제목',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 날짜
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null)
                          setModalState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
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
                            const Icon(
                              Icons.calendar_today,
                              color: AppColors.textMid,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 시간 설정
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: noTime
                                ? null
                                : () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          selectedTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null)
                                      setModalState(
                                        () => selectedTime = picked,
                                      );
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: noTime
                                    ? AppColors.cardBackground.withOpacity(0.5)
                                    : AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    noTime
                                        ? '시간 없음'
                                        : (selectedTime != null
                                              ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                              : '시간 선택'),
                                    style: TextStyle(
                                      color: noTime
                                          ? AppColors.textLight
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.access_time,
                                    color: AppColors.textMid,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setModalState(() {
                            noTime = !noTime;
                            if (noTime) selectedTime = null;
                          }),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: noTime
                                      ? AppColors.primary
                                      : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: noTime
                                        ? AppColors.primary
                                        : AppColors.cardBorder,
                                  ),
                                ),
                                child: noTime
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '시간 없음',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 투약일 때 요일 반복
                    if (selectedType == 'medication') ...[
                      const Text(
                        '요일 반복',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          final isSelected = repeatDays.contains(day);
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              if (isSelected) {
                                repeatDays.remove(day);
                              } else {
                                repeatDays.add(day);
                              }
                            }),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.cardBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.cardBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  dayLabels[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMid,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.isEmpty) return;
                          if (selectedPetId == null) return;

                          final timeString = noTime || selectedTime == null
                              ? null
                              : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

                          final data = {
                            'petId': selectedPetId,
                            'title': titleController.text.trim(),
                            'type': selectedType,
                            'date': Timestamp.fromDate(selectedDate),
                            'time': timeString,
                            'repeatDays': selectedType == 'medication'
                                ? repeatDays
                                : [],
                            'isNotified': false,
                          };

                          String docId;
                          if (editEvent != null && editEvent['docId'] != null) {
                            docId = editEvent['docId'];
                            await FirebaseFirestore.instance
                                .collection('calendars')
                                .doc(docId)
                                .update(data);
                            // 기존 알림 취소
                            NotificationService()
                                .cancelAppointmentNotifications(docId);
                            NotificationService().cancelMedicationNotifications(
                              docId,
                            );
                            NotificationService().cancelEtcNotification(docId);
                          } else {
                            final ref = await FirebaseFirestore.instance
                                .collection('calendars')
                                .add(data);
                            docId = ref.id;
                          }

                          // 알림 예약
                          final petDoc = await FirebaseFirestore.instance
                              .collection('pets')
                              .doc(selectedPetId)
                              .get();
                          final petName = petDoc.data()?['name'] ?? '';

                          if (selectedType == 'vaccine' ||
                              selectedType == 'checkup') {
                            DateTime notifyDate = selectedDate;
                            if (!noTime && selectedTime != null) {
                              notifyDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );
                            }
                            await NotificationService()
                                .scheduleAppointmentNotification(
                                  docId: docId,
                                  petName: petName,
                                  title: titleController.text.trim(),
                                  date: notifyDate,
                                );
                          } else if (selectedType == 'medication') {
                            if (!noTime && selectedTime != null) {
                              final notifyDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );
                              await NotificationService()
                                  .scheduleMedicationNotification(
                                    docId: docId,
                                    petName: petName,
                                    title: titleController.text.trim(),
                                    scheduledDate: notifyDate,
                                  );
                            }
                          } else {
                            await NotificationService().scheduleEtcNotification(
                              docId: docId,
                              petName: petName,
                              title: titleController.text.trim(),
                              date: selectedDate,
                            );
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            _loadData();
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
                // 반려동물 색상 범례
                if (_pets.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _pets.map((pet) {
                          final color =
                              _petColors[pet['id']] ?? AppColors.primary;
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pet['name'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMid,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

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
                    _loadData();
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
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();
                      final eventList = events.cast<Map<String, dynamic>>();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: eventList.take(3).map((e) {
                          final color = Color(e['petColor'] as int);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                      ? const EmptyWidget(
                          message: '날짜를 선택해주세요',
                          imagePath: 'assets/images/sleepy.png',
                        )
                      : _getEventsForDay(_selectedDay!).isEmpty
                      ? const EmptyWidget(
                          message: '일정이 없어요',
                          imagePath: 'assets/images/sleepy.png',
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 16,
                          ),
                          itemCount: _getEventsForDay(_selectedDay!).length,
                          itemBuilder: (context, index) {
                            final event = _getEventsForDay(
                              _selectedDay!,
                            )[index];
                            final color = Color(event['petColor'] as int);
                            return GestureDetector(
                              onTap: () => _showEventOptions(event),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event['title'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                event['petName'],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMid,
                                                ),
                                              ),
                                              if (event['time'] != null) ...[
                                                const Text(
                                                  ' · ',
                                                  style: TextStyle(
                                                    color: AppColors.textMid,
                                                  ),
                                                ),
                                                Text(
                                                  event['time'],
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textMid,
                                                  ),
                                                ),
                                              ],
                                              if (event['repeatDays'] != null &&
                                                  (event['repeatDays'] as List)
                                                      .isNotEmpty) ...[
                                                const Text(
                                                  ' · ',
                                                  style: TextStyle(
                                                    color: AppColors.textMid,
                                                  ),
                                                ),
                                                const Text(
                                                  '반복',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getTypeLabel(event['type']),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    if (event['docId'] != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.more_vert,
                                        color: AppColors.textLight,
                                        size: 18,
                                      ),
                                    ],
                                  ],
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
