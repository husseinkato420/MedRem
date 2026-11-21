import 'package:flutter/material.dart';
import '../app_colors.dart';

class LogoBadge extends StatelessWidget {
  final double size;

  const LogoBadge({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Icon(Icons.medication, color: Colors.white, size: size * 0.55),
    );
  }
}
