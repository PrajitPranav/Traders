import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// A custom, premium geometric 'S' monogram and wordmark for Saravanas.
class SaravanasLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool showTagline;
  final Color? primaryColor;
  final Color? accentColor;
  final Color? textColor;

  const SaravanasLogo({
    super.key,
    this.size = 56,
    this.showWordmark = false,
    this.showTagline = false,
    this.primaryColor,
    this.accentColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final emblem = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryColor ?? AppColors.primaryNavy,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: (primaryColor ?? AppColors.primaryNavy).withValues(alpha: 0.18),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.6, size * 0.6),
          painter: _SaravanasMonogramPainter(
            accentColor: accentColor ?? AppColors.accentTeal,
            lightColor: Colors.white,
          ),
        ),
      ),
    );

    if (!showWordmark) {
      return emblem;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        SizedBox(height: size * 0.25),
        Text(
          AppStrings.companyName,
          style: TextStyle(
            color: textColor ?? AppColors.primaryNavy,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.08),
          Text(
            AppStrings.tagline,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: size * 0.20,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter that renders a geometric, modern S monogram
class _SaravanasMonogramPainter extends CustomPainter {
  final Color accentColor;
  final Color lightColor;

  _SaravanasMonogramPainter({
    required this.accentColor,
    required this.lightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.22;

    // Paint for top curve of S (white)
    final topPaint = Paint()
      ..color = lightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Paint for bottom accent curve of S (teal)
    final bottomPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathTop = Path();
    // Top hook of S
    pathTop.moveTo(size.width * 0.85, size.height * 0.22);
    pathTop.cubicTo(
      size.width * 0.85,
      size.height * 0.05,
      size.width * 0.18,
      size.height * 0.05,
      size.width * 0.18,
      size.height * 0.35,
    );
    pathTop.cubicTo(
      size.width * 0.18,
      size.height * 0.55,
      size.width * 0.82,
      size.height * 0.50,
      size.width * 0.82,
      size.height * 0.68,
    );
    canvas.drawPath(pathTop, topPaint);

    final pathBottom = Path();
    // Bottom hook of S
    pathBottom.moveTo(size.width * 0.82, size.height * 0.65);
    pathBottom.cubicTo(
      size.width * 0.82,
      size.height * 0.95,
      size.width * 0.15,
      size.height * 0.95,
      size.width * 0.15,
      size.height * 0.78,
    );
    canvas.drawPath(pathBottom, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _SaravanasMonogramPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor || oldDelegate.lightColor != lightColor;
  }
}

