import 'package:flutter/material.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/services/auth_service.dart';
import 'package:daengnyang/screens/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);
    if (user != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _signInWithKakao() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithKakao();
    setState(() => _isLoading = false);
    if (user != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // 캐릭터 이미지
              Image.asset(
                'assets/images/main.png',
                height: 200,
              ),
              const SizedBox(height: 24),

              // 앱 이름
              Text(
                '이제댕냥',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '내새꾸 걱정, 이제댕냥!',
                style: TextStyle(fontSize: 16, color: AppColors.textMid),
              ),

              const Spacer(),

              if (_isLoading)
                CircularProgressIndicator(color: AppColors.primary)
              else
                Column(
                  children: [
                    // 구글 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 20,
                          height: 20,
                        ),
                        label: const Text('Google로 시작하기'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          foregroundColor: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 카카오 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _signInWithKakao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE500),
                          foregroundColor: const Color(0xFF191919),
                        ),
                        child: const Text('카카오로 시작하기'),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}