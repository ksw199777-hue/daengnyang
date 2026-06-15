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
    final bool overlap = imagePath.contains('sleepy');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (overlap)
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMid),
                    textAlign: TextAlign.center,
                  ),
                ),
                Image.asset(imagePath, height: 120),
              ],
            )
          else ...[
            Image.asset(imagePath, height: 120),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.textMid),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}