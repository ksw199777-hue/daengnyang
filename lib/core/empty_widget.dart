import 'package:flutter/material.dart';
import 'package:daengnyang/core/colors.dart';

class EmptyWidget extends StatelessWidget {
  final String message;
  final String imagePath;

  const EmptyWidget({
    super.key,
    required this.message,
    this.imagePath = 'assets/images/what.png',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(imagePath, height: 120),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}