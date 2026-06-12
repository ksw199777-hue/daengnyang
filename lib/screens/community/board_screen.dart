import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/empty_widget.dart';
import 'package:daengnyang/screens/community/post_card.dart';
import 'package:daengnyang/screens/community/my_activity_screen.dart';

class PostList extends StatefulWidget {
  final String category;
  final String selectedTag;
  final ValueChanged<String> onTagChanged;

  const PostList({
    super.key,
    required this.category,
    required this.selectedTag,
    required this.onTagChanged,
  });

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(PostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTag != widget.selectedTag) {
      _updateStream();
    }
  }

  void _updateStream() {
    _stream = widget.selectedTag == '전체'
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
              .snapshots();
  }

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

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _stream,
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

              if (_isSearching) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allPosts.length,
                        itemBuilder: (context, index) =>
                            PostCard(post: allPosts[index]),
                      ),
                    ),
                    _buildMyActivityButton(context),
                  ],
                );
              }

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
                          if (index <= top3.length) {
                            return PostCard(
                              post: top3[index - 1],
                              isTop: true,
                            );
                          }
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
                          return PostCard(
                            post: allPosts[index - top3.length - 2],
                          );
                        }
                        return PostCard(post: allPosts[index]);
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
