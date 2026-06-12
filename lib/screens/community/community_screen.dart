import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/bad_words.dart';
import 'package:daengnyang/screens/chat/chat_list_screen.dart';
import 'package:daengnyang/screens/chat/chat_screen.dart';
import 'package:daengnyang/core/empty_widget.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentCategory = 'community';
  String _currentTag = '전체'; // 게시판 탭에서 선택된 말머리 필터

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentCategory = _tabController.index == 0 ? 'community' : 'trade';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('커뮤니티'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '게시판'),
            Tab(text: '중고거래'),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where(
                  'participants',
                  arrayContains: FirebaseAuth.instance.currentUser?.uid,
                )
                .snapshots(),
            builder: (context, snapshot) {
              int unreadTotal = 0;
              if (snapshot.hasData) {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  unreadTotal +=
                      ((data['unreadCount']
                                  as Map<String, dynamic>?)?[userId] ??
                              0)
                          as int;
                }
              }
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadTotal > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showWritePost(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostList(
            category: 'community',
            selectedTag: _currentTag,
            onTagChanged: (tag) => setState(() => _currentTag = tag),
          ),
          const _TradeList(),
        ],
      ),
    );
  }

  void _showWritePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WritePostScreen(category: _currentCategory),
      ),
    );
  }
}

// 게시판 목록
class _PostList extends StatefulWidget {
  final String category;
  final String selectedTag;
  final ValueChanged<String> onTagChanged;

  const _PostList({
    required this.category,
    required this.selectedTag,
    required this.onTagChanged,
  });

  @override
  State<_PostList> createState() => _PostListState();
}

