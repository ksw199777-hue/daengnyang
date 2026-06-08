import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/services/auth_service.dart';
import 'package:daengnyang/screens/pet/pet_register_screen.dart';
import 'package:daengnyang/screens/settings/subscription_screen.dart';
import 'package:daengnyang/screens/admin/admin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final petsSnapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();

    if (mounted) {
      setState(() {
        _userData = userDoc.data();
        _pets = petsSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _isLoading = false;
      });
    }
  }

  void _showNicknameDialog() {
    final controller = TextEditingController(
      text: _userData?['nickname'] ?? '',
    );
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
                '닉네임 변경',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: '닉네임 (2~12자)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final nickname = controller.text.trim();
                    if (nickname.length < 2) return;

                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId == null) return;

                    // 중복 체크
                    final existing = await FirebaseFirestore.instance
                        .collection('users')
                        .where('nickname', isEqualTo: nickname)
                        .limit(1)
                        .get();

                    if (existing.docs.isNotEmpty &&
                        existing.docs.first.id != userId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이미 사용 중인 닉네임이에요')),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update({'nickname': nickname});

                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  },
                  child: const Text('변경하기', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditPetDialog(Map<String, dynamic> pet) {
    final nameController = TextEditingController(text: pet['name'] ?? '');
    final weightController = TextEditingController(
      text: pet['weight'] != null && pet['weight'] != 0.0
          ? '${pet['weight']}'
          : '',
    );
    bool weightUnknown = pet['weight'] == 0.0 || pet['weight'] == null;
    bool isNeutered = pet['isNeutered'] ?? false;

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
                      '반려동물 정보 수정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '이름',
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
                    if (!weightUnknown)
                      TextField(
                        controller: weightController,
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
                    if (!weightUnknown) const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setModalState(() {
                        weightUnknown = !weightUnknown;
                        if (weightUnknown) weightController.clear();
                      }),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: weightUnknown
                                  ? AppColors.primary
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: weightUnknown
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: weightUnknown
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '체중을 잘 모르겠어요',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () =>
                          setModalState(() => isNeutered = !isNeutered),
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
                            const Text(
                              '중성화 여부',
                              style: TextStyle(color: AppColors.textDark),
                            ),
                            Switch(
                              value: isNeutered,
                              onChanged: (v) =>
                                  setModalState(() => isNeutered = v),
                              activeColor: AppColors.primary,
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
                              .collection('pets')
                              .doc(pet['id'])
                              .update({
                                'name': nameController.text.trim(),
                                'weight': weightUnknown
                                    ? 0.0
                                    : double.tryParse(
                                            weightController.text.trim(),
                                          ) ??
                                          0.0,
                                'isNeutered': isNeutered,
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

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('탈퇴하면 모든 데이터가 삭제돼요. 정말 탈퇴하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // 유저 문서 삭제
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();

    // 반려동물 삭제
    final pets = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in pets.docs) {
      await doc.reference.delete();
    }

    // 게시글 + 댓글 + 좋아요 삭제
    final posts = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in posts.docs) {
      // 게시글 댓글 삭제
      final comments = await FirebaseFirestore.instance
          .collection('comments')
          .where('postId', isEqualTo: doc.id)
          .get();
      for (final comment in comments.docs) {
        await comment.reference.delete();
      }
      // 게시글 좋아요 삭제
      final likes = await FirebaseFirestore.instance
          .collection('likes')
          .where('postId', isEqualTo: doc.id)
          .get();
      for (final like in likes.docs) {
        await like.reference.delete();
      }
      await doc.reference.delete();
    }

    // 내가 쓴 댓글 삭제
    final myComments = await FirebaseFirestore.instance
        .collection('comments')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in myComments.docs) {
      await doc.reference.delete();
    }

    // 건강 기록 삭제
    final healthRecords = await FirebaseFirestore.instance
        .collection('healthRecords')
        .where(
          'petId',
          whereIn: pets.docs.map((e) => e.id).toList().isEmpty
              ? ['_']
              : pets.docs.map((e) => e.id).toList(),
        )
        .get();
    for (final doc in healthRecords.docs) {
      await doc.reference.delete();
    }

    // 캘린더 삭제
    final calendars = await FirebaseFirestore.instance
        .collection('calendars')
        .where(
          'petId',
          whereIn: pets.docs.map((e) => e.id).toList().isEmpty
              ? ['_']
              : pets.docs.map((e) => e.id).toList(),
        )
        .get();
    for (final doc in calendars.docs) {
      await doc.reference.delete();
    }

    // 채팅방 삭제
    final chats = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .get();
    for (final doc in chats.docs) {
      final messages = await FirebaseFirestore.instance
          .collection('messages')
          .where('chatId', isEqualTo: doc.id)
          .get();
      for (final message in messages.docs) {
        await message.reference.delete();
      }
      await doc.reference.delete();
    }

    await FirebaseAuth.instance.currentUser?.delete();
    await AuthService().signOut();
  }

  Widget _buildPetAvatar(Map<String, dynamic> pet) {
    final profileImage = pet['profileImage'];
    final species = pet['species'] ?? 'dog';

    if (profileImage != null && profileImage.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(profileImage),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.accent,
      child: Image.asset(
        species == 'cat' ? 'assets/images/cat.png' : 'assets/images/dog.png',
        width: 36,
        height: 36,
      ),
    );
  }

  Future<void> _showDeletePetDialog(Map<String, dynamic> pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 삭제'),
        content: Text('${pet['name']}을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 반려동물 관련 데이터 삭제
    final petId = pet['id'];

    final healthRecords = await FirebaseFirestore.instance
        .collection('healthRecords')
        .where('petId', isEqualTo: petId)
        .get();
    for (final doc in healthRecords.docs) {
      await doc.reference.delete();
    }

    final calendars = await FirebaseFirestore.instance
        .collection('calendars')
        .where('petId', isEqualTo: petId)
        .get();
    for (final doc in calendars.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance.collection('pets').doc(petId).delete();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('반려동물이 삭제됐어요')));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('설정')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기본 정보
                  _buildSectionHeader('기본 정보'),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildListTile(
                          icon: Icons.person_outline,
                          title: '닉네임',
                          subtitle: _userData?['nickname'] ?? '',
                          onTap: _showNicknameDialog,
                        ),
                      ],
                    ),
                  ),

                  // 반려동물
                  _buildSectionHeader('반려동물'),
                  _buildCard(
                    child: Column(
                      children: [
                        ..._pets.map(
                          (pet) => ListTile(
                            leading: _buildPetAvatar(pet),
                            title: Text(
                              pet['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                            subtitle: Text(
                              '${pet['breed'] ?? ''} · ${pet['gender'] == 'male' ? '수컷' : '암컷'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMid,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _showEditPetDialog(pet),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.textMid,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _showDeletePetDialog(pet),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                        ),
                        ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: AppColors.textMid,
                            ),
                          ),
                          title: const Text(
                            '반려동물 추가',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMid,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PetRegisterScreen(),
                              ),
                            ).then((_) => _loadData());
                          },
                        ),
                      ],
                    ),
                  ),

                  // 구독
                  _buildSectionHeader('구독'),
                  _buildCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              color: Color(0xFF8B6914),
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            '현재 플랜',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            _userData?['subscriptionType'] == 'free'
                                ? '무료 플랜'
                                : '프리미엄 플랜',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMid,
                            ),
                          ),
                          trailing: _userData?['subscriptionType'] == 'free'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '업그레이드',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SubscriptionScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // 알림final topPosts
                  _buildSectionHeader('알림'),
                  _buildCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            '건강 관리 알림',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: const Text(
                            '예방접종, 투약, 건강검진 일정 알림',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMid,
                            ),
                          ),
                          value: _notificationsEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (v) =>
                              setState(() => _notificationsEnabled = v),
                        ),
                      ],
                    ),
                  ),

                  // 계정
                  _buildSectionHeader('계정'),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildListTile(
                          icon: Icons.logout,
                          title: '로그아웃',
                          onTap: () async {
                            await AuthService().signOut();
                            if (mounted) {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildListTile(
                          icon: Icons.delete_outline,
                          title: '회원 탈퇴',
                          titleColor: Colors.red,
                          iconColor: Colors.red,
                          onTap: _deleteAccount,
                        ),
                      ],
                    ),
                  ),
                  // 관리자 메뉴 (관리자만 보임)
                  if (AdminScreen.isAdmin()) ...[
                    _buildSectionHeader('관리자'),
                    _buildCard(
                      child: _buildListTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: '관리자 페이지',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textMid,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppColors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMid),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
      onTap: onTap,
    );
  }
}
