import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/pet_breeds.dart';
import 'package:daengnyang/screens/home/home_screen.dart';

class PetRegisterScreen extends StatefulWidget {
  const PetRegisterScreen({super.key});

  @override
  State<PetRegisterScreen> createState() => _PetRegisterScreenState();
}

class _PetRegisterScreenState extends State<PetRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();

  String _species = 'dog';
  String _gender = 'male';
  String? _selectedBreed;
  String? _selectedCategory;
  DateTime _birthDate = DateTime.now();
  bool _isLoading = false;
  bool _isNeutered = false;
  bool _weightUnknown = false;
  bool _birthUnknown = false;
  XFile? _profileImage;

  Map<String, List<String>> get _currentBreeds =>
      _species == 'dog' ? PetBreeds.dogBreeds : PetBreeds.catBreeds;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: '프로필 사진 편집'),
        IOSUiSettings(title: '프로필 사진 편집'),
      ],
    );
    if (cropped != null) setState(() => _profileImage = XFile(cropped.path));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _showBreedPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempCategory = _selectedCategory ?? _currentBreeds.keys.first;
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 검색어 기반 필터링
            List<String> filteredBreeds = searchQuery.isEmpty
                ? _currentBreeds[tempCategory]!
                : _currentBreeds.values
                      .expand((list) => list)
                      .where((breed) => breed.contains(searchQuery))
                      .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
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
                      '품종 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 검색창
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setModalState(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: '품종 검색',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textMid,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 카테고리 탭 (검색어 없을 때만 표시)
                    if (searchQuery.isEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _currentBreeds.keys.map((category) {
                            final isSelected = tempCategory == category;
                            return GestureDetector(
                              onTap: () =>
                                  setModalState(() => tempCategory = category),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
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
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMid,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    if (searchQuery.isEmpty) const SizedBox(height: 12),

                    // 품종 목록
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        itemCount: filteredBreeds.length,
                        itemBuilder: (context, index) {
                          final breed = filteredBreeds[index];
                          return ListTile(
                            title: Text(
                              breed,
                              style: const TextStyle(color: AppColors.textDark),
                            ),
                            trailing: _selectedBreed == breed
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedBreed = breed;
                                _selectedCategory = tempCategory;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBreed == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('품종을 선택해주세요')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final petId = FirebaseFirestore.instance.collection('pets').doc().id;

      String? profileImageUrl;
      if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('pets/$petId/profile.jpg');
        await ref.putFile(File(_profileImage!.path));
        profileImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('pets').doc(petId).set({
        'userId': userId,
        'name': _nameController.text.trim(),
        'species': _species,
        'breed': _selectedBreed,
        'gender': _gender,
        'birthDate': _birthUnknown ? null : Timestamp.fromDate(_birthDate),
        'weight': _weightUnknown
            ? 0.0
            : double.parse(_weightController.text.trim()),
        'isNeutered': _isNeutered,
        'profileImage': profileImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('반려동물 등록 에러: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('반려동물 등록')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '어떤 친구인가요?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 24),

                // 프로필 사진
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: AppColors.accent,
                              backgroundImage: _profileImage != null
                                  ? FileImage(File(_profileImage!.path))
                                  : null,
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.pets,
                                      size: 40,
                                      color: AppColors.primary.withOpacity(0.6),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
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
                      const SizedBox(height: 8),
                      Text(
                        _profileImage == null ? '프로필 사진 추가' : '사진 변경',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      if (_profileImage != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => setState(() => _profileImage = null),
                          child: const Text(
                            '기본 사진으로 되돌리기',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 종 선택
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _species = 'dog';
                          _selectedBreed = null;
                          _selectedCategory = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _species == 'dog'
                                ? AppColors.primary
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _species == 'dog'
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/dog.png',
                                width: 48,
                                height: 48,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '강아지',
                                style: TextStyle(
                                  color: _species == 'dog'
                                      ? Colors.white
                                      : AppColors.textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _species = 'cat';
                          _selectedBreed = null;
                          _selectedCategory = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _species == 'cat'
                                ? AppColors.primary
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _species == 'cat'
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/cat.png',
                                width: 48,
                                height: 48,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '고양이',
                                style: TextStyle(
                                  color: _species == 'cat'
                                      ? Colors.white
                                      : AppColors.textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 이름
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? '이름을 입력해주세요' : null,
                ),
                const SizedBox(height: 16),

                // 품종 선택
                GestureDetector(
                  onTap: _showBreedPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
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
                          _selectedBreed ?? '품종 선택',
                          style: TextStyle(
                            color: _selectedBreed != null
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMid,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 성별
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _gender = 'male'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _gender == 'male'
                                ? AppColors.primary
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _gender == 'male'
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Text(
                            '수컷',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _gender == 'male'
                                  ? Colors.white
                                  : AppColors.textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _gender = 'female'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _gender == 'female'
                                ? AppColors.primary
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _gender == 'female'
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Text(
                            '암컷',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _gender == 'female'
                                  ? Colors.white
                                  : AppColors.textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 중성화 여부
                GestureDetector(
                  onTap: () => setState(() => _isNeutered = !_isNeutered),
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
                          value: _isNeutered,
                          onChanged: (v) => setState(() => _isNeutered = v),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 생일
                // 생일 모름 체크박스
                GestureDetector(
                  onTap: () {
                    setState(() => _birthUnknown = !_birthUnknown);
                    if (!_birthUnknown) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🐾', style: TextStyle(fontSize: 36)),
                            SizedBox(height: 12),
                            Text(
                              '내 새꾸의 새로운 생일을\n정해보는 건 어떠세요?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textDark,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '처음 만난 날이나 입양일을\n생일로 등록해도 좋아요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMid,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _birthUnknown
                              ? AppColors.primary
                              : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _birthUnknown
                                ? AppColors.primary
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: _birthUnknown
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '생일을 몰라요',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (!_birthUnknown)
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
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
                            '생일: ${_birthDate.year}.${_birthDate.month}.${_birthDate.day}',
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
                const SizedBox(height: 16),

                // 체중
                if (!_weightUnknown)
                  TextFormField(
                    controller: _weightController,
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
                    validator: (v) {
                      if (_weightUnknown) return null;
                      return v == null || v.isEmpty ? '체중을 입력해주세요' : null;
                    },
                  ),
                if (!_weightUnknown) const SizedBox(height: 8),

                // 체중 모름 체크박스
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _weightUnknown = !_weightUnknown;
                    if (_weightUnknown) _weightController.clear();
                  }),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _weightUnknown
                              ? AppColors.primary
                              : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _weightUnknown
                                ? AppColors.primary
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: _weightUnknown
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '체중을 잘 모르겠어요 (나중에 입력할게요)',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 등록 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('등록하기', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
