import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/screens/pet/pet_register_screen.dart';
import 'package:daengnyang/screens/calendar/calendar_screen.dart';
import 'package:daengnyang/screens/health/health_screen.dart';
import 'package:daengnyang/screens/outing/outing_screen.dart';
import 'package:daengnyang/screens/community/community_screen.dart';
import 'package:daengnyang/models/pet_model.dart';
import 'package:daengnyang/services/firestore_service.dart';
import 'package:daengnyang/screens/auth/nickname_screen.dart';
import 'package:daengnyang/screens/admin/admin_screen.dart';
import 'package:daengnyang/screens/settings/settings_screen.dart';
import 'package:daengnyang/screens/settings/subscription_screen.dart';
import 'package:daengnyang/screens/settings/notification_settings_screen.dart';
import 'package:daengnyang/services/notification_service.dart';
import 'package:daengnyang/core/wheel_time_picker.dart';
import 'package:daengnyang/main.dart' show isDeletingAccount;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;

  final List<Widget> _screens = [
    const CalendarScreen(),
    const HealthScreen(),
    const _HomeTab(),
    const OutingScreen(),
    const CommunityScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkPetRegistered();
    NotificationService().registerFcmToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkInitialMessage();
    });
  }

  Future<void> _checkPetRegistered() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // 닉네임 확인
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!userDoc.exists) return;

    final nickname = userDoc.data()?['nickname'];

    if ((nickname == null || nickname.isEmpty) && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NicknameScreen()),
      );
      return;
    }

    // 반려동물 확인
    final pets = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (pets.docs.isEmpty && mounted && !isDeletingAccount.value) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: SizedBox(
        height: 60 + bottomPadding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder, width: 0.5),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTabItem(0, Icons.calendar_today_outlined, '캘린더'),
                    _buildTabItem(1, Icons.favorite_outline, '건강'),
                    const SizedBox(width: 60),
                    _buildTabItem(3, Icons.explore_outlined, '나들이'),
                    _buildTabItem(4, Icons.people_outline, '커뮤니티'),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 2),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textLight,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final FirestoreService _firestoreService = FirestoreService();
  PetModel? _currentPet;
  bool _isLoading = true;
  List<PetModel> _pets = [];
  int _currentPetIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    final isReload = !_isLoading;
    try {
      final pets = await _firestoreService.getMyPets();
      if (!mounted) return;
      if (isReload && pets.isEmpty && !isDeletingAccount.value) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PetRegisterScreen()),
        );
        return;
      }
      setState(() {
        _pets = pets;
        _currentPetIndex = pets.isEmpty ? 0 : _currentPetIndex.clamp(0, pets.length - 1);
        _currentPet = pets.isNotEmpty ? pets[_currentPetIndex] : null;
        _isLoading = false;
      });
      // 생일 알림 (재)등록 — 매 홈탭 로드마다 다음 생일로 갱신
      for (final pet in pets) {
        if (pet.birthDate != null) {
          NotificationService().scheduleBirthdayNotification(
            petId: pet.id,
            petName: pet.name,
            birthDate: pet.birthDate!,
          );
        }
      }
      await Future.wait([_loadHealthSummary(), _loadUpcomingEvents()]);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _petUpcomingEvents = {};
  Map<String, dynamic> _healthSummary = {};

  Future<void> _loadHealthSummary() async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year + 1, 1, 1);

    // _pets는 getMyPets()로 이미 로드된 가족 그룹 전체 펫 목록
    if (_pets.isEmpty) return;

    final List<Map<String, dynamic>> summaries = [];

    for (final pet in _pets) {
      final petId = pet.id;
      final petName = pet.name;

      // 올해 진료/접종
      final appointments = await FirebaseFirestore.instance
          .collection('calendars')
          .where('petId', isEqualTo: petId)
          .where('type', whereIn: ['checkup', 'vaccine'])
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
          .where('date', isLessThan: Timestamp.fromDate(yearEnd))
          .get();

      final checkupCount = appointments.docs
          .where((d) => d.data()['type'] == 'checkup')
          .length;
      final vaccineCount = appointments.docs
          .where((d) => d.data()['type'] == 'vaccine')
          .length;

      // 투약 일정
      final medications = await FirebaseFirestore.instance
          .collection('calendars')
          .where('petId', isEqualTo: petId)
          .where('type', isEqualTo: 'medication')
          .get();

      // 투약 완료율 (약마다 등록일 기준으로 계산 후 평균)
      final medChecks = await FirebaseFirestore.instance
          .collection('medicationChecks')
          .get();

      int totalMedDays = 0;
      int checkedMedDays = 0;
      final List<double> medRates = [];
      final today = DateTime(now.year, now.month, now.day);

      for (final med in medications.docs) {
        final data = med.data();
        final repeatDays = List<int>.from(data['repeatDays'] ?? []);
        final medDate = (data['date'] as Timestamp).toDate();
        final medStart = DateTime(medDate.year, medDate.month, medDate.day);

        if (medStart.isAfter(today)) continue;

        final dayCount = today.difference(medStart).inDays + 1;
        int medTotal = 0;
        int medChecked = 0;

        for (int i = 0; i < dayCount; i++) {
          final day = medStart.add(Duration(days: i));
          if (day.isAfter(today)) break;
          final dayStr = '${day.year}-${day.month}-${day.day}';
          final weekday = day.weekday;

          bool shouldTake = false;
          if (repeatDays.isNotEmpty) {
            shouldTake = repeatDays.contains(weekday);
          } else {
            shouldTake = day == medStart;
          }

          if (shouldTake) {
            medTotal++;
            final docId = '${med.id}_$dayStr';
            final checked = medChecks.docs.any((d) => d.id == docId);
            if (checked) medChecked++;
          }
        }

        totalMedDays += medTotal;
        checkedMedDays += medChecked;
        if (medTotal > 0) {
          medRates.add(medChecked / medTotal);
        }
      }

      final medCompletionRate = medRates.isNotEmpty
          ? medRates.reduce((a, b) => a + b) / medRates.length * 100
          : null;

      // 올해 체중 변화 (올해 첫 기록 vs 최근 기록)
      final weights = await FirebaseFirestore.instance
          .collection('healthRecords')
          .where('petId', isEqualTo: petId)
          .where('type', isEqualTo: 'weight')
          .where(
            'recordedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart),
          )
          .where('recordedAt', isLessThan: Timestamp.fromDate(yearEnd))
          .orderBy('recordedAt')
          .get();

      double? weightDiff;
      if (weights.docs.length >= 2) {
        final first = (weights.docs.first.data()['value'] as num).toDouble();
        final latest = (weights.docs.last.data()['value'] as num).toDouble();
        weightDiff = latest - first;
      }

      summaries.add({
        'petName': petName,
        'totalMedDays': totalMedDays,
        'checkedMedDays': checkedMedDays,
        'medCompletionRate': medCompletionRate,
        'checkupCount': checkupCount,
        'vaccineCount': vaccineCount,
        'weightDiff': weightDiff,
      });
    }

    if (mounted) {
      setState(() => _healthSummary = {'summaries': summaries});
    }
  }

  Future<void> _loadUpcomingEvents() async {
    if (_pets.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, List<Map<String, dynamic>>> result = {};

    for (final pet in _pets) {
      final calendarsSnapshot = await FirebaseFirestore.instance
          .collection('calendars')
          .where('petId', isEqualTo: pet.id)
          .get();

      final petEvents = <Map<String, dynamic>>[];
      for (final cal in calendarsSnapshot.docs) {
        final data = cal.data();
        final dateTs = data['date'] as Timestamp?;
        if (dateTs == null) continue;
        final date = dateTs.toDate();
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (dateOnly.isBefore(today)) continue;

        // 투약 종료일이 오늘 이전이면 제외
        if (data['type'] == 'medication') {
          final endDateTs = data['endDate'] as Timestamp?;
          if (endDateTs != null) {
            final endDateOnly = endDateTs.toDate();
            final endDay = DateTime(endDateOnly.year, endDateOnly.month, endDateOnly.day);
            if (endDay.isBefore(today)) continue;
          }
        }

        petEvents.add({'id': cal.id, ...data});
      }

      petEvents.sort((a, b) {
        final dateA = (a['date'] as Timestamp).toDate();
        final dateB = (b['date'] as Timestamp).toDate();
        return dateA.compareTo(dateB);
      });

      result[pet.id] = petEvents.take(3).toList();
    }

    if (mounted) {
      setState(() => _petUpcomingEvents = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 생일 배너
              if (_birthdayPets.isNotEmpty) _BirthdayBanner(pets: _birthdayPets),
              // 반려동물 카드
              if (_pets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 캐릭터 (뒤)
                      Positioned(
                        top: -45,
                        right: 20,
                        child: Image.asset(
                          _pets[_currentPetIndex].species == 'cat'
                              ? 'assets/images/hi.png'
                              : 'assets/images/hi.png',
                          height: 70,
                        ),
                      ),
                      // 카드 (앞)
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (_pets.length <= 1) return;
                          if (details.primaryVelocity! < 0) {
                            setState(() {
                              _currentPetIndex =
                                  (_currentPetIndex + 1) % _pets.length;
                              _currentPet = _pets[_currentPetIndex];
                            });
                          } else if (details.primaryVelocity! > 0) {
                            setState(() {
                              _currentPetIndex =
                                  (_currentPetIndex - 1 + _pets.length) %
                                  _pets.length;
                              _currentPet = _pets[_currentPetIndex];
                            });
                          }
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          },
                          child: Container(
                            key: ValueKey(_currentPetIndex),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child:
                                            _pets[_currentPetIndex]
                                                    .profileImage !=
                                                null
                                            ? Image.network(
                                                _pets[_currentPetIndex]
                                                    .profileImage!,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.asset(
                                                _pets[_currentPetIndex]
                                                            .species ==
                                                        'cat'
                                                    ? 'assets/images/cat.png'
                                                    : 'assets/images/dog.png',
                                                width: 44,
                                                height: 44,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _pets[_currentPetIndex].name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_pets[_currentPetIndex].breed} · ${_pets[_currentPetIndex].gender == 'male' ? '수컷' : '암컷'} · ${_getAge(_pets[_currentPetIndex].birthDate)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textMid,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const SubscriptionScreen(),
                                              ),
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF8E1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFFD700,
                                                  ),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: const Text(
                                                '무료 플랜 · 업그레이드 →',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF8B6914),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.notifications_outlined,
                                            color: AppColors.textMid,
                                            size: 22,
                                          ),
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const NotificationSettingsScreen(),
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(height: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.settings_outlined,
                                            color: AppColors.textMid,
                                            size: 22,
                                          ),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const SettingsScreen(),
                                              ),
                                            );
                                            _loadPet();
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // 빠른 기록 버튼
                                Row(
                                  children: [
                                    _buildQuickButton(
                                      Icons.monitor_weight_outlined,
                                      '체중',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildQuickButton(
                                      Icons.medication_outlined,
                                      '투약',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildQuickButton(
                                      Icons.local_hospital_outlined,
                                      '진료',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildQuickButton(
                                      Icons.vaccines_outlined,
                                      '접종',
                                    ),
                                  ],
                                ),
                                // 다음 일정
                                Builder(builder: (context) {
                                  final petId = _pets[_currentPetIndex].id;
                                  final events = _petUpcomingEvents[petId] ?? [];
                                  if (events.isEmpty) return const SizedBox.shrink();
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  return Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      const Divider(height: 1, color: AppColors.cardBorder),
                                      const SizedBox(height: 10),
                                      ...events.map((event) {
                                        final date = (event['date'] as Timestamp).toDate();
                                        final dateOnly = DateTime(date.year, date.month, date.day);
                                        final diff = dateOnly.difference(today).inDays;
                                        final dDay = diff == 0 ? '오늘' : 'D-$diff';
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      event['title'] ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: AppColors.textDark,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${date.month}/${date.day}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.textMid,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: diff == 0
                                                      ? AppColors.primary.withValues(alpha: 0.1)
                                                      : AppColors.cardBackground,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  dDay,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: diff == 0 ? AppColors.primary : AppColors.textMid,
                                                    fontWeight: diff == 0 ? FontWeight.w500 : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }),
                                if (_pets.length > 1) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(_pets.length, (
                                      index,
                                    ) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: index == _currentPetIndex
                                              ? AppColors.primary
                                              : AppColors.cardBorder,
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // 건강 요약 카드
              const Text(
                '올해 요약',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              if (_healthSummary['summaries'] == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder, width: 0.5),
                  ),
                  child: const Center(
                    child: Text(
                      '등록된 건강 기록이 없어요',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                )
              else
                ...(_healthSummary['summaries'] as List<Map<String, dynamic>>).map((
                  summary,
                ) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary['petName'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildSummaryItem(
                              Icons.medication_outlined,
                              '투약',
                              '${summary['checkedMedDays']}회',
                              summary['medCompletionRate'] != null
                                  ? '완료율 ${(summary['medCompletionRate'] as double).toStringAsFixed(0)}%'
                                  : '일정 없음',
                            ),
                            _buildSummaryDivider(),
                            _buildSummaryItem(
                              Icons.local_hospital_outlined,
                              '진료',
                              '${summary['checkupCount']}회',
                              '',
                            ),
                            _buildSummaryDivider(),
                            _buildSummaryItem(
                              Icons.vaccines_outlined,
                              '접종',
                              '${summary['vaccineCount']}회',
                              '',
                            ),
                            _buildSummaryDivider(),
                            _buildSummaryItem(
                              Icons.monitor_weight_outlined,
                              '체중',
                              summary['weightDiff'] != null
                                  ? '${(summary['weightDiff'] as double) >= 0 ? '+' : ''}${(summary['weightDiff'] as double).toStringAsFixed(1)}kg'
                                  : '기록없음',
                              '',
                              valueColor: summary['weightDiff'] == null
                                  ? AppColors.textLight
                                  : (summary['weightDiff'] as double) > 0
                                  ? const Color(0xFFE05252)
                                  : (summary['weightDiff'] as double) < 0
                                  ? const Color(0xFF4CAF50)
                                  : AppColors.textDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value,
    String sub, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMid),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(width: 1, height: 50, color: AppColors.cardBorder);
  }

  Widget _buildQuickButton(IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleQuickButton(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleQuickButton(String label) {
    if (_currentPet == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('반려동물을 먼저 등록해주세요')));
      return;
    }
    switch (label) {
      case '체중':
        _showQuickWeightDialog();
        break;
      case '투약':
        _showQuickMedicationDialog();
        break;
      case '진료':
        _showQuickAppointmentDialog();
        break;
      case '접종':
        _showQuickVaccineDialog();
        break;
    }
  }

  void _showQuickWeightDialog() {
    final controller = TextEditingController();
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
              Text(
                '${_currentPet!.name} 체중 기록',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.isEmpty) return;
                    final petId = _currentPet!.id;
                    final value = double.tryParse(controller.text.trim());
                    await FirebaseFirestore.instance
                        .collection('healthRecords')
                        .add({
                          'petId': petId,
                          'type': 'weight',
                          'title': '체중 기록',
                          'value': value,
                          'recordedAt': FieldValue.serverTimestamp(),
                        });
                    if (value != null) {
                      await FirebaseFirestore.instance
                          .collection('pets')
                          .doc(petId)
                          .update({'weight': value});
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('체중이 기록됐어요!')),
                      );
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
  }

  void _showQuickMedicationDialog() {
    final controller = TextEditingController();
    TimeOfDay? selectedTime;
    bool noTime = false;
    List<int> repeatDays = [];
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
                      '${_currentPet!.name} 투약 기록',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '약 이름',
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
                    // 시간 설정
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: noTime
                                ? null
                                : () async {
                                    final picked = await showWheelTimePicker(
                                      context,
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
                    const SizedBox(height: 12),
                    // 요일 반복
                    const Text(
                      '요일 반복',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final isSelected = repeatDays.contains(day);
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            if (isSelected)
                              repeatDays.remove(day);
                            else
                              repeatDays.add(day);
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (controller.text.isEmpty) return;
                          final timeString = noTime || selectedTime == null
                              ? null
                              : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                          final now = DateTime.now();
                          final ref = await FirebaseFirestore.instance
                              .collection('calendars')
                              .add({
                                'petId': _currentPet!.id,
                                'title': controller.text.trim(),
                                'type': 'medication',
                                'date': Timestamp.fromDate(now),
                                'time': timeString,
                                'repeatDays': repeatDays,
                                'isNotified': false,
                              });
                          if (!noTime && selectedTime != null) {
                            final notifyDate = DateTime(
                              now.year, now.month, now.day,
                              selectedTime!.hour, selectedTime!.minute,
                            );
                            await NotificationService().scheduleMedicationNotification(
                              docId: ref.id,
                              petName: _currentPet!.name,
                              title: controller.text.trim(),
                              scheduledDate: notifyDate,
                              petId: _currentPet!.id,
                              repeatDays: repeatDays,
                            );
                          }
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('투약이 기록됐어요!')),
                            );
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

  void _showQuickAppointmentDialog() {
    final controller = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay? selectedTime;
    bool noTime = false;

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
                      '${_currentPet!.name} 진료 일정',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '진료 내용',
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
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
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
                                    final picked = await showWheelTimePicker(
                                      context,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (controller.text.isEmpty) return;
                          final timeString = noTime || selectedTime == null
                              ? null
                              : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                          final ref = await FirebaseFirestore.instance
                              .collection('calendars')
                              .add({
                                'petId': _currentPet!.id,
                                'title': controller.text.trim(),
                                'type': 'checkup',
                                'date': Timestamp.fromDate(selectedDate),
                                'time': timeString,
                                'repeatDays': [],
                                'isNotified': false,
                              });
                          final notifyDate = (!noTime && selectedTime != null)
                              ? DateTime(
                                  selectedDate.year, selectedDate.month, selectedDate.day,
                                  selectedTime!.hour, selectedTime!.minute,
                                )
                              : selectedDate;
                          await NotificationService().scheduleAppointmentNotification(
                            docId: ref.id,
                            petName: _currentPet!.name,
                            title: controller.text.trim(),
                            date: notifyDate,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            _loadUpcomingEvents();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('진료 일정이 등록됐어요!')),
                            );
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

  void _showQuickVaccineDialog() {
    final controller = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay? selectedTime;
    bool noTime = false;

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
                      '${_currentPet!.name} 접종 일정',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '접종 이름 (예: 광견병, 종합백신)',
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
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
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
                                    final picked = await showWheelTimePicker(
                                      context,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (controller.text.isEmpty) return;
                          final timeString = noTime || selectedTime == null
                              ? null
                              : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                          final ref = await FirebaseFirestore.instance
                              .collection('calendars')
                              .add({
                                'petId': _currentPet!.id,
                                'title': controller.text.trim(),
                                'type': 'vaccine',
                                'date': Timestamp.fromDate(selectedDate),
                                'time': timeString,
                                'repeatDays': [],
                                'isNotified': false,
                              });
                          final notifyDate = (!noTime && selectedTime != null)
                              ? DateTime(
                                  selectedDate.year, selectedDate.month, selectedDate.day,
                                  selectedTime!.hour, selectedTime!.minute,
                                )
                              : selectedDate;
                          await NotificationService().scheduleAppointmentNotification(
                            docId: ref.id,
                            petName: _currentPet!.name,
                            title: controller.text.trim(),
                            date: notifyDate,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            _loadUpcomingEvents();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('접종 일정이 등록됐어요!')),
                            );
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

  List<PetModel> get _birthdayPets {
    final now = DateTime.now();
    return _pets.where((p) {
      final b = p.birthDate;
      return b != null && b.month == now.month && b.day == now.day;
    }).toList();
  }

  String _getAge(DateTime? birthDate) {
    if (birthDate == null) return '나이 미상';
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years == 0) return '$months개월';
    return '$years살';
  }
}

class _BirthdayBanner extends StatelessWidget {
  final List<PetModel> pets;
  const _BirthdayBanner({required this.pets});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8D8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFEDD9C8), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              '${pets.map((p) => p.name).join(', ')} 생일을 축하해요!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: Image.asset('assets/images/happy_birthday.png', width: 70, height: 70),
          ),
          Positioned(
            right: 0,
            child: Image.asset('assets/images/popper.png', width: 40, height: 40),
          ),
        ],
      ),
    );
  }
}
