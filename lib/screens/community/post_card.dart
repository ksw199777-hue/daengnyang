import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/screens/community/post_detail_screen.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isTop;

  const PostCard({super.key, required this.post, this.isTop = false});

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
