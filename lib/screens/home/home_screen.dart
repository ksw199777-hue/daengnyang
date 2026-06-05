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
  }

  Future<void> _checkPetRegistered() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // 닉네임 확인
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

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

    if (pets.docs.isEmpty && mounted) {
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
    final pets = await _firestoreService.getMyPets();
    if (mounted) {
      setState(() {
        _pets = pets;
        _currentPet = pets.isNotEmpty ? pets.first : null;
        _isLoading = false;
      });
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
              // 반려동물 카드
              if (_pets.isNotEmpty)
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
                                      _pets[_currentPetIndex].profileImage !=
                                          null
                                      ? Image.network(
                                          _pets[_currentPetIndex].profileImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          _pets[_currentPetIndex].species ==
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF8E1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFFD700),
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
                                    onPressed: () {},
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
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SettingsScreen(),
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // 여러 마리일 때 점 표시
                          if (_pets.length > 1) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_pets.length, (index) {
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
              const SizedBox(height: 16),

              // 빠른 기록
              const Text(
                '빠른 기록',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickButton(Icons.monitor_weight_outlined, '체중'),
                  const SizedBox(width: 8),
                  _buildQuickButton(Icons.medication_outlined, '투약'),
                  const SizedBox(width: 8),
                  _buildQuickButton(Icons.local_hospital_outlined, '진료'),
                  const SizedBox(width: 8),
                  _buildQuickButton(Icons.note_outlined, '메모'),
                ],
              ),
              const SizedBox(height: 20),

              // 다음 일정
              const Text(
                '다음 일정',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: const Center(
                  child: Text(
                    '등록된 일정이 없어요',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton(IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
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

  String _getAge(DateTime birthDate) {
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
