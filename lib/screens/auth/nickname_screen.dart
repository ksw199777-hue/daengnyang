import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:daengnyang/core/bad_words.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/screens/pet/pet_register_screen.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      setState(() => _errorMessage = '닉네임을 입력해주세요');
      return;
    }
    if (nickname.length < 2) {
      setState(() => _errorMessage = '닉네임은 2자 이상이어야 해요');
      return;
    }
    if (nickname.length > 12) {
      setState(() => _errorMessage = '닉네임은 12자 이하여야 해요');
      return;
    }
    if (BadWords.contains(nickname)) {
      setState(() => _errorMessage = '사용할 수 없는 닉네임이에요');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 닉네임 중복 체크
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          _errorMessage = '이미 사용 중인 닉네임이에요';
          _isLoading = false;
        });
        return;
      }

      // 닉네임 저장
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .set({'nickname': nickname}, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = '오류가 발생했어요. 다시 시도해주세요');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                '닉네임을 정해볼까요?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '커뮤니티에서 사용할 닉네임이에요',
                style: TextStyle(fontSize: 15, color: AppColors.textMid),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nicknameController,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: '닉네임 (2~12자)',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveNickname,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('다음', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
