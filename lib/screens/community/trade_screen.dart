import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/empty_widget.dart';
import 'package:daengnyang/screens/community/post_card.dart';
import 'package:daengnyang/screens/community/my_activity_screen.dart';

class TradeList extends StatefulWidget {
  const TradeList({super.key});

  @override
  State<TradeList> createState() => _TradeListState();
}

class _TradeListState extends State<TradeList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _petType = 'all';
  String _itemCategory = '전체';
  String _region = '전체';
  bool _hideSold = false;
  bool _showLikedOnly = false;
  List<String> _likedPostIds = [];
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('posts')
        .where('category', isEqualTo: 'trade')
        .where('isBlacklisted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
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
                  ),
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

  Widget _buildDropdownItem(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
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
                          ? AppColors.primary.withValues(alpha: 0.1)
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
                          ? AppColors.primary.withValues(alpha: 0.1)
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
                          ? AppColors.primary.withValues(alpha: 0.1)
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

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return _buildScrollableEmpty();
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
                    : (a['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                final bTime = b['lastBoostedAt'] != null
                    ? (b['lastBoostedAt'] as Timestamp).toDate()
                    : (b['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                return bTime.compareTo(aTime);
              });

              if (allPosts.isEmpty) {
                return _buildScrollableEmpty();
              }

              return ListView.builder(
                padding: const EdgeInsets.only(
                  top: 4,
                  left: 16,
                  right: 16,
                  bottom: 8,
                ),
                itemCount: allPosts.length,
                itemBuilder: (context, index) {
                  return PostCard(post: allPosts[index]);
                },
              );
            },
          ),
        ),
        _buildMyActivityButton(context),
      ],
    );
  }

  Widget _buildScrollableEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight < 200 ? 200.0 : constraints.maxHeight;
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: h,
            child: const EmptyWidget(message: '게시글이 없어요'),
          ),
        );
      },
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
