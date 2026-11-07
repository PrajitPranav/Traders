import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'saravanas_logo.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final IconData? buttonIcon;
  final VoidCallback? onButtonPressed;
  final bool showLogo;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.buttonIcon,
    this.onButtonPressed,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLogo) ...[
              SaravanasLogo(
                size: 64,
                primaryColor: AppColors.primaryNavy.withValues(alpha: 0.85),
                accentColor: AppColors.accentTeal,
              ),
              const SizedBox(height: 24),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: Icon(buttonIcon ?? Icons.add, size: 18),
                label: Text(buttonText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

