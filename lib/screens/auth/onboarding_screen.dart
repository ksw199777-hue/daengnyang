import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daengnyang/core/colors.dart';
import 'package:daengnyang/screens/auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: 4,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) => Image.asset(
              'assets/images/onboarding_${index + 1}.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // 건너뛰기 버튼 (마지막 페이지 제외)
          if (_currentPage < 3)
            Positioned(
              top: topPad + 12,
              right: 16,
              child: TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: const Text('건너뛰기', style: TextStyle(fontSize: 13)),
              ),
            ),

          // 하단 버튼 (4페이지만 시작하기)
          if (_currentPage == 3)
            Positioned(
              left: 32,
              right: 32,
              bottom: bottomPad + 8,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
