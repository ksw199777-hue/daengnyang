import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:daengnyang/core/colors.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherNickname;
  final String postTitle;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherNickname,
    required this.postTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (!doc.exists) return;
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'unreadCount.$userId': 0});
    } catch (e) {
      print('읽음 처리 에러: $e');
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final content = imageUrl ?? _messageController.text.trim();
    if (content.isEmpty || userId == null) return;

    if (imageUrl == null) _messageController.clear();

    await FirebaseFirestore.instance.collection('messages').add({
      'chatId': widget.chatId,
      'senderId': userId,
      'content': content,
      'isImage': imageUrl != null,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
          'lastMessage': imageUrl != null ? '사진' : content,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
        });
  }

  Future<void> _sendImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isSending = true);

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'chats/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      await _sendMessage(imageUrl: url);
    } catch (e) {
      print('이미지 전송 에러: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _leaveChat() async {
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('채팅방을 나가면 대화 내용이 삭제돼요. 나가시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 채팅방에 나갔다는 메세지 남기기
    await FirebaseFirestore.instance.collection('messages').add({
      'chatId': widget.chatId,
      'senderId': userId,
      'content': '상대방이 채팅방을 나갔어요.',
      'isImage': false,
      'isSystem': true,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // participants 에서 제거
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
          'participants': FieldValue.arrayRemove([userId]),
          'lastMessage': '상대방이 채팅방을 나갔어요.',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherNickname,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (widget.postTitle.isNotEmpty)
              Text(
                widget.postTitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textMid),
              ),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'leave',
                child: Text('채팅방 나가기', style: TextStyle(color: Colors.red)),
              ),
            ],
            onSelected: (value) {
              if (value == 'leave') _leaveChat();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, chatSnapshot) {
          final chatData = chatSnapshot.data?.data() as Map<String, dynamic>?;
          final participants = List<String>.from(
            chatData?['participants'] ?? [],
          );
          final hasLeft = !participants.contains(widget.otherUserId);

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messages')
                      .where('chatId', isEqualTo: widget.chatId)
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data?.docs ?? [];

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message =
                            messages[index].data() as Map<String, dynamic>;
                        final isMine = message['senderId'] == userId;
                        final isImage = message['isImage'] == true;
                        final isSystem = message['isSystem'] == true;
                        final createdAt = message['createdAt'] != null
                            ? (message['createdAt'] as Timestamp).toDate()
                            : DateTime.now();

                        // 시스템 메세지
                        if (isSystem) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message['content'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMid,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: isMine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMine) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (isImage)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => Scaffold(
                                              backgroundColor: Colors.black,
                                              appBar: AppBar(
                                                backgroundColor: Colors.black,
                                                iconTheme: const IconThemeData(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              body: Center(
                                                child: InteractiveViewer(
                                                  child: Image.network(
                                                    message['content'],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        clipBehavior: Clip.hardEdge,
                                        child: Image.network(
                                          message['content'],
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (context, child, progress) {
                                                if (progress == null)
                                                  return child;
                                                return Container(
                                                  width: 200,
                                                  height: 200,
                                                  color:
                                                      AppColors.cardBackground,
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.65,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMine
                                            ? AppColors.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(
                                            isMine ? 16 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMine ? 4 : 16,
                                          ),
                                        ),
                                        border: isMine
                                            ? null
                                            : Border.all(
                                                color: AppColors.cardBorder,
                                                width: 0.5,
                                              ),
                                      ),
                                      child: Text(
                                        message['content'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isMine
                                              ? Colors.white
                                              : AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textLight,
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
                ),
              ),

              // 메세지 입력 or 나갔을때
              if (hasLeft)
                Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    top: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.cardBorder, width: 0.5),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '상대방이 채팅방을 나갔어요.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMid),
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.only(
                    left: 8,
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
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isSending ? null : _sendImage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.image_outlined,
                                color: AppColors.textMid,
                              ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: '메세지를 입력해주세요',
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
                        onTap: _isSending ? null : () => _sendMessage(),
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
                ),
            ],
          );
        },
      ),
    );
  }
}
