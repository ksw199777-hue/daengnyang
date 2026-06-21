import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/services/auth_service.dart';
import 'package:daengnyang/screens/pet/pet_register_screen.dart';
import 'package:daengnyang/screens/settings/subscription_screen.dart';
import 'package:daengnyang/screens/admin/admin_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:daengnyang/screens/auth/login_screen.dart';
import 'package:daengnyang/screens/settings/suggestion_screen.dart';
import 'package:daengnyang/screens/settings/family_group_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _pets = [];
  bool _isLoading = true;

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
    XFile? selectedImage;
    bool isLoading = false;

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

                    // 프로필 사진
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80,
                              );
                              if (image != null) {
                                final cropped = await ImageCropper().cropImage(
                                  sourcePath: image.path,
                                  aspectRatio: const CropAspectRatio(
                                    ratioX: 1,
                                    ratioY: 1,
                                  ),
                                  uiSettings: [
                                    AndroidUiSettings(
                                      toolbarTitle: '사진 편집',
                                      toolbarColor: AppColors.primary,
                                      toolbarWidgetColor: Colors.white,
                                      initAspectRatio:
                                          CropAspectRatioPreset.square,
                                      lockAspectRatio: true,
                                    ),
                                  ],
                                );
                                if (cropped != null) {
                                  setModalState(
                                    () => selectedImage = XFile(cropped.path),
                                  );
                                }
                              }
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: AppColors.accent,
                                  backgroundImage: selectedImage != null
                                      ? FileImage(File(selectedImage!.path))
                                      : pet['profileImage'] != null
                                      ? NetworkImage(pet['profileImage'])
                                            as ImageProvider
                                      : null,
                                  child:
                                      selectedImage == null &&
                                          pet['profileImage'] == null
                                      ? Image.asset(
                                          pet['species'] == 'cat'
                                              ? 'assets/images/cat.png'
                                              : 'assets/images/dog.png',
                                          width: 56,
                                          height: 56,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (pet['profileImage'] != null ||
                              selectedImage != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                selectedImage = null;
                                pet['profileImage'] = null;
                              }),
                              child: const Text(
                                '기본 사진으로 되돌리기',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

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
                        onPressed: isLoading
                            ? null
                            : () async {
                                setModalState(() => isLoading = true);

                                String? profileImageUrl = pet['profileImage'];

                                // 이미지 업로드
                                if (selectedImage != null) {
                                  final ref = FirebaseStorage.instance
                                      .ref()
                                      .child('pets/${pet['id']}/profile.jpg');
                                  await ref.putFile(File(selectedImage!.path));
                                  profileImageUrl = await ref.getDownloadURL();
                                }

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
                                      'profileImage': profileImageUrl,
                                    });

                                if (mounted) {
                                  Navigator.pop(context);
                                  _loadData();
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
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

    // async 이전에 navigator/messenger 저장 (signOut 후 mounted가 false가 돼도 동작)
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // 1. FCM 토큰 무효화 (탈퇴 진행 전 푸시 알림 차단)
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': null});
    } catch (_) {}

    // 2. Firestore 데이터 삭제
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();

      final pets = await FirebaseFirestore.instance
          .collection('pets')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in pets.docs) {
        await doc.reference.delete();
      }

      final posts = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in posts.docs) {
        final comments = await FirebaseFirestore.instance
            .collection('comments')
            .where('postId', isEqualTo: doc.id)
            .get();
        for (final c in comments.docs) {
          await c.reference.delete();
        }
        final likes = await FirebaseFirestore.instance
            .collection('likes')
            .where('postId', isEqualTo: doc.id)
            .get();
        for (final l in likes.docs) {
          await l.reference.delete();
        }
        await doc.reference.delete();
      }

      final myComments = await FirebaseFirestore.instance
          .collection('comments')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in myComments.docs) {
        await doc.reference.delete();
      }

      final petIds = pets.docs.map((e) => e.id).toList();
      if (petIds.isNotEmpty) {
        final healthRecords = await FirebaseFirestore.instance
            .collection('healthRecords')
            .where('petId', whereIn: petIds)
            .get();
        for (final doc in healthRecords.docs) {
          await doc.reference.delete();
        }
        final calendars = await FirebaseFirestore.instance
            .collection('calendars')
            .where('petId', whereIn: petIds)
            .get();
        for (final doc in calendars.docs) {
          await doc.reference.delete();
        }
      }

      final chats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();
      for (final doc in chats.docs) {
        final messages = await FirebaseFirestore.instance
            .collection('messages')
            .where('chatId', isEqualTo: doc.id)
            .get();
        for (final msg in messages.docs) {
          await msg.reference.delete();
        }
        await doc.reference.delete();
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('오류가 발생했어요. 다시 시도해주세요')),
      );
      return;
    }

    // 3. Firebase Auth 계정 삭제 (실패해도 아래 로그아웃·이동은 반드시 실행)
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        messenger.showSnackBar(
          const SnackBar(content: Text('잠시 후 다시 시도해주세요')),
        );
      }
    } catch (_) {}

    // 4. 로그아웃
    try {
      await AuthService().signOut();
    } catch (_) {}

    // 5. LoginScreen으로 이동 (mounted 여부와 무관하게 저장된 navigator 사용)
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
      await _loadData();
      if (mounted && _pets.isEmpty) {
        Navigator.of(context).pop();
      }
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

                  // 가족
                  _buildSectionHeader('가족'),
                  _buildCard(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.people_outline,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        '가족 공유',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: const Text(
                        '가족과 반려동물 일정을 함께 관리해요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMid,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
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
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8B6914),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textLight,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FamilyGroupScreen(),
                        ),
                      ).then((_) => _loadData()),
                    ),
                  ),

                  // 지원
                  _buildSectionHeader('지원'),
                  _buildCard(
                    child: Column(
                      children: [
                        _buildListTile(
                          icon: Icons.chat_bubble_outline,
                          title: '관리자에게 문의',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SuggestionScreen(),
                            ),
                          ),
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
                            final navigator = Navigator.of(context);
                            final userId = FirebaseAuth.instance.currentUser?.uid;
                            if (userId != null) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .update({'fcmToken': null});
                              } catch (_) {}
                            }
                            await AuthService().signOut();
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
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
