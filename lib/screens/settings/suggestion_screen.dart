import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:daengnyang/core/colors.dart';

const String kConfirmedReply = '관리자가 문의사항을 확인했어요';

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  String? _userId;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _userId = uid;
        _nickname = doc.data()?['nickname'] ?? '';
      });
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final urls = <String>[];
    for (final image in images) {
      final ref = FirebaseStorage.instance.ref().child(
        'suggestions/${DateTime.now().millisecondsSinceEpoch}_${image.name}',
      );
      await ref.putFile(File(image.path));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  void _showSubmitSheet({
    String? docId,
    String? initialTitle,
    String? initialContent,
  }) {
    final titleController = TextEditingController(text: initialTitle ?? '');
    final contentController = TextEditingController(text: initialContent ?? '');
    List<XFile> selectedImages = [];
    bool isLoading = false;
    final isEdit = docId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                Text(
                  isEdit ? '문의 수정' : '문의하기',
                  style: const TextStyle(
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
                TextField(
                  controller: contentController,
                  maxLines: 5,
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
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: selectedImages.length >= 3
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final images = await picker.pickMultiImage(
                              imageQuality: 80,
                            );
                            if (images.isNotEmpty) {
                              setModalState(() {
                                final remaining = 3 - selectedImages.length;
                                selectedImages.addAll(images.take(remaining));
                              });
                            }
                          },
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: AppColors.textMid,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '사진 추가 (${selectedImages.length}/3)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(selectedImages[index].path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setModalState(
                                  () => selectedImages.removeAt(index),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty ||
                                contentController.text.trim().isEmpty) {
                              return;
                            }
                            setModalState(() => isLoading = true);
                            if (isEdit) {
                              await FirebaseFirestore.instance
                                  .collection('suggestions')
                                  .doc(docId)
                                  .update({
                                    'title': titleController.text.trim(),
                                    'content': contentController.text.trim(),
                                  });
                            } else {
                              final imageUrls = await _uploadImages(
                                selectedImages,
                              );
                              await FirebaseFirestore.instance
                                  .collection('suggestions')
                                  .add({
                                    'userId': _userId,
                                    'nickname': _nickname,
                                    'title': titleController.text.trim(),
                                    'content': contentController.text.trim(),
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'reply': null,
                                    'repliedAt': null,
                                    'images': imageUrls,
                                  });
                            }
                            if (context.mounted) Navigator.pop(context);
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
                            isEdit ? '수정하기' : '제출하기',
                            style: const TextStyle(fontSize: 16),
                          ),
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

  Future<void> _deleteInquiry(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문의 삭제'),
        content: const Text('이 문의를 삭제할까요?'),
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
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('suggestions')
          .doc(docId)
          .delete();
    }
  }

  void _showDetail(Map<String, dynamic> data) {
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['title'] ?? '',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(data['createdAt']),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['content'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMid,
                  height: 1.6,
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              if (data['reply'] != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['reply'] == kConfirmedReply ? '확인' : '답변',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['reply'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(data['repliedAt']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Widget _buildBadge(String? reply) {
    if (reply == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Text(
          '답변 대기',
          style: TextStyle(fontSize: 11, color: AppColors.textLight),
        ),
      );
    }
    if (reply == kConfirmedReply) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(
          '확인됨',
          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary),
      ),
      child: const Text(
        '답변 완료',
        style: TextStyle(fontSize: 11, color: AppColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('문의 내역')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text('문의하기', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('suggestions')
            .where('userId', isEqualTo: _userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '문의 내역이 없어요',
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 80,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              final hasReply = data['reply'] != null;
              return GestureDetector(
                onTap: () => _showDetail(data),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                              _formatDate(data['createdAt']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildBadge(data['reply']),
                      if (!hasReply) ...[
                        const SizedBox(width: 2),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showSubmitSheet(
                            docId: docId,
                            initialTitle: data['title'],
                            initialContent: data['content'],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _deleteInquiry(docId),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
