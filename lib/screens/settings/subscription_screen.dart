import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentPlan = 'free';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (mounted) {
      setState(() {
        _currentPlan = doc.data()?['subscriptionType'] ?? 'free';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('구독 플랜'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                children: [
                  // 현재 플랜 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('현재 플랜',
                                style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                            Text(
                              _currentPlan == 'free' ? '무료 플랜' : '프리미엄 플랜',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 무료 플랜 카드
                  _buildPlanCard(
                    title: '무료 플랜',
                    price: '무료',
                    features: [
                      '반려동물 1마리',
                      '캘린더 일정 관리',
                      '건강 기록',
                      '커뮤니티 이용',
                      '장소 검색',
                      '쇼핑',
                    ],
                    isCurrentPlan: _currentPlan == 'free',
                    isPremium: false,
                  ),
                  const SizedBox(height: 16),

                  // 프리미엄 플랜 카드
                  _buildPlanCard(
                    title: '프리미엄 플랜',
                    price: '₩3,900/월',
                    features: [
                      '반려동물 무제한',
                      '무료 플랜 모든 기능',
                      'AI 건강 상담',
                      'AI 맞춤 상품 추천',
                      '월간 건강 리포트 PDF',
                    ],
                    isCurrentPlan: _currentPlan == 'premium',
                    isPremium: true,
                  ),
                  const SizedBox(height: 24),

                  // 안내 문구
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder, width: 0.5),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('결제 안내',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                        SizedBox(height: 8),
                        Text('• 구독은 매월 자동 갱신됩니다.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                        Text('• 언제든지 구독을 취소할 수 있어요.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                        Text('• 취소 시 현재 구독 기간이 끝날 때까지 이용 가능해요.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrentPlan,
    required bool isPremium,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan ? AppColors.primary : AppColors.cardBorder,
          width: isCurrentPlan ? 2 : 0.5,
        ),
        boxShadow: isPremium
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isPremium) ...[
                    const Icon(Icons.workspace_premium, color: Color(0xFF8B6914), size: 20),
                    const SizedBox(width: 6),
                  ],
                  Text(title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      )),
                ],
              ),
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('현재 플랜',
                      style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(price,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isPremium ? AppColors.primary : AppColors.textDark,
              )),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16,
                    color: isPremium ? AppColors.primary : AppColors.textMid),
                const SizedBox(width: 8),
                Text(feature,
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          if (!isCurrentPlan)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  if (isPremium) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('결제 시스템 준비 중이에요. 곧 만나요!')),
                    );
                  } else {
                    // 무료로 다운그레이드
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('무료 플랜으로 변경'),
                        content: const Text('무료 플랜으로 변경하면 반려동물이 1마리로 제한돼요. 변경할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final userId = FirebaseAuth.instance.currentUser?.uid;
                              if (userId != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .update({'subscriptionType': 'free'});
                              }
                              if (mounted) {
                                Navigator.pop(context);
                                _loadPlan();
                              }
                            },
                            child: const Text('변경', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPremium ? AppColors.primary : AppColors.cardBackground,
                  foregroundColor: isPremium ? Colors.white : AppColors.textMid,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isPremium ? '프리미엄 시작하기' : '무료 플랜으로 변경',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}