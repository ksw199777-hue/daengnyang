import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/empty_widget.dart';

class HealthScreen extends StatefulWidget {
  final String? initialPetId;
  const HealthScreen({super.key, this.initialPetId});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<Map<String, dynamic>> _pets = [];
  int _selectedPetIndex = 0;
  List<Map<String, dynamic>> _weightRecords = [];
  List<Map<String, dynamic>> _todayMedications = [];
  List<Map<String, dynamic>> _allMedications = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;

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
        .orderBy('createdAt')
        .get();

    final pets = petsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    if (pets.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // 알림 딥링크로 진입한 경우 해당 반려동물 선택
    if (widget.initialPetId != null) {
      final idx = pets.indexWhere((p) => p['id'] == widget.initialPetId);
      if (idx != -1) _selectedPetIndex = idx;
    } else if (_selectedPetIndex >= pets.length) {
      _selectedPetIndex = 0;
    }

    await _loadPetData(pets);

    if (mounted) {
      setState(() {
        _pets = pets;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPetData(List<Map<String, dynamic>> pets) async {
    final pet = pets[_selectedPetIndex];
    final petId = pet['id'];
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 체중 기록
    final weightSnapshot = await FirebaseFirestore.instance
        .collection('healthRecords')
        .where('petId', isEqualTo: petId)
        .where('type', isEqualTo: 'weight')
        .orderBy('recordedAt', descending: true)
        .get();

    final weightRecords = weightSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    // 오늘 투약 일정
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    final allMedications = await FirebaseFirestore.instance
        .collection('calendars')
        .where('petId', isEqualTo: petId)
        .where('type', isEqualTo: 'medication')
        .get();

    final todayMedications = <Map<String, dynamic>>[];
    for (final doc in allMedications.docs) {
      final data = doc.data();
      final repeatDays = List<int>.from(data['repeatDays'] ?? []);
      final date = (data['date'] as Timestamp).toDate();
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (repeatDays.isNotEmpty) {
        if (repeatDays.contains(todayWeekday)) {
          todayMedications.add({'id': doc.id, ...data});
        }
      } else {
        if (dateOnly == todayStart) {
          todayMedications.add({'id': doc.id, ...data});
        }
      }
    }

    // 진료 일정 (접종 + 진료) - 선택 년도 기준
    final yearStart = DateTime(_selectedYear, 1, 1);
    final yearEnd = DateTime(_selectedYear + 1, 1, 1);

    final appointmentSnapshot = await FirebaseFirestore.instance
        .collection('calendars')
        .where('petId', isEqualTo: petId)
        .where('type', whereIn: ['checkup', 'vaccine'])
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
        .where('date', isLessThan: Timestamp.fromDate(yearEnd))
        .orderBy('date')
        .get();

    final appointments = appointmentSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    final allMedicationsList = allMedications.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    if (mounted) {
      setState(() {
        _weightRecords = weightRecords;
        _todayMedications = todayMedications;
        _allMedications = allMedicationsList;
        _appointments = appointments;
      });
    }
  }

  List<FlSpot> _getWeightSpots() {
    final filtered = _weightRecords
        .where((r) {
          if (r['recordedAt'] == null) return false;
          if (r['value'] == null) return false;
          final date = (r['recordedAt'] as Timestamp).toDate();
          return date.year == _selectedYear;
        })
        .toList()
        .reversed
        .toList();

    final List<FlSpot> spots = [];
    for (int i = 0; i < filtered.length; i++) {
      spots.add(FlSpot(i.toDouble(), (filtered[i]['value'] as num).toDouble()));
    }
    return spots;
  }

  List<Map<String, dynamic>> _getYearlyWeights() {
    return _weightRecords
        .where((r) {
          if (r['recordedAt'] == null) return false;
          if (r['value'] == null) return false;
          final date = (r['recordedAt'] as Timestamp).toDate();
          return date.year == _selectedYear;
        })
        .toList()
        .reversed
        .toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  bool _isPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(today);
  }

  void _showWeightDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '체중 기록',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      itemCount: _weightRecords.length,
                      itemBuilder: (context, index) {
                        final record = _weightRecords[index];
                        final date = record['recordedAt'] != null
                            ? _formatDate(
                                (record['recordedAt'] as Timestamp).toDate(),
                              )
                            : '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMid,
                                ),
                              ),
                              Text(
                                '${record['value']}kg',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showEditWeightDialog(record);
                                    },
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () async {
                                      await FirebaseFirestore.instance
                                          .collection('healthRecords')
                                          .doc(record['id'])
                                          .delete();
                                      await _loadData();
                                      setModalState(() {});
                                    },
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditWeightDialog(Map<String, dynamic> record) {
    final valueController = TextEditingController(text: '${record['value']}');
    DateTime selectedDate = record['recordedAt'] != null
        ? (record['recordedAt'] as Timestamp).toDate()
        : DateTime.now();

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '체중 수정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '체중 (kg)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '날짜',
                    style: TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
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
                            '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}',
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('healthRecords')
                            .doc(record['id'])
                            .update({
                              'value': double.tryParse(
                                valueController.text.trim(),
                              ),
                              'recordedAt': Timestamp.fromDate(selectedDate),
                            });
                        if (mounted) {
                          Navigator.pop(context);
                          _loadData();
                        }
                      },
                      child: const Text('수정하기', style: TextStyle(fontSize: 16)),
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

  void _showAddWeightDialog() {
    final valueController = TextEditingController();
    DateTime selectedDate = DateTime.now();

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '체중 기록',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '체중 (kg)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '날짜',
                    style: TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
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
                            '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}',
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_pets.isEmpty) return;
                        final petId = _pets[_selectedPetIndex]['id'];
                        await FirebaseFirestore.instance
                            .collection('healthRecords')
                            .add({
                              'petId': petId,
                              'type': 'weight',
                              'title': '체중 기록',
                              'value': double.tryParse(
                                valueController.text.trim(),
                              ),
                              'recordedAt': Timestamp.fromDate(selectedDate),
                            });
                        if (mounted) {
                          Navigator.pop(context);
                          _loadData();
                        }
                      },
                      child: const Text('저장', style: TextStyle(fontSize: 16)),
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

  void _showAppointmentDetail(Map<String, dynamic> appointment) {
    final date = (appointment['date'] as Timestamp).toDate();
    final isPast = _isPast(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
            child: _AppointmentDetailWidget(
              appointment: appointment,
              isPast: isPast,
              onSaved: () {
                Navigator.pop(context);
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getWeightSpots();
    final yearlyWeights = _getYearlyWeights();
    final selectedColor = _pets.isEmpty
        ? AppColors.primary
        : _colorPalette[_selectedPetIndex % _colorPalette.length];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _pets.isEmpty ? '건강 기록' : '${_pets[_selectedPetIndex]['name']} 건강 기록',
        ),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 반려동물 선택 버튼
                if (_pets.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_pets.length, (index) {
                          final color =
                              _colorPalette[index % _colorPalette.length];
                          final isSelected = _selectedPetIndex == index;
                          return GestureDetector(
                            onTap: () async {
                              setState(() {
                                _selectedPetIndex = index;
                                _isLoading = true;
                              });
                              await _loadPetData(_pets);
                              setState(() => _isLoading = false);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                _pets[index]['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: color,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 체중 변화
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '체중 변화',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _showAddWeightDialog,
                                  child: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    setState(() => _selectedYear--);
                                    await _loadPetData(_pets);
                                  },
                                  child: const Icon(
                                    Icons.chevron_left,
                                    color: AppColors.textMid,
                                  ),
                                ),
                                Text(
                                  '$_selectedYear년',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMid,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    setState(() => _selectedYear++);
                                    await _loadPetData(_pets);
                                  },
                                  child: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textMid,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 체중 변화량 표시
                        if (yearlyWeights.length >= 2) ...[
                          Builder(
                            builder: (context) {
                              final latest =
                                  (yearlyWeights.last['value'] as num)
                                      .toDouble();
                              final prev =
                                  (yearlyWeights[yearlyWeights.length -
                                              2]['value']
                                          as num)
                                      .toDouble();
                              final diff = latest - prev;
                              final isUp = diff > 0;
                              final isZero = diff == 0;
                              return Row(
                                children: [
                                  Text(
                                    '최근 ${yearlyWeights.last['value']}kg',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMid,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isZero
                                          ? AppColors.cardBackground
                                          : isUp
                                          ? const Color(0xFFFFEEEE)
                                          : const Color(0xFFEEF7EE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isZero
                                          ? '변화없음'
                                          : '${isUp ? '+' : ''}${diff.toStringAsFixed(1)}kg',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isZero
                                            ? AppColors.textMid
                                            : isUp
                                            ? const Color(0xFFE05252)
                                            : const Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        GestureDetector(
                          onTap: _showWeightDetail,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 0.5,
                              ),
                            ),
                            child: yearlyWeights.isEmpty
                                ? SizedBox(
                                    height: 100,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '체중 기록이 없어요',
                                          style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      SizedBox(
                                        height: 180,
                                        child: LineChart(
                                          LineChartData(
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: false,
                                              getDrawingHorizontalLine:
                                                  (value) => FlLine(
                                                    color: AppColors.cardBorder,
                                                    strokeWidth: 0.5,
                                                  ),
                                            ),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 44,
                                                  getTitlesWidget: (value, meta) {
                                                    return Text(
                                                      '${value.toStringAsFixed(1)}kg',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        color:
                                                            AppColors.textLight,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 24,
                                                  getTitlesWidget: (value, meta) {
                                                    final idx = value.toInt();
                                                    if (idx < 0 ||
                                                        idx >=
                                                            yearlyWeights
                                                                .length)
                                                      return const Text('');
                                                    final date =
                                                        (yearlyWeights[idx]['recordedAt']
                                                                as Timestamp)
                                                            .toDate();
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      child: Text(
                                                        _formatShortDate(date),
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color: AppColors
                                                              .textLight,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              rightTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                            ),
                                            borderData: FlBorderData(
                                              show: false,
                                            ),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: spots,
                                                isCurved: true,
                                                color: selectedColor,
                                                barWidth: 2,
                                                dotData: FlDotData(
                                                  getDotPainter:
                                                      (
                                                        spot,
                                                        percent,
                                                        barData,
                                                        index,
                                                      ) {
                                                        return FlDotCirclePainter(
                                                          radius: 4,
                                                          color: selectedColor,
                                                          strokeWidth: 2,
                                                          strokeColor:
                                                              Colors.white,
                                                        );
                                                      },
                                                ),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  color: selectedColor
                                                      .withOpacity(0.08),
                                                ),
                                              ),
                                            ],
                                            lineTouchData: LineTouchData(
                                              enabled: true,
                                              touchTooltipData: LineTouchTooltipData(
                                                getTooltipColor: (spot) =>
                                                    selectedColor,
                                                getTooltipItems: (touchedSpots) {
                                                  return touchedSpots.map((
                                                    spot,
                                                  ) {
                                                    return LineTooltipItem(
                                                      '${spot.y.toStringAsFixed(1)}kg',
                                                      const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    );
                                                  }).toList();
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        '탭하면 전체 기록을 볼 수 있어요',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 오늘 투약
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '오늘 투약',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                final pet = _pets[_selectedPetIndex];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _MedicationHistoryScreen(
                                      petId: pet['id'],
                                      medications: _allMedications,
                                      color: selectedColor,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: const Text(
                                  '이력 보기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMid,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_todayMedications.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 0.5,
                              ),
                            ),
                            child: const EmptyWidget(
                              message: '오늘 투약 일정이 없어요',
                              imagePath: 'assets/images/sleepy.png',
                            ),
                          )
                        else
                          ...(_todayMedications.map(
                            (med) => _MedicationCheckCard(
                              medication: med,
                              color: selectedColor,
                            ),
                          )),
                        const SizedBox(height: 24),

                        // 진료/접종 일정
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '진료 & 접종',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_pets.isEmpty) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AppointmentHistoryScreen(
                                          petId: _pets[_selectedPetIndex]['id'],
                                          petName:
                                              _pets[_selectedPetIndex]['name'],
                                          color: selectedColor,
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: const Text(
                                  '이력 보기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMid,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_appointments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 0.5,
                              ),
                            ),
                            child: const EmptyWidget(
                              message: '등록된 진료/접종 일정이 없어요',
                              imagePath: 'assets/images/sleepy.png',
                            ),
                          )
                        else ...[
                          ...(_appointments.where((a) => a['review'] == null).map((
                            appointment,
                          ) {
                            final date = (appointment['date'] as Timestamp)
                                .toDate();
                            final isPast = _isPast(date);
                            final isToday = _isToday(date);
                            final hasReview = appointment['review'] != null;

                            return GestureDetector(
                              onTap: () => _showAppointmentDetail(appointment),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isToday
                                        ? selectedColor
                                        : AppColors.cardBorder,
                                    width: isToday ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: selectedColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        appointment['type'] == 'vaccine'
                                            ? Icons.vaccines_outlined
                                            : Icons.local_hospital_outlined,
                                        color: selectedColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            appointment['title'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                _formatDate(date),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMid,
                                                ),
                                              ),
                                              if (appointment['time'] !=
                                                  null) ...[
                                                const Text(
                                                  ' · ',
                                                  style: TextStyle(
                                                    color: AppColors.textMid,
                                                  ),
                                                ),
                                                Text(
                                                  appointment['time'],
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textMid,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (isPast && !hasReview)
                                            const Text(
                                              '후기를 작성해봐요',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          if (hasReview)
                                            const Text(
                                              '후기 작성 완료',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF7CB87A),
                                              ),
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
                                        color: isToday
                                            ? selectedColor.withOpacity(0.1)
                                            : isPast
                                            ? AppColors.cardBackground
                                            : AppColors.cardBackground,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isToday
                                            ? '오늘'
                                            : isPast
                                            ? '후기 작성'
                                            : 'D-${date.difference(DateTime.now()).inDays + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isToday
                                              ? selectedColor
                                              : AppColors.textMid,
                                          fontWeight: isToday
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textLight,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })),
                          // 진료비 통계
                          Builder(
                            builder: (context) {
                              final completedAppointments = _appointments
                                  .where((a) => a['review'] != null)
                                  .toList();
                              if (completedAppointments.isEmpty)
                                return const SizedBox();
                              final totalVetFee = completedAppointments
                                  .fold<int>(0, (sum, a) {
                                    final review =
                                        a['review'] as Map<String, dynamic>?;
                                    return sum +
                                        ((review?['vetFee'] ?? 0) as int) +
                                        ((review?['medFee'] ?? 0) as int);
                                  });
                              final thisYearAppointments = completedAppointments
                                  .where((a) {
                                    final date = (a['date'] as Timestamp)
                                        .toDate();
                                    return date.year == DateTime.now().year;
                                  })
                                  .toList();
                              final thisYearFee = thisYearAppointments
                                  .fold<int>(0, (sum, a) {
                                    final review =
                                        a['review'] as Map<String, dynamic>?;
                                    return sum +
                                        ((review?['vetFee'] ?? 0) as int) +
                                        ((review?['medFee'] ?? 0) as int);
                                  });
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '진료비 통계',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '올해 지출',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMid,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_formatPrice(thisYearFee)}원',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: selectedColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 36,
                                          color: AppColors.cardBorder,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 16,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '누적 지출',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textMid,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_formatPrice(totalVetFee)}원',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// 투약 체크 카드
class _MedicationCheckCard extends StatefulWidget {
  final Map<String, dynamic> medication;
  final Color color;

  const _MedicationCheckCard({required this.medication, required this.color});

  @override
  State<_MedicationCheckCard> createState() => _MedicationCheckCardState();
}

class _MedicationCheckCardState extends State<_MedicationCheckCard> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _loadChecked();
  }

  Future<void> _loadChecked() async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final docId = '${widget.medication['id']}_$todayStr';

    final doc = await FirebaseFirestore.instance
        .collection('medicationChecks')
        .doc(docId)
        .get();

    if (mounted) setState(() => _checked = doc.exists);
  }

  Future<void> _toggleCheck() async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final docId = '${widget.medication['id']}_$todayStr';

    if (_checked) {
      await FirebaseFirestore.instance
          .collection('medicationChecks')
          .doc(docId)
          .delete();
    } else {
      await FirebaseFirestore.instance
          .collection('medicationChecks')
          .doc(docId)
          .set({
            'medicationId': widget.medication['id'],
            'date': todayStr,
            'checkedAt': FieldValue.serverTimestamp(),
          });
    }

    setState(() => _checked = !_checked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleCheck,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _checked ? widget.color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _checked ? widget.color : AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: _checked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.medication['title'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _checked ? AppColors.textLight : AppColors.textDark,
                    decoration: _checked ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (widget.medication['time'] != null)
                  Text(
                    widget.medication['time'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                  ),
              ],
            ),
          ),
          if (_checked)
            Text(
              '먹였어요',
              style: TextStyle(
                fontSize: 12,
                color: widget.color,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// 투약 이력 화면
class _MedicationHistoryScreen extends StatefulWidget {
  final String petId;
  final List<Map<String, dynamic>> medications;
  final Color color;

  const _MedicationHistoryScreen({
    required this.petId,
    required this.medications,
    required this.color,
  });

  @override
  State<_MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<_MedicationHistoryScreen> {
  // dateStr -> { medId -> bool }
  Map<String, Map<String, bool>> _checkMap = {};
  List<DateTime> _dates = [];
  // dateStr -> list of scheduled medications
  Map<String, List<Map<String, dynamic>>> _scheduledMeds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // 가장 이른 등록일 찾기
    DateTime? earliest;
    for (final med in widget.medications) {
      final ts = med['date'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final dOnly = DateTime(d.year, d.month, d.day);
      if (earliest == null || dOnly.isBefore(earliest)) earliest = dOnly;
    }

    if (earliest == null || widget.medications.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 등록일부터 오늘까지 날짜 생성
    final totalDays = todayOnly.difference(earliest).inDays + 1;
    final dates = <DateTime>[];
    final scheduledMeds = <String, List<Map<String, dynamic>>>{};

    for (int i = 0; i < totalDays; i++) {
      final day = earliest.add(Duration(days: i));
      if (day.isAfter(todayOnly)) break;
      final dayStr = '${day.year}-${day.month}-${day.day}';
      final weekday = day.weekday;

      final medsForDay = <Map<String, dynamic>>[];
      for (final med in widget.medications) {
        final ts = med['date'] as Timestamp?;
        if (ts == null) continue;
        final medDate = ts.toDate();
        final medStart = DateTime(medDate.year, medDate.month, medDate.day);
        if (day.isBefore(medStart)) continue;

        final repeatDays = List<int>.from(med['repeatDays'] ?? []);
        bool shouldTake;
        if (repeatDays.isNotEmpty) {
          shouldTake = repeatDays.contains(weekday);
        } else {
          shouldTake = day == medStart;
        }
        if (shouldTake) medsForDay.add(med);
      }

      if (medsForDay.isNotEmpty) {
        dates.add(day);
        scheduledMeds[dayStr] = medsForDay;
      }
    }

    // 최신 날짜가 위로 오도록 역순 정렬
    dates.sort((a, b) => b.compareTo(a));

    // medicationChecks 로드
    final medIds = widget.medications.map((m) => m['id'] as String).toSet();
    final checksSnapshot = await FirebaseFirestore.instance
        .collection('medicationChecks')
        .get();

    final checkMap = <String, Map<String, bool>>{};
    for (final doc in checksSnapshot.docs) {
      final parts = doc.id.split('_');
      if (parts.length < 2) continue;
      final medId = parts[0];
      if (!medIds.contains(medId)) continue;
      final dateStr = parts.sublist(1).join('_');
      checkMap.putIfAbsent(dateStr, () => {})[medId] = true;
    }

    if (mounted) {
      setState(() {
        _dates = dates;
        _scheduledMeds = scheduledMeds;
        _checkMap = checkMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCheck(
      String dayStr, Map<String, dynamic> med, bool current) async {
    final medId = med['id'] as String;
    final docId = '${medId}_$dayStr';

    if (current) {
      await FirebaseFirestore.instance
          .collection('medicationChecks')
          .doc(docId)
          .delete();
    } else {
      await FirebaseFirestore.instance
          .collection('medicationChecks')
          .doc(docId)
          .set({
        'medicationId': medId,
        'date': dayStr,
        'checkedAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      setState(() {
        _checkMap.putIfAbsent(dayStr, () => {})[medId] = !current;
      });
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dOnly = DateTime(d.year, d.month, d.day);
    if (dOnly == today) return '${d.month}/${d.day} (오늘)';
    if (dOnly == yesterday) return '${d.month}/${d.day} (어제)';
    const weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}/${d.day} (${weekdays[d.weekday]})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('투약 이력')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dates.isEmpty
          ? const EmptyWidget(message: '투약 이력이 없어요')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final day = _dates[index];
                final dayStr = '${day.year}-${day.month}-${day.day}';
                final meds = _scheduledMeds[dayStr] ?? [];
                final dayChecks = _checkMap[dayStr] ?? {};

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Text(
                          _formatDate(day),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      ...meds.map((med) {
                        final medId = med['id'] as String;
                        final checked = dayChecks[medId] == true;
                        return InkWell(
                          onTap: () => _toggleCheck(dayStr, med, checked),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: checked
                                        ? widget.color
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: checked
                                          ? widget.color
                                          : AppColors.cardBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: checked
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: checked
                                              ? AppColors.textLight
                                              : AppColors.textDark,
                                          decoration: checked
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (med['time'] != null)
                                        Text(
                                          med['time'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMid,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (checked)
                                  Text(
                                    '먹였어요',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// 진료 상세/후기 위젯
class _AppointmentDetailWidget extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final bool isPast;
  final VoidCallback onSaved;

  const _AppointmentDetailWidget({
    required this.appointment,
    required this.isPast,
    required this.onSaved,
  });

  @override
  State<_AppointmentDetailWidget> createState() =>
      _AppointmentDetailWidgetState();
}

class _AppointmentDetailWidgetState extends State<_AppointmentDetailWidget> {
  final _diagnosisController = TextEditingController();
  final _vetFeeController = TextEditingController();
  final _medFeeController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime? _nextAppointment;
  bool _hasExistingReview = false;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _vetFeeController.dispose();
    _medFeeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadReview() async {
    final review = widget.appointment['review'];
    if (review != null) {
      setState(() {
        _hasExistingReview = true;
        _diagnosisController.text = review['diagnosis'] ?? '';
        _vetFeeController.text = review['vetFee']?.toString() ?? '';
        _medFeeController.text = review['medFee']?.toString() ?? '';
        _memoController.text = review['memo'] ?? '';
        if (review['nextAppointment'] != null) {
          _nextAppointment = (review['nextAppointment'] as Timestamp).toDate();
        }
      });
    }
  }

  Future<void> _saveReview() async {
    final review = {
      'diagnosis': _diagnosisController.text.trim(),
      'vetFee': int.tryParse(_vetFeeController.text.replaceAll(',', '')) ?? 0,
      'medFee': int.tryParse(_medFeeController.text.replaceAll(',', '')) ?? 0,
      'memo': _memoController.text.trim(),
      'nextAppointment': _nextAppointment != null
          ? Timestamp.fromDate(_nextAppointment!)
          : null,
      'savedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('calendars')
        .doc(widget.appointment['id'])
        .update({'review': review});

    // 다음 예약일 캘린더에 자동 저장
    if (_nextAppointment != null) {
      await FirebaseFirestore.instance.collection('calendars').add({
        'petId': widget.appointment['petId'],
        'title': widget.appointment['title'],
        'type': widget.appointment['type'],
        'date': Timestamp.fromDate(_nextAppointment!),
        'time': widget.appointment['time'],
        'repeatDays': [],
        'isNotified': false,
      });
    }

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.appointment['date'] as Timestamp).toDate();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.appointment['title'] ?? '',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatDate(date)}${widget.appointment['time'] != null ? ' · ${widget.appointment['time']}' : ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.textMid),
        ),
        const SizedBox(height: 20),

        if (!widget.isPast)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '진료 후 후기를 작성할 수 있어요',
              style: TextStyle(fontSize: 13, color: AppColors.textMid),
            ),
          )
        else ...[
          const Text(
            '진단/증상',
            style: TextStyle(fontSize: 13, color: AppColors.textMid),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _diagnosisController,
            decoration: InputDecoration(
              hintText: '진단명 또는 증상을 입력해주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '진료비',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _vetFeeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: '원',
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '약값',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _medFeeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: '원',
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '메모',
            style: TextStyle(fontSize: 13, color: AppColors.textMid),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '추가 메모를 입력해주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '다음 예약일 (선택)',
            style: TextStyle(fontSize: 13, color: AppColors.textMid),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _nextAppointment = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _nextAppointment != null
                        ? _formatDate(_nextAppointment!)
                        : '날짜 선택',
                    style: TextStyle(
                      color: _nextAppointment != null
                          ? AppColors.textDark
                          : AppColors.textLight,
                    ),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveReview,
              child: Text(
                _hasExistingReview ? '수정하기' : '저장하기',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

// 진료/접종 이력 페이지
class AppointmentHistoryScreen extends StatefulWidget {
  final String petId;
  final String petName;
  final Color color;

  const AppointmentHistoryScreen({
    super.key,
    required this.petId,
    required this.petName,
    required this.color,
  });

  @override
  State<AppointmentHistoryScreen> createState() =>
      _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  void _showHistoryDetail(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    final date = (appointment['date'] as Timestamp).toDate();
    final review = appointment['review'] as Map<String, dynamic>;
    final vetFee = (review['vetFee'] ?? 0) as int;
    final medFee = (review['medFee'] ?? 0) as int;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 + 수정/삭제 버튼
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      appointment['type'] == 'vaccine'
                          ? Icons.vaccines_outlined
                          : Icons.local_hospital_outlined,
                      color: widget.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 수정 버튼
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showEditHistory(context, appointment);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_outlined,
                        color: AppColors.textMid,
                        size: 20,
                      ),
                    ),
                  ),
                  // 삭제 버튼
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('이력 삭제'),
                          content: const Text(
                            '이 진료 이력을 삭제할까요?\n후기만 삭제되고 일정은 진료&접종 목록으로 돌아가요.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                '삭제',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection('calendars')
                            .doc(appointment['id'])
                            .update({'review': FieldValue.delete()});
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if ((review['diagnosis'] ?? '').isNotEmpty) ...[
                const Text(
                  '진단/증상',
                  style: TextStyle(fontSize: 12, color: AppColors.textMid),
                ),
                const SizedBox(height: 4),
                Text(
                  review['diagnosis'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '진료비',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatPrice(vetFee)}원',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '약값',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatPrice(medFee)}원',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '합계',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatPrice(vetFee + medFee)}원',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: widget.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((review['memo'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '메모',
                  style: TextStyle(fontSize: 12, color: AppColors.textMid),
                ),
                const SizedBox(height: 4),
                Text(
                  review['memo'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditHistory(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    final review = appointment['review'] as Map<String, dynamic>;
    final diagnosisController = TextEditingController(
      text: review['diagnosis'] ?? '',
    );
    final vetFeeController = TextEditingController(
      text: (review['vetFee'] ?? 0).toString(),
    );
    final medFeeController = TextEditingController(
      text: (review['medFee'] ?? 0).toString(),
    );
    final memoController = TextEditingController(text: review['memo'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이력 수정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '진단/증상',
                  style: TextStyle(fontSize: 13, color: AppColors.textMid),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: diagnosisController,
                  decoration: InputDecoration(
                    hintText: '진단명 또는 증상',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '진료비',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMid,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: vetFeeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: '원',
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '약값',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMid,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: medFeeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: '원',
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '메모',
                  style: TextStyle(fontSize: 13, color: AppColors.textMid),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: memoController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '추가 메모',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('calendars')
                          .doc(appointment['id'])
                          .update({
                            'review': {
                              ...review,
                              'diagnosis': diagnosisController.text.trim(),
                              'vetFee':
                                  int.tryParse(
                                    vetFeeController.text.replaceAll(',', ''),
                                  ) ??
                                  0,
                              'medFee':
                                  int.tryParse(
                                    medFeeController.text.replaceAll(',', ''),
                                  ) ??
                                  0,
                              'memo': memoController.text.trim(),
                            },
                          });
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('수정하기', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('${widget.petName} 진료 이력')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('calendars')
            .where('petId', isEqualTo: widget.petId)
            .where('type', whereIn: ['checkup', 'vaccine'])
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all =
              snapshot.data?.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList() ??
              [];
          final history = all.where((a) => a['review'] != null).toList();
          if (history.isEmpty) {
            return const EmptyWidget(message: '후기를 작성한 진료/접종 이력이 없어요');
          }
          return ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final appointment = history[index];
              final date = (appointment['date'] as Timestamp).toDate();
              final review = appointment['review'] as Map<String, dynamic>;
              final vetFee = (review['vetFee'] ?? 0) as int;
              final medFee = (review['medFee'] ?? 0) as int;
              final total = vetFee + medFee;
              return GestureDetector(
                onTap: () => _showHistoryDetail(context, appointment),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          appointment['type'] == 'vaccine'
                              ? Icons.vaccines_outlined
                              : Icons.local_hospital_outlined,
                          color: widget.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMid,
                              ),
                            ),
                            if ((review['diagnosis'] ?? '').isNotEmpty)
                              Text(
                                review['diagnosis'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (total > 0)
                        Text(
                          '${_formatPrice(total)}원',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: widget.color,
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textLight,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
