import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:daengnyang/core/colors.dart';

const String adminUid = '0x6rpTDXYchVDAKh9JXaxh7DsLG3';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static bool isAdmin() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == adminUid;
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin()) {
      return const Scaffold(body: Center(child: Text('접근 권한이 없어요')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('관리자'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMid,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: '신고된 게시글'),
              Tab(text: '신고된 댓글'),
              Tab(text: '상품 관리'),
              Tab(text: '건의사항'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReportedPostList(),
            _ReportedCommentList(),
            _ProductManagement(),
            _SuggestionList(),
          ],
        ),
      ),
    );
  }
}

class _ReportedPostList extends StatelessWidget {
  const _ReportedPostList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('reportCount', isGreaterThan: 0)
          .orderBy('reportCount', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              '신고된 게시글이 없어요',
              style: TextStyle(color: AppColors.textLight),
            ),
          );
        }
        final posts = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            final postId = posts[index].id;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '신고 ${post['reportCount']}건',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '작성자: ${post['nickname'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(postId)
                                .update({'reportCount': 0});
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '신고 무시',
                            style: TextStyle(
                              color: AppColors.textMid,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('게시글 삭제'),
                                content: const Text('이 게시글을 삭제할까요?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                                  .collection('posts')
                                  .doc(postId)
                                  .delete();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportedCommentList extends StatelessWidget {
  const _ReportedCommentList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('comments')
          .where('reportCount', isGreaterThan: 0)
          .orderBy('reportCount', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              '신고된 댓글이 없어요',
              style: TextStyle(color: AppColors.textLight),
            ),
          );
        }
        final comments = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            final commentId = comments[index].id;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '신고 ${comment['reportCount']}건',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment['nickname'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('comments')
                                .doc(commentId)
                                .update({'reportCount': 0});
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '신고 무시',
                            style: TextStyle(
                              color: AppColors.textMid,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('댓글 삭제'),
                                content: const Text('이 댓글을 삭제할까요?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                                  .collection('comments')
                                  .doc(commentId)
                                  .delete();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductManagement extends StatefulWidget {
  const _ProductManagement();

  @override
  State<_ProductManagement> createState() => _ProductManagementState();
}

class _ProductManagementState extends State<_ProductManagement> {
  String _selectedPetType = 'dog';
  String _selectedCategory = '사료';
  String? _selectedSubCategory;

  final Map<String, Map<String, List<String>>> _subCategories = {
    'dog': {
      '사료': ['전체', '퍼피', '어덜트', '시니어', '습식'],
      '간식': ['전체', '껌/뼈간식', '동결건조', '저키/육포', '캔/파우치', '소시지', '덴탈간식', '우유'],
      '용품': [
        '전체',
        '배변용품',
        '위생용품',
        '구강용품',
        '미용&관리',
        '목욕용품',
        '장난감&노즈워크',
        '훈련용품',
        '산책용품',
        '하우스&방석',
        '이동장&유모차',
        '의류&패션',
        '급식기&급수기',
        '기저귀',
        '넥카라',
      ],
      '영양제': ['전체', '관절', '피부/모질', '장/소화', '눈/귀', '면역', '종합'],
    },
    'cat': {
      '사료': ['전체', '키튼', '어덜트', '시니어', '습식'],
      '간식': [
        '전체',
        '파우치',
        '캔',
        '동결건조',
        '저키/스낵',
        '소시지',
        '캣닢&캣그라스',
        '덴탈간식',
        '파우더',
        '우유',
      ],
      '용품': [
        '전체',
        '모래&화장실',
        '장난감&사냥놀이',
        '스크래처',
        '구강용품',
        '미용&관리',
        '목욕용품',
        '위생용품',
        '의류',
        '하네스',
        '이동장&유모차',
        '급식기&급수기',
        '하우스&방석',
        '캣타워&캣휠',
        '넥카라',
        '울타리&안전문',
        '먹이퍼즐',
      ],
      '영양제': ['전체', '관절', '피부/모질', '장/소화', '눈/귀', '면역', '헤어볼'],
    },
  };

  List<String> get _currentSubCategories =>
      (_subCategories[_selectedPetType] ??
          _subCategories['dog']!)[_selectedCategory] ??
      [];

  void _showCategoryPicker() {
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
              ...['사료', '간식', '용품', '영양제'].map(
                (cat) => ListTile(
                  title: Text(
                    cat,
                    style: TextStyle(
                      color: _selectedCategory == cat
                          ? AppColors.primary
                          : AppColors.textDark,
                      fontWeight: _selectedCategory == cat
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _selectedCategory == cat
                      ? const Icon(
                          Icons.check,
                          color: AppColors.primary,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _selectedSubCategory = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubCategoryPicker() {
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _currentSubCategories
                        .map(
                          (sub) => ListTile(
                            title: Text(
                              sub,
                              style: TextStyle(
                                color:
                                    (sub == '전체' &&
                                            _selectedSubCategory == null) ||
                                        _selectedSubCategory == sub
                                    ? AppColors.primary
                                    : AppColors.textDark,
                                fontWeight:
                                    (sub == '전체' &&
                                            _selectedSubCategory == null) ||
                                        _selectedSubCategory == sub
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing:
                                (sub == '전체' && _selectedSubCategory == null) ||
                                    _selectedSubCategory == sub
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 18,
                                  )
                                : null,
                            onTap: () {
                              setState(
                                () => _selectedSubCategory = sub == '전체'
                                    ? null
                                    : sub,
                              );
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddProductDialog({
    Map<String, dynamic>? editProduct,
    String? docId,
  }) {
    final nameController = TextEditingController(
      text: editProduct?['name'] ?? '',
    );
    final descController = TextEditingController(
      text: editProduct?['description'] ?? '',
    );
    final coupangController = TextEditingController(
      text: editProduct?['coupangUrl'] ?? '',
    );
    String category = editProduct?['category'] ?? '사료';
    String subCategory = editProduct?['subCategory'] ?? '';
    String petType = editProduct?['petType'] ?? 'dog';
    List<String> tags = editProduct?['tags'] != null
        ? List<String>.from(editProduct!['tags'])
        : [];
    final tagController = TextEditingController();
    XFile? selectedImage;
    bool isLoading = false;

    final Map<String, Map<String, List<String>>> allSubCategories = {
      'dog': {
        '사료': ['퍼피', '어덜트', '시니어', '습식'],
        '간식': ['껌/뼈간식', '동결건조', '저키/육포', '캔/파우치', '소시지', '덴탈간식', '우유'],
        '용품': [
          '배변용품',
          '위생용품',
          '구강용품',
          '미용&관리',
          '목욕용품',
          '장난감&노즈워크',
          '훈련용품',
          '산책용품',
          '하우스&방석',
          '이동장&유모차',
          '의류&패션',
          '급식기&급수기',
          '기저귀',
          '넥카라',
        ],
        '영양제': ['관절', '피부/모질', '장/소화', '눈/귀', '면역', '종합'],
      },
      'cat': {
        '사료': ['키튼', '어덜트', '시니어', '습식'],
        '간식': [
          '파우치',
          '캔',
          '동결건조',
          '저키/스낵',
          '소시지',
          '캣닢&캣그라스',
          '덴탈간식',
          '파우더',
          '우유',
        ],
        '용품': [
          '모래&화장실',
          '장난감&사냥놀이',
          '스크래처',
          '구강용품',
          '미용&관리',
          '목욕용품',
          '위생용품',
          '의류',
          '하네스',
          '이동장&유모차',
          '급식기&급수기',
          '하우스&방석',
          '캣타워&캣휠',
          '넥카라',
          '울타리&안전문',
          '먹이퍼즐',
        ],
        '영양제': ['관절', '피부/모질', '장/소화', '눈/귀', '면역', '헤어볼'],
      },
    };

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
              height: MediaQuery.of(context).size.height * 0.9,
              child: Padding(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editProduct != null ? '상품 수정' : '상품 추가',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 반려동물 유형
                      const Text(
                        '반려동물',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['dog', 'cat'].map((type) {
                          final label = type == 'dog' ? '강아지' : '고양이';
                          final isSelected = petType == type;
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              petType = type;
                              subCategory = '';
                            }),
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
                                label,
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

                      // 대카테고리
                      const Text(
                        '카테고리',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['사료', '간식', '용품', '영양제'].map((cat) {
                            final isSelected = category == cat;
                            return GestureDetector(
                              onTap: () => setModalState(() {
                                category = cat;
                                subCategory = '';
                              }),
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
                                  cat,
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
                      const SizedBox(height: 12),

                      // 세부카테고리
                      const Text(
                        '세부 카테고리',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            ((allSubCategories[petType] ??
                                        allSubCategories['dog']!)[category] ??
                                    [])
                                .map((sub) {
                                  final isSelected = subCategory == sub;
                                  return GestureDetector(
                                    onTap: () =>
                                        setModalState(() => subCategory = sub),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.1)
                                            : AppColors.cardBackground,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.cardBorder,
                                        ),
                                      ),
                                      child: Text(
                                        sub,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textMid,
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                      ),
                      const SizedBox(height: 12),

                      // 상품명
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: '상품명',
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

                      // 특징
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: '특징/설명',
                          alignLabelWithHint: true,
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

                      // 쿠팡 링크
                      TextField(
                        controller: coupangController,
                        decoration: InputDecoration(
                          labelText: '쿠팡 파트너스 링크',
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

                      // 태그
                      const Text(
                        '태그',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tagController,
                              decoration: InputDecoration(
                                hintText: '태그 입력 후 추가',
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
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (tagController.text.isNotEmpty) {
                                setModalState(() {
                                  tags.add(tagController.text.trim());
                                  tagController.clear();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '추가',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: tags
                              .map(
                                (tag) => GestureDetector(
                                  onTap: () =>
                                      setModalState(() => tags.remove(tag)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tag,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // 이미지
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (image != null)
                            setModalState(() => selectedImage = image);
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
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                color: AppColors.textMid,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedImage != null
                                    ? '이미지 선택됨'
                                    : (editProduct?['imageUrl'] != null
                                          ? '이미지 변경'
                                          : '이미지 추가'),
                                style: const TextStyle(
                                  color: AppColors.textMid,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selectedImage != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(selectedImage!.path),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ] else if (editProduct?['imageUrl'] != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            editProduct!['imageUrl'],
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (nameController.text.isEmpty) return;
                                  setModalState(() => isLoading = true);
                                  String? imageUrl = editProduct?['imageUrl'];
                                  if (selectedImage != null) {
                                    final ref = FirebaseStorage.instance
                                        .ref()
                                        .child(
                                          'products/${DateTime.now().millisecondsSinceEpoch}.jpg',
                                        );
                                    await ref.putFile(
                                      File(selectedImage!.path),
                                    );
                                    imageUrl = await ref.getDownloadURL();
                                  }
                                  final data = {
                                    'name': nameController.text.trim(),
                                    'category': category,
                                    'subCategory': subCategory,
                                    'petType': petType,
                                    'description': descController.text.trim(),
                                    'coupangUrl': coupangController.text.trim(),
                                    'tags': tags,
                                    'imageUrl': imageUrl,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  };
                                  if (docId != null) {
                                    await FirebaseFirestore.instance
                                        .collection('products')
                                        .doc(docId)
                                        .update(data);
                                  } else {
                                    await FirebaseFirestore.instance
                                        .collection('products')
                                        .add(data);
                                  }
                                  if (mounted) Navigator.pop(context);
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
                              : Text(
                                  editProduct != null ? '수정하기' : '추가하기',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPetBtn(String type, String label) {
    final isSelected = _selectedPetType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedPetType = type;
        _selectedSubCategory = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 강아지/고양이 필터
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPetBtn('dog', '강아지'),
                const SizedBox(width: 8),
                _buildPetBtn('cat', '고양이'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 드롭다운 필터
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showCategoryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.textMid,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _showSubCategoryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedSubCategory != null
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedSubCategory != null
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedSubCategory ?? '전체',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedSubCategory != null
                                  ? AppColors.primary
                                  : AppColors.textMid,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: _selectedSubCategory != null
                                ? AppColors.primary
                                : AppColors.textMid,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedSubCategory != null
                  ? FirebaseFirestore.instance
                        .collection('products')
                        .where('petType', whereIn: [_selectedPetType, 'all'])
                        .where('category', isEqualTo: _selectedCategory)
                        .where('subCategory', isEqualTo: _selectedSubCategory)
                        .orderBy('createdAt', descending: true)
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('products')
                        .where('petType', whereIn: [_selectedPetType, 'all'])
                        .where('category', isEqualTo: _selectedCategory)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 상품이 없어요',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  );
                }
                final products = snapshot.data!.docs;
                return ListView.builder(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 4,
                    bottom: MediaQuery.of(context).padding.bottom + 80,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product =
                        products[index].data() as Map<String, dynamic>;
                    final docId = products[index].id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
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
                          if (product['imageUrl'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product['imageUrl'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                color: AppColors.textLight,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  '${product['category']} · ${product['subCategory'] ?? ''} · ${product['petType'] == 'dog' ? '강아지' : '고양이'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('수정'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  '삭제',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showAddProductDialog(
                                  editProduct: product,
                                  docId: docId,
                                );
                              } else if (value == 'delete') {
                                await FirebaseFirestore.instance
                                    .collection('products')
                                    .doc(docId)
                                    .delete();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const String _kConfirmedReply = '관리자가 문의사항을 확인했어요';

class _SuggestionList extends StatelessWidget {
  const _SuggestionList();

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Future<void> _markConfirmed(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('suggestions').doc(docId).update({
      'reply': _kConfirmedReply,
      'repliedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showDetail(BuildContext context, String docId, Map<String, dynamic> data) {
    final existingReply = data['reply'] == _kConfirmedReply ? '' : (data['reply'] ?? '');
    final replyController = TextEditingController(text: existingReply);
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['nickname'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                    ),
                    Text(
                      _formatDate(data['createdAt']),
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data['content'] ?? '',
                  style: const TextStyle(fontSize: 14, color: AppColors.textMid, height: 1.6),
                ),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          images[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (data['reply'] == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _markConfirmed(context, docId);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('확인 처리'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: replyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: '답변 입력',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (replyController.text.trim().isEmpty) return;
                            setModalState(() => isLoading = true);
                            await FirebaseFirestore.instance
                                .collection('suggestions')
                                .doc(docId)
                                .update({
                              'reply': replyController.text.trim(),
                              'repliedAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('답변 저장', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('suggestions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('문의가 없어요', style: TextStyle(color: AppColors.textLight)),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final hasReply = data['reply'] != null;
            return Opacity(
              opacity: hasReply ? 0.5 : 1.0,
              child: GestureDetector(
                onTap: () => _showDetail(context, docId, data),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                              data['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['nickname'] ?? ''} · ${_formatDate(data['createdAt'])}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasReply ? AppColors.accent : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasReply ? AppColors.primary : AppColors.cardBorder,
                          ),
                        ),
                        child: Text(
                          hasReply ? '완료' : '미답변',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasReply ? AppColors.primary : AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
