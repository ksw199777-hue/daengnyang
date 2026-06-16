import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/core/bad_words.dart';
import 'package:daengnyang/screens/chat/chat_screen.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String get _shareUrl {
    final category = _post?['category'];
    final path = category == 'trade' ? 'trade' : 'post';
    return 'https://daengnyang-c80e5.web.app/$path/${widget.postId}';
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE500),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'K',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C1E1E),
                    ),
                  ),
                ),
              ),
              title: const Text('카카오톡으로 공유'),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareKakao();
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(Icons.link_rounded, size: 22),
              ),
              title: const Text('링크 복사'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyLink();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareKakao() async {
    if (_post == null) return;

    final category = _post?['category'];
    final path = category == 'trade' ? 'trade' : 'post';
    final deepLinkUri = Uri.parse(
      'https://daengnyang-c80e5.web.app/$path/${widget.postId}',
    );
    final title = (_post?['title'] as String? ?? '').isNotEmpty
        ? _post!['title'] as String
        : '이제댕냥';
    final body = _post?['content'] as String? ?? '';
    final description = body.length > 60 ? '${body.substring(0, 60)}...' : body;

    final images = (_post?['images'] as List?)?.cast<String>() ?? [];
    final imageUri = Uri.parse(
      images.isNotEmpty
          ? images.first
          : 'https://daengnyang-c80e5.web.app/icon.png',
    );

    final execParams = {'postId': widget.postId, 'type': path};

    final template = FeedTemplate(
      content: Content(
        title: title,
        description: description.isNotEmpty ? description : null,
        imageUrl: imageUri,
        link: Link(
          webUrl: deepLinkUri,
          mobileWebUrl: deepLinkUri,
          androidExecutionParams: execParams,
        ),
      ),
      buttons: [
        Button(
          title: '앱에서 보기',
          link: Link(
            webUrl: deepLinkUri,
            mobileWebUrl: deepLinkUri,
            androidExecutionParams: execParams,
          ),
        ),
      ],
    );

    try {
      final talkAvailable =
          await ShareClient.instance.isKakaoTalkSharingAvailable();
      if (talkAvailable) {
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      } else {
        final uri =
            await WebSharerClient.instance.makeDefaultUrl(template: template);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유에 실패했어요')),
      );
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크가 복사됐어요')),
    );
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
    final comments = await FirebaseFirestore.instance
        .collection('comments')
        .where('postId', isEqualTo: widget.postId)
        .get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }

    final likes = await FirebaseFirestore.instance
        .collection('likes')
        .where('postId', isEqualTo: widget.postId)
        .get();
    for (final doc in likes.docs) {
      await doc.reference.delete();
    }

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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _showShareSheet,
                ),
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
                        style: const TextStyle(
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
              if (_post?['category'] == 'trade' &&
                  _post?['region'] != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 2),
                Text(
                  _post!['region'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
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
