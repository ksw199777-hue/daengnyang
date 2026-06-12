import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/screens/chat/chat_list_screen.dart';
import 'package:daengnyang/screens/community/board_screen.dart';
import 'package:daengnyang/screens/community/trade_screen.dart';
import 'package:daengnyang/screens/community/write_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentCategory = 'community';
  String _currentTag = '전체';

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
      resizeToAvoidBottomInset: false,
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
          PostList(
            category: 'community',
            selectedTag: _currentTag,
            onTagChanged: (tag) => setState(() => _currentTag = tag),
          ),
          const TradeList(),
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
