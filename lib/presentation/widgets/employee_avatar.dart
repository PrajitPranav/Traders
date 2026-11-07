import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EmployeeAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const EmployeeAvatar({
    super.key,
    required this.initials,
    this.radius = 22,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primaryLight.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          color: textColor ?? AppColors.primaryNavy,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}

