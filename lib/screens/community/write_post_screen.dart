import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/bad_words.dart';

class WritePostScreen extends StatefulWidget {
  final String category;
  const WritePostScreen({super.key, required this.category});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isUploading = false;
  String _petType = 'dog';
  String _itemCategory = '사료';
  String _postTag = '전체';
  String _region = '전체';
  String _tradeType = '판매해요';

  final List<String> _itemCategories = ['사료', '간식', '용품', '기타'];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 70);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        if (_selectedImages.length > 5) {
          _selectedImages.removeRange(5, _selectedImages.length);
        }
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> urls = [];
    for (final image in _selectedImages) {
      final ref = FirebaseStorage.instance.ref().child(
        'posts/${DateTime.now().millisecondsSinceEpoch}_${image.name}',
      );
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submitPost() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      return;
    }

    if (widget.category == 'community' && _postTag == '전체') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('말머리를 선택해주세요')));
      return;
    }

    if (widget.category == 'trade' && _region == '전체') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지역을 선택해주세요')));
      return;
    }

    if (BadWords.contains(_titleController.text) ||
        BadWords.contains(_contentController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('부적절한 표현이 포함되어 있어요')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final oneHourAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      final recentPosts = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: oneHourAgo)
          .get();
      if (recentPosts.docs.length >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('1시간 내 3개까지만 등록할 수 있어요')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final nickname = userDoc.data()?['nickname'] ?? '익명';

      setState(() => _isUploading = true);
      final imageUrls = await _uploadImages();
      setState(() => _isUploading = false);

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': userId,
        'nickname': nickname,
        'category': widget.category,
        'tag': widget.category == 'community' ? _postTag : null,
        'region': widget.category == 'trade' ? _region : null,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'images': imageUrls,
        'price': widget.category == 'trade'
            ? int.tryParse(_priceController.text.replaceAll(',', ''))
            : null,
        'tradeType': widget.category == 'trade' ? _tradeType : null,
        'petType': widget.category == 'trade' ? _petType : null,
        'itemCategory': widget.category == 'trade' ? _itemCategory : null,
        'likesCount': 0,
        'commentsCount': 0,
        'isBlacklisted': false,
        'reportCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      setState(() {
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category == 'community' ? '게시글 작성' : '중고거래 등록'),
        actions: [
          TextButton(
            onPressed: (_isLoading || _isUploading) ? null : _submitPost,
            child: (_isLoading || _isUploading)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '등록',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.category == 'community') ...[
              const Text(
                '말머리',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['자유', '질문', '정보'].map((tag) {
                  final isSelected = _postTag == tag;
                  return GestureDetector(
                    onTap: () => setState(() => _postTag = tag),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
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
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textMid,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (widget.category == 'trade') ...[
              const Text(
                '거래 유형',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['판매해요', '구해요'].map((type) {
                  final isSelected = _tradeType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _tradeType = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
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
                        type,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textMid,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                '지역',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _region,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: [
                  '전체',
                  '서울',
                  '경기',
                  '인천',
                  '부산',
                  '대구',
                  '대전',
                  '광주',
                  '울산',
                  '세종',
                  '강원',
                  '충북',
                  '충남',
                  '전북',
                  '전남',
                  '경북',
                  '경남',
                  '제주',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _region = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                '반려동물 유형',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeButton('dog', '강아지'),
                  const SizedBox(width: 8),
                  _buildTypeButton('cat', '고양이'),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '품목',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _itemCategories.map((cat) {
                  final isSelected = _itemCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _itemCategory = cat),
                    child: Container(
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
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textMid,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '제목',
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
            if (widget.category == 'trade') ...[
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '가격 (원)',
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
            ],
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: '내용',
                alignLabelWithHint: true,
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
            GestureDetector(
              onTap: _pickImages,
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
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      color: AppColors.textMid,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedImages.isEmpty
                          ? '이미지 첨부 (최대 5장)'
                          : '${_selectedImages.length}장 선택됨',
                      style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(
                                File(_selectedImages[index].path),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedImages.removeAt(index)),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label) {
    final isSelected = _petType == type;
    return GestureDetector(
      onTap: () => setState(() => _petType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}