class _PostListState extends State<_PostList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  final List<String> _suggestions = [
    '슬개골',
    '피부병',
    '관절',
    '토 색',
    '사료 추천',
    '백내장',
    '심장병',
    '중성화',
    '구토',
    '설사',
    '눈물자국',
    '귀 염증',
    '발톱',
    '치석',
    '비만',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    return Column(
      children: [
        // 검색창
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '게시글 검색',
              hintStyle: const TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textMid,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textMid,
                        size: 18,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _isSearching = v.isNotEmpty;
            }),
          ),
        ),

        // 말머리 탭 필터
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: ['전체', '자유', '질문', '정보'].map((tag) {
                final isSelected = widget.selectedTag == tag;
                final index = ['전체', '자유', '질문', '정보'].indexOf(tag);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTagChanged(tag),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textMid,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 게시글 목록
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.selectedTag == '전체'
                ? FirebaseFirestore.instance
                      .collection('posts')
                      .where('category', isEqualTo: widget.category)
                      .where('isBlacklisted', isEqualTo: false)
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                : FirebaseFirestore.instance
                      .collection('posts')
                      .where('category', isEqualTo: widget.category)
                      .where('tag', isEqualTo: widget.selectedTag)
                      .where('isBlacklisted', isEqualTo: false)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Column(
                  children: [
                    const Expanded(child: EmptyWidget(message: '게시글이 없어요')),
                    _buildMyActivityButton(context),
                  ],
                );
              }

              var allPosts = snapshot.data!.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList();

              // 검색 필터
              if (_searchQuery.isNotEmpty) {
                allPosts = allPosts
                    .where(
                      (post) => (post['title'] as String? ?? '')
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()),
                    )
                    .toList();
              }

              if (allPosts.isEmpty) {
                return Column(
                  children: [
                    Expanded(
                      child: EmptyWidget(message: '"$_searchQuery" 검색 결과가 없어요'),
                    ),
                    _buildMyActivityButton(context),
                  ],
                );
              }

              // 검색 중이면 인기게시글 없이 바로 목록
              if (_isSearching) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allPosts.length,
                        itemBuilder: (context, index) =>
                            _PostCard(post: allPosts[index]),
                      ),
                    ),
                    _buildMyActivityButton(context),
                  ],
                );
              }

              // TOP3
              final topPosts =
                  allPosts.where((post) {
                    final createdAt = post['createdAt'];
                    if (createdAt == null) return false;
                    final date = (createdAt as Timestamp).toDate();
                    return date.isAfter(threeMonthsAgo) &&
                        (post['likesCount'] ?? 0) > 0;
                  }).toList()..sort(
                    (a, b) =>
                        (b['likesCount'] ?? 0).compareTo(a['likesCount'] ?? 0),
                  );
              final top3 = topPosts.take(3).toList();

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      itemCount:
                          allPosts.length +
                          (top3.isNotEmpty ? top3.length + 2 : 0),
                      itemBuilder: (context, index) {
                        if (top3.isNotEmpty) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '인기 게시글',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (index <= top3.length)
                            return _PostCard(
                              post: top3[index - 1],
                              isTop: true,
                            );
                          if (index == top3.length + 1) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.textMid,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '전체 게시글',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return _PostCard(
                            post: allPosts[index - top3.length - 2],
                          );
                        }
                        return _PostCard(post: allPosts[index]);
                      },
                    ),
                  ),
                  _buildMyActivityButton(context),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyActivityButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyActivityScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.textMid,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '내 활동',
                    style: TextStyle(fontSize: 12, color: AppColors.textMid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeList extends StatefulWidget {
  const _TradeList();

  @override
  State<_TradeList> createState() => _TradeListState();
}

class _TradeListState extends State<_TradeList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _petType = 'all';
  String _itemCategory = '전체';
  String _region = '전체';
  bool _hideSold = false;
  bool _showLikedOnly = false;
  List<String> _likedPostIds = [];

  final List<String> _itemCategories = ['전체', '사료', '간식', '용품', '기타'];
  final List<String> _suggestions = [
    '캣타워',
    '사료',
    '간식',
    '하네스',
    '목줄',
    '장난감',
    '캐리어',
    '모래',
    '패드',
    '빗',
  ];

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPetTypeDropdown() {
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
              _buildDropdownItem('전체', _petType == 'all', () {
                setState(() => _petType = 'all');
                Navigator.pop(context);
              }),
              _buildDropdownItem('강아지', _petType == 'dog', () {
                setState(() => _petType = 'dog');
                Navigator.pop(context);
              }),
              _buildDropdownItem('고양이', _petType == 'cat', () {
                setState(() => _petType = 'cat');
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryDropdown() {
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
              ...['전체', '사료', '간식', '용품', '기타']
                  .map(
                    (cat) => _buildDropdownItem(cat, _itemCategory == cat, () {
                      setState(() => _itemCategory = cat);
                      Navigator.pop(context);
                    }),
                  )
                  .toList(),
            ],
          ),
        );
      },
    );
  }

  void _showRegionDropdown() {
    final regions = [
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
    ];
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: regions
                        .map(
                          (r) => _buildDropdownItem(r, _region == r, () {
                            setState(() => _region = r);
                            Navigator.pop(context);
                          }),
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

  Widget _buildDropdownItem(String label, bool isSelected, VoidCallback onTap) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textDark,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary, size: 18)
          : null,
      onTap: onTap,
    );
  }

  Future<void> _loadLikedPosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('likes')
        .where('userId', isEqualTo: userId)
        .get();
    if (mounted) {
      setState(() {
        _likedPostIds = snapshot.docs
            .map((doc) => doc.data()['postId'] as String)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String petTypeLabel = _petType == 'all'
        ? '전체'
        : _petType == 'dog'
        ? '강아지'
        : '고양이';

    return Column(
      children: [
        // 검색창
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '상품 검색',
              hintStyle: const TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textMid,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textMid,
                        size: 18,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(height: 8),

        // 필터 드롭다운 한 줄
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 지역
              Expanded(
                child: GestureDetector(
                  onTap: _showRegionDropdown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _region != '전체'
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _region != '전체'
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _region,
                          style: TextStyle(
                            fontSize: 13,
                            color: _region != '전체'
                                ? AppColors.primary
                                : AppColors.textMid,
                            fontWeight: _region != '전체'
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: _region != '전체'
                              ? AppColors.primary
                              : AppColors.textMid,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 반려동물 유형
              Expanded(
                child: GestureDetector(
                  onTap: _showPetTypeDropdown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _petType != 'all'
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _petType != 'all'
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          petTypeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: _petType != 'all'
                                ? AppColors.primary
                                : AppColors.textMid,
                            fontWeight: _petType != 'all'
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: _petType != 'all'
                              ? AppColors.primary
                              : AppColors.textMid,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 품목
              Expanded(
                child: GestureDetector(
                  onTap: _showCategoryDropdown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _itemCategory != '전체'
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _itemCategory != '전체'
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _itemCategory,
                          style: TextStyle(
                            fontSize: 13,
                            color: _itemCategory != '전체'
                                ? AppColors.primary
                                : AppColors.textMid,
                            fontWeight: _itemCategory != '전체'
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: _itemCategory != '전체'
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
        // 판매완료 제외 + 찜 목록 토글
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _hideSold = !_hideSold),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _hideSold
                            ? AppColors.primary
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _hideSold
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: _hideSold
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '판매완료 제외',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  await _loadLikedPosts();
                  setState(() => _showLikedOnly = !_showLikedOnly);
                },
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _showLikedOnly
                            ? AppColors.primary
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _showLikedOnly
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: _showLikedOnly
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '찜 목록',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 게시글 목록
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('category', isEqualTo: 'trade')
                .where('isBlacklisted', isEqualTo: false)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return Column(
                  children: [
                    const Expanded(child: EmptyWidget(message: '게시글이 없어요')),
                    _buildMyActivityButton(context),
                  ],
                );
              }

              var allPosts = snapshot.data!.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList();

              if (_region != '전체') {
                allPosts = allPosts
                    .where((p) => p['region'] == _region)
                    .toList();
              }
              if (_petType != 'all') {
                allPosts = allPosts
                    .where((p) => p['petType'] == _petType)
                    .toList();
              }
              if (_itemCategory != '전체') {
                allPosts = allPosts
                    .where((p) => p['itemCategory'] == _itemCategory)
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                allPosts = allPosts
                    .where(
                      (p) => (p['title'] as String? ?? '')
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()),
                    )
                    .toList();
              }
              if (_hideSold) {
                allPosts = allPosts.where((p) => p['isSold'] != true).toList();
              }
              if (_showLikedOnly) {
                allPosts = allPosts
                    .where((p) => _likedPostIds.contains(p['id']))
                    .toList();
              }

              allPosts.sort((a, b) {
                final aTime = a['lastBoostedAt'] != null
                    ? (a['lastBoostedAt'] as Timestamp).toDate()
                    : (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                final bTime = b['lastBoostedAt'] != null
                    ? (b['lastBoostedAt'] as Timestamp).toDate()
                    : (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                return bTime.compareTo(aTime);
              });

              if (allPosts.isEmpty) {
                return Column(
                  children: [
                    const Expanded(child: EmptyWidget(message: '게시글이 없어요')),
                    _buildMyActivityButton(context),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      itemCount: allPosts.length,
                      itemBuilder: (context, index) {
                        return _PostCard(post: allPosts[index]);
                      },
                    ),
                  ),
                  _buildMyActivityButton(context),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyActivityButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyActivityScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.textMid,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '내 활동',
                    style: TextStyle(fontSize: 12, color: AppColors.textMid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isTop;

  const _PostCard({required this.post, this.isTop = false});

  @override
  Widget build(BuildContext context) {
    final createdAt = post['createdAt'] != null
        ? (post['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final isSold = post['isSold'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(postId: post['id']),
        ),
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: isSold ? 0.5 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTop
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.cardBorder,
                  width: isTop ? 1 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isTop)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '인기',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      // 말머리 뱃지 (커뮤니티 게시글)
                      if (post['category'] == 'community' &&
                          post['tag'] != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _tagColor(post['tag']).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _tagColor(post['tag']).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            post['tag'],
                            style: TextStyle(
                              fontSize: 10,
                              color: _tagColor(post['tag']),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // 거래 유형 뱃지 (중고거래 게시글)
                      if (post['category'] == 'trade' &&
                          post['tradeType'] != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: post['tradeType'] == '판매해요'
                                ? const Color(0xFFE67E22).withValues(alpha: 0.12)
                                : const Color(0xFF27AE60).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: post['tradeType'] == '판매해요'
                                  ? const Color(0xFFE67E22).withValues(alpha: 0.4)
                                  : const Color(0xFF27AE60).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            post['tradeType'] == '판매해요' ? '판매해요' : '구해요',
                            style: TextStyle(
                              fontSize: 10,
                              color: post['tradeType'] == '판매해요'
                                  ? const Color(0xFFE67E22)
                                  : const Color(0xFF27AE60),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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
                  const SizedBox(height: 4),
                  Text(
                    post['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post['images'] != null &&
                      (post['images'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (post['images'] as List).length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              image: DecorationImage(
                                image: NetworkImage(
                                  (post['images'] as List)[index],
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        post['nickname'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      const Spacer(),
                      if (post['category'] == 'trade' && post['price'] != null)
                        Text(
                          '${_formatPrice(post['price'])}원',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      if (post['category'] != 'trade') ...[
                        const Icon(
                          Icons.favorite_outline,
                          size: 13,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${post['likesCount'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 13,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${post['commentsCount'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 판매완료 오버레이
          if (isSold)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/sad.png', height: 60),
                    const SizedBox(height: 8),
                    const Text(
                      '거래가 완료되었어요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _tagColor(String? tag) {
    switch (tag) {
      case '질문':
        return const Color(0xFF4A90D9);
      case '정보':
        return const Color(0xFF27AE60);
      case '자유':
        return const Color(0xFFE67E22);
      default:
        return AppColors.textMid;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

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
            // 커뮤니티 말머리 선택
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

            // 중고거래 전용 필터
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
                items:
                    [
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
                        ]
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
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

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  String? _replyToId;
  String? _replyToNickname;
  bool _isLiked = false;
  bool _showLikeAnimation = false;
  Map<String, dynamic>? _post;

  @override
  void initState() {
    super.initState();
    _checkLiked();
    _loadPost();
  }

  Future<void> _loadPost() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    if (mounted) setState(() => _post = {'id': doc.id, ...doc.data() ?? {}});
  }

  Future<void> _checkLiked() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('likes')
        .doc('${widget.postId}_$userId')
        .get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  Future<void> _toggleLike() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final likeDoc = FirebaseFirestore.instance
        .collection('likes')
        .doc('${widget.postId}_$userId');
    final postDoc = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId);

    if (_isLiked) {
      await likeDoc.delete();
      await postDoc.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeDoc.set({
        'postId': widget.postId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postDoc.update({'likesCount': FieldValue.increment(1)});

      // 애니메이션 표시
      setState(() => _showLikeAnimation = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _showLikeAnimation = false);
    }
    setState(() => _isLiked = !_isLiked);
    _loadPost();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) return;
    if (BadWords.contains(_commentController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('부적절한 표현이 포함되어 있어요')));
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final nickname = userDoc.data()?['nickname'] ?? '익명';

    await FirebaseFirestore.instance.collection('comments').add({
      'postId': widget.postId,
      'userId': userId,
      'nickname': nickname,
      'content': _commentController.text.trim(),
      'parentId': _replyToId,
      'reportCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'commentsCount': FieldValue.increment(1)});

    setState(() {
      _replyToId = null;
      _replyToNickname = null;
    });
    _commentController.clear();
  }

  Future<void> _reportPost() async {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'reportCount': FieldValue.increment(1)});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고가 접수됐어요')));
    }
  }

  Future<void> _deletePost() async {
    // 댓글 먼저 삭제
    final comments = await FirebaseFirestore.instance
        .collection('comments')
        .where('postId', isEqualTo: widget.postId)
        .get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }

    // 좋아요 삭제
    final likes = await FirebaseFirestore.instance
        .collection('likes')
        .where('postId', isEqualTo: widget.postId)
        .get();
    for (final doc in likes.docs) {
      await doc.reference.delete();
    }

    // 게시글 삭제
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .delete();

    if (mounted) Navigator.pop(context);
  }

  void _showBoostBottomSheet() {
    final now = DateTime.now();
    final createdAt = _post?['createdAt'] != null
        ? (_post!['createdAt'] as Timestamp).toDate()
        : now;
    final lastBoostedAt = _post?['lastBoostedAt'] != null
        ? (_post!['lastBoostedAt'] as Timestamp).toDate()
        : null;
    final lastActivity = lastBoostedAt ?? createdAt;
    final canBoost = now.difference(lastActivity).inHours >= 48;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '끌어올리기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '48시간이 지나면 끌어올릴 수 있어요',
                style: TextStyle(fontSize: 14, color: AppColors.textMid),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: canBoost
                      ? () async {
                          Navigator.pop(context);
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.postId)
                              .update({
                            'lastBoostedAt': FieldValue.serverTimestamp(),
                          });
                          _loadPost();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canBoost ? AppColors.primary : Colors.grey.shade300,
                    foregroundColor:
                        canBoost ? Colors.white : Colors.grey.shade500,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '끌어올리기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditPostDialog() {
    final titleController = TextEditingController(text: _post?['title'] ?? '');
    final contentController = TextEditingController(
      text: _post?['content'] ?? '',
    );
    final priceController = TextEditingController(
      text: _post?['price'] != null ? '${_post!['price']}' : '',
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '게시글 수정',
                  style: TextStyle(
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
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_post?['category'] == 'trade') ...[
                  TextField(
                    controller: priceController,
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
                  controller: contentController,
                  maxLines: 8,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty ||
                          contentController.text.isEmpty) {
                        return;
                      }
                      if (BadWords.contains(titleController.text) ||
                          BadWords.contains(contentController.text)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('부적절한 표현이 포함되어 있어요')),
                        );
                        return;
                      }
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.postId)
                          .update({
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim(),
                            if (_post?['category'] == 'trade')
                              'price': int.tryParse(
                                priceController.text.replaceAll(',', ''),
                              ),
                          });
                      if (mounted) {
                        Navigator.pop(context);
                        _loadPost();
                      }
                    },
                    child: const Text('수정하기', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startChat() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    final otherUserId = _post?['userId'] as String?;
    if (otherUserId == null) return;

    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    String? chatId;
    for (final doc in existing.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(otherUserId) &&
          data['postId'] == widget.postId) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final newChat = await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUserId, otherUserId],
        'postId': widget.postId,
        'postTitle': _post?['title'],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      });
      chatId = newChat.id;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId!,
            otherUserId: otherUserId,
            otherNickname: _post?['nickname'] ?? '',
            postTitle: _post?['title'] ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('게시글'),
            actions: [
              if (_post != null)
                PopupMenuButton(
                  itemBuilder: (context) {
                    final isOwner = _post?['userId'] == userId;
                    return [
                      if (isOwner)
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                      if (isOwner)
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      if (!isOwner)
                        const PopupMenuItem(value: 'report', child: Text('신고')),
                    ];
                  },
                  onSelected: (value) {
                    if (value == 'edit') _showEditPostDialog();
                    if (value == 'delete') _deletePost();
                    if (value == 'report') _reportPost();
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('comments')
                      .where('postId', isEqualTo: widget.postId)
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final comments =
                        snapshot.data?.docs
                            .map(
                              (doc) => {
                                'id': doc.id,
                                ...doc.data() as Map<String, dynamic>,
                              },
                            )
                            .toList() ??
                        [];
                    final parentComments = comments
                        .where((c) => c['parentId'] == null)
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: parentComments.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildPostContent();
                        final comment = parentComments[index - 1];
                        final replies = comments
                            .where((c) => c['parentId'] == comment['id'])
                            .toList();
                        return _buildComment(comment, replies);
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.cardBorder, width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyToNickname != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              '$_replyToNickname 님에게 답글 작성 중',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _replyToId = null;
                                _replyToNickname = null;
                              }),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: '댓글을 입력해주세요',
                              hintStyle: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _submitComment,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 하트 애니메이션
        if (_showLikeAnimation)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showLikeAnimation ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/love.png', height: 120),
                      const SizedBox(height: 12),
                      Text(
                        _post?['category'] == 'trade'
                            ? '이 상품을 찜했어요'
                            : '이 게시글을 추천했어요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostContent() {
    if (_post == null) return const SizedBox();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final createdAt = _post?['createdAt'] != null
        ? (_post!['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final isSold = _post?['isSold'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _post?['title'] ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _post?['nickname'] ?? '',
                style: const TextStyle(fontSize: 12, color: AppColors.textMid),
              ),
              const SizedBox(width: 8),
              Text(
                '${createdAt.month}/${createdAt.day}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          if (_post?['category'] == 'trade' && _post?['price'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_post!['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
          const Divider(height: 24),
          Text(
            _post?['content'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              height: 1.6,
            ),
          ),
          if (_post?['images'] != null &&
              (_post!['images'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (_post!['images'] as List).length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _ImageViewerScreen(
                          images: List<String>.from(_post!['images']),
                          initialIndex: index,
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(
                            (_post!['images'] as List)[index],
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_outline,
                      size: 18,
                      color: _isLiked ? Colors.red : AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_post?['likesCount'] ?? 0}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isLiked ? Colors.red : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                '${_post?['commentsCount'] ?? 0}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          if (_post?['category'] == 'trade' &&
              _post?['userId'] == userId &&
              _post?['isSold'] != true) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _showBoostBottomSheet,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                label: const Text('끌어올리기'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder),
                  foregroundColor: AppColors.textMid,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('판매 완료'),
                      content: const Text('거래가 완료됐나요?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            '완료',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .update({'isSold': true});
                    _loadPost();
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('판매 완료'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          if (isSold) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Image.asset('assets/images/sad.png', height: 80),
                  const SizedBox(height: 8),
                  const Text(
                    '거래가 완료되었어요',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_post?['category'] == 'trade' && _post?['userId'] != userId) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('메세지 보내기'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComment(
    Map<String, dynamic> comment,
    List<Map<String, dynamic>> replies,
  ) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final createdAt = comment['createdAt'] != null
        ? (comment['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    comment['nickname'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${createdAt.month}/${createdAt.day}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (comment['userId'] == userId)
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('comments')
                                .doc(comment['id'])
                                .delete();
                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.postId)
                                .update({
                                  'commentsCount': FieldValue.increment(-1),
                                });
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      if (comment['userId'] != userId)
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('comments')
                                .doc(comment['id'])
                                .update({
                                  'reportCount': FieldValue.increment(1),
                                });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('신고가 접수됐어요')),
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment['content'] ?? '',
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _replyToId = comment['id'];
                  _replyToNickname = comment['nickname'];
                }),
                child: const Text(
                  '답글 달기',
                  style: TextStyle(fontSize: 11, color: AppColors.textMid),
                ),
              ),
            ],
          ),
        ),
        ...replies.map((reply) {
          final replyDate = reply['createdAt'] != null
              ? (reply['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          return Container(
            margin: const EdgeInsets.only(left: 20, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reply['nickname'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${replyDate.month}/${replyDate.day}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        if (reply['userId'] == userId)
                          GestureDetector(
                            onTap: () async {
                              await FirebaseFirestore.instance
                                  .collection('comments')
                                  .doc(reply['id'])
                                  .delete();
                              await FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(widget.postId)
                                  .update({
                                    'commentsCount': FieldValue.increment(-1),
                                  });
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        if (reply['userId'] != userId)
                          GestureDetector(
                            onTap: () async {
                              await FirebaseFirestore.instance
                                  .collection('comments')
                                  .doc(reply['id'])
                                  .update({
                                    'reportCount': FieldValue.increment(1),
                                  });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('신고가 접수됐어요')),
                                );
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.flag_outlined,
                                size: 14,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply['content'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 활동'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '내 게시글'),
            Tab(text: '내 댓글'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyWidget(message: '작성한 게시글이 없어요');
              }
              final posts = snapshot.data!.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList();
              return ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) => _PostCard(post: posts[index]),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('comments')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyWidget(message: '작성한 댓글이 없어요');
              }
              final comments = snapshot.data!.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList();
              return ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  final createdAt = comment['createdAt'] != null
                      ? (comment['createdAt'] as Timestamp).toDate()
                      : DateTime.now();
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PostDetailScreen(postId: comment['postId']),
                      ),
                    ),
                    child: Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['content'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${createdAt.month}/${createdAt.day}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ImageViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
