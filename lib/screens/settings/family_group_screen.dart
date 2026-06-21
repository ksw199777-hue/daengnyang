import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/models/family_group_model.dart';
import 'package:daengnyang/services/family_group_service.dart';

class FamilyGroupScreen extends StatefulWidget {
  const FamilyGroupScreen({super.key});

  @override
  State<FamilyGroupScreen> createState() => _FamilyGroupScreenState();
}

class _FamilyGroupScreenState extends State<FamilyGroupScreen> {
  final _service = FamilyGroupService();
  FamilyGroupModel? _group;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    final group = await _service.getMyGroup();
    List<Map<String, dynamic>> members = [];
    if (group != null) {
      members = await _service.getMembers(group.memberIds);
    }
    if (mounted) {
      setState(() {
        _group = group;
        _members = members;
        _isLoading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    setState(() => _isLoading = true);
    try {
      await _service.createGroup();
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 생성에 실패했어요. 다시 시도해주세요')),
        );
      }
    }
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '초대 코드 입력',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '가족에게 받은 6자리 코드를 입력해주세요',
                    style: TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'XXXXXX',
                      hintStyle: const TextStyle(
                        color: AppColors.textLight,
                        letterSpacing: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final code = controller.text.trim();
                              if (code.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('6자리 코드를 입력해주세요'),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isLoading = true);
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final group = await _service.joinGroup(code);
                                navigator.pop();
                                if (group == null) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('코드가 올바르지 않아요'),
                                    ),
                                  );
                                } else {
                                  _loadGroup();
                                }
                              } catch (e) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('이미 가족 그룹에 가입되어 있어요'),
                                  ),
                                );
                              }
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
                          : const Text('가입하기', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmKick(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('멤버 내보내기'),
        content: Text('${member['nickname'] ?? '멤버'}님을 그룹에서 내보낼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('내보내기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    await _service.kickMember(_group!.id, member['id'] as String);
    await _loadGroup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멤버를 내보냈어요')),
      );
    }
  }

  Future<void> _confirmLeave() async {
    final isOwner = _group?.ownerId == _currentUserId;
    final hasOthers = (_group?.memberIds.length ?? 0) > 1;

    String message = '그룹을 나가면 가족 공유가 해제돼요.';
    if (isOwner && hasOthers) {
      message = '그룹장이 나가면 다음 멤버에게 그룹장이 위임돼요. 계속할까요?';
    } else if (!hasOthers) {
      message = '혼자 남은 상태에서 나가면 그룹이 삭제돼요. 계속할까요?';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹 나가기'),
        content: Text(message),
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

    setState(() => _isLoading = true);
    await _service.leaveGroup(_group!.id);
    await _loadGroup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹을 나갔어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('가족 공유')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _group == null
          ? _buildNoGroupView()
          : _buildGroupView(),
    );
  }

  Widget _buildNoGroupView() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 32,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 프리미엄 전용 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: Color(0xFF8B6914), size: 16),
                SizedBox(width: 4),
                Text(
                  '프리미엄 전용',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B6914),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '가족과 함께 반려동물을 관리해요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '가족 그룹을 만들면 같은 그룹원의\n반려동물 일정과 건강 기록을 함께 볼 수 있어요',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMid,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _createGroup,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '가족 공유 시작하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _showJoinDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '코드로 가입하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupView() {
    final isOwner = _group!.ownerId == _currentUserId;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 초대 코드 카드
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '초대 코드',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _group!.inviteCode,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 6,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: _group!.inviteCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('초대 코드가 복사됐어요'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.copy_outlined,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '복사',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '가족에게 이 코드를 공유하면 같은 그룹에 초대할 수 있어요',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ),

          // 멤버 목록
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              '멤버 ${_members.length}명',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMid,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Column(
              children: _members.asMap().entries.map((entry) {
                final index = entry.key;
                final member = entry.value;
                final memberId = member['id'] as String;
                final isMe = memberId == _currentUserId;
                final isMemberOwner = memberId == _group!.ownerId;

                return Column(
                  children: [
                    if (index > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.accent,
                        backgroundImage: member['profileImage'] != null
                            ? NetworkImage(member['profileImage'] as String)
                            : null,
                        child: member['profileImage'] == null
                            ? Text(
                                (member['nickname'] as String? ?? '?')
                                    .isNotEmpty
                                    ? (member['nickname'] as String)
                                          .substring(0, 1)
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(
                            member['nickname'] as String? ?? '알 수 없음',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '나',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (isMemberOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '그룹장',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8B6914),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: (isOwner && !isMe)
                          ? GestureDetector(
                              onTap: () => _confirmKick(member),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '내보내기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          // 코드로 가입하기 버튼 (이미 그룹원이지만 다른 그룹 코드를 입력하는 시나리오는 차단됨)
          const SizedBox(height: 32),

          // 그룹 나가기
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _confirmLeave,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '그룹 나가기',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
