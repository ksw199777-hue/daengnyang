import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, bool> _settings = {
    'comment': true,
    'reply': true,
    'chat': true,
    'medication': true,
    'appointment': true,
    'birthday': true,
    'suggestionReply': true,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final saved =
        doc.data()?['notificationSettings'] as Map<String, dynamic>?;

    if (saved != null) {
      setState(() {
        _settings = {
          'comment': saved['comment'] != false,
          'reply': saved['reply'] != false,
          'chat': saved['chat'] != false,
          'medication': saved['medication'] != false,
          'appointment': saved['appointment'] != false,
          'birthday': saved['birthday'] != false,
          'suggestionReply': saved['suggestionReply'] != false,
        };
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggle(String key) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final newValue = !(_settings[key] ?? true);
    setState(() => _settings[key] = newValue);

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'notificationSettings.$key': newValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('알림 설정')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _section('커뮤니티', [
                  _tile('댓글 알림', '내 게시글에 댓글이 달리면 알려요', 'comment'),
                  _tile('답글 알림', '내 댓글에 답글이 달리면 알려요', 'reply'),
                ]),
                _section('채팅', [
                  _tile('채팅 알림', '새 메시지가 오면 알려요', 'chat'),
                ]),
                _section('건강 관리', [
                  _tile('투약 알림', '투약 시간을 알려요', 'medication'),
                  _tile('진료·접종 알림', '진료 및 접종 일정을 알려요', 'appointment'),
                  _tile('생일 알림', '반려동물 생일을 알려요', 'birthday'),
                ]),
                _section('기타', [
                  _tile('문의 답변 알림', '관리자가 문의에 답변하면 알려요', 'suggestionReply'),
                ]),
              ],
            ),
    );
  }

  Widget _section(String label, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMid,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _tile(String title, String subtitle, String key) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMid),
      ),
      value: _settings[key] ?? true,
      onChanged: (_) => _toggle(key),
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
