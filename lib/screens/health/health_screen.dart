import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:daengnyang/core/colors.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _weightRecords = [];
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = true;
  String? _petId;
  String? _petName;
  String? _selectedPetId;
  int _selectedYear = DateTime.now().year;

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

    if (petsSnapshot.docs.isEmpty) return;

    final pets = petsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    // 선택된 반려동물 없으면 첫번째로
    final selectedId = _selectedPetId ?? pets.first['id'];

    setState(() {
      _pets = pets;
      _selectedPetId = selectedId;
      _petName = pets.firstWhere((p) => p['id'] == selectedId)['name'];
      _petId = selectedId;
    });

    final records = await FirebaseFirestore.instance
        .collection('healthRecords')
        .where('petId', isEqualTo: selectedId)
        .orderBy('recordedAt', descending: true)
        .get();

    final List<Map<String, dynamic>> recordList = records.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    final weightList = recordList
        .where((r) => r['type'] == 'weight' && r['value'] != null)
        .toList();

    if (mounted) {
      setState(() {
        _records = recordList.where((r) => r['type'] != 'weight').toList();
        _weightRecords = weightList;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getYearlyWeights() {
    return _weightRecords
        .where((r) {
          if (r['recordedAt'] == null) return false;
          final date = (r['recordedAt'] as Timestamp).toDate();
          return date.year == _selectedYear;
        })
        .toList()
        .reversed
        .toList();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case '정상':
        return const Color(0xFF4CAF50);
      case '관찰 중':
        return const Color(0xFFFF9800);
      case '치료 중':
        return Colors.red;
      default:
        return AppColors.textMid;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'weight':
        return '체중';
      case 'disease':
        return '질병';
      case 'visit':
        return '진료';
      case 'medication':
        return '투약';
      default:
        return '기타';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'disease':
        return const Color(0xFFFF6B9D);
      case 'visit':
        return AppColors.primary;
      case 'medication':
        return const Color(0xFFFF9800);
      default:
        return AppColors.textMid;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day.toString().padLeft(2, '0')}';
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
                          'value': double.tryParse(valueController.text.trim()),
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
  }

  void _showAddRecordDialog() {
    String selectedType = 'weight';
    final valueController = TextEditingController();
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    String selectedStatus = '정상';

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
                    const Text(
                      '건강 기록 추가',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['weight', 'disease', 'visit', 'medication']
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
                    if (selectedType == 'weight')
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
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    if (selectedType != 'weight') ...[
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: '제목',
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
                      const SizedBox(height: 12),
                      if (selectedType == 'disease') ...[
                        const Text(
                          '상태',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['정상', '관찰 중', '치료 중'].map((status) {
                            final isSelected = selectedStatus == status;
                            return GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedStatus = status),
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
                                  status,
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
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: '메모 (선택)',
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_petId == null) return;
                          final data = {
                            'petId': _petId,
                            'type': selectedType,
                            'title': selectedType == 'weight'
                                ? '체중 기록'
                                : titleController.text.trim(),
                            'value': selectedType == 'weight'
                                ? double.tryParse(valueController.text.trim())
                                : null,
                            'note': noteController.text.trim(),
                            'status': selectedType == 'disease'
                                ? selectedStatus
                                : null,
                            'recordedAt': FieldValue.serverTimestamp(),
                          };
                          await FirebaseFirestore.instance
                              .collection('healthRecords')
                              .add(data);
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
              ),
            );
          },
        );
      },
    );
  }

  void _showRecordOptions(Map<String, dynamic> record) {
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
                title: const Text(
                  '수정',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditRecordDialog(record);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('healthRecords')
                      .doc(record['id'])
                      .delete();
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

  void _showEditRecordDialog(Map<String, dynamic> record) {
    final titleController = TextEditingController(text: record['title'] ?? '');
    final noteController = TextEditingController(text: record['note'] ?? '');
    String selectedStatus = record['status'] ?? '정상';

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
                      '${_getTypeLabel(record['type'])} 수정',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '제목',
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
                    const SizedBox(height: 12),
                    if (record['type'] == 'disease') ...[
                      const Text(
                        '상태',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['정상', '관찰 중', '치료 중'].map((status) {
                          final isSelected = selectedStatus == status;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedStatus = status),
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
                                status,
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
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '메모 (선택)',
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
                                'title': titleController.text.trim(),
                                'note': noteController.text.trim(),
                                'status': record['type'] == 'disease'
                                    ? selectedStatus
                                    : null,
                              });
                          if (mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        },
                        child: const Text(
                          '수정하기',
                          style: TextStyle(fontSize: 16),
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

  Widget _buildRecordSection(String type) {
    final filtered = _records.where((r) => r['type'] == type).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _getTypeColor(type),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _getTypeLabel(type),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: const Center(
              child: Text(
                '기록이 없어요',
                style: TextStyle(color: AppColors.textLight, fontSize: 13),
              ),
            ),
          )
        else
          ...filtered.map((record) {
            final date = record['recordedAt'] != null
                ? _formatDate((record['recordedAt'] as Timestamp).toDate())
                : '';
            return GestureDetector(
              onTap: () => _showRecordOptions(record),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (record['note'] != null &&
                              record['note'].isNotEmpty)
                            Text(
                              record['note'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMid,
                              ),
                            ),
                          if (date.isNotEmpty)
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (record['status'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            record['status'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record['status'],
                          style: TextStyle(
                            fontSize: 11,
                            color: _getStatusColor(record['status']),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.more_vert,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearlyWeights = _getYearlyWeights();
    final List<FlSpot> spots = [];
    for (int i = 0; i < yearlyWeights.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), (yearlyWeights[i]['value'] as num).toDouble()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _pets.length > 1
    ? GestureDetector(
        onTap: () {
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
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._pets.map((pet) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accent,
                        child: Image.asset(
                          pet['species'] == 'cat'
                              ? 'assets/images/cat.png'
                              : 'assets/images/dog.png',
                          width: 28, height: 28,
                        ),
                      ),
                      title: Text(pet['name'] ?? ''),
                      trailing: _selectedPetId == pet['id']
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedPetId = pet['id'];
                          _isLoading = true;
                        });
                        Navigator.pop(context);
                        _loadData();
                      },
                    )).toList(),
                  ],
                ),
              );
            },
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_petName 건강 기록'),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
      )
    : Text('${_petName ?? ''} 건강 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddRecordDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '체중 변화',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _selectedYear--),
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
                            onTap: () => setState(() => _selectedYear++),
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
                          ? const SizedBox(
                              height: 100,
                              child: Center(
                                child: Text(
                                  '체중 기록이 없어요',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 13,
                                  ),
                                ),
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
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
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
                                                  color: AppColors.textLight,
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
                                                  idx >= yearlyWeights.length)
                                                return const Text('');
                                              final date =
                                                  (yearlyWeights[idx]['recordedAt']
                                                          as Timestamp)
                                                      .toDate();
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  _formatShortDate(date),
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: AppColors.textLight,
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
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: spots,
                                          isCurved: true,
                                          color: AppColors.primary,
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
                                                    color: AppColors.primary,
                                                    strokeWidth: 2,
                                                    strokeColor: Colors.white,
                                                  );
                                                },
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: AppColors.primary
                                                .withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                      lineTouchData: LineTouchData(
                                        enabled: true,
                                        touchTooltipData: LineTouchTooltipData(
                                          getTooltipColor: (spot) =>
                                              AppColors.primary,
                                          getTooltipItems: (touchedSpots) {
                                            return touchedSpots.map((spot) {
                                              return LineTooltipItem(
                                                '${spot.y.toStringAsFixed(1)}kg',
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
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
                  _buildRecordSection('disease'),
                  _buildRecordSection('visit'),
                  _buildRecordSection('medication'),
                ],
              ),
            ),
    );
  }
}
