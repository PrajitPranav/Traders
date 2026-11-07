import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/saravanas_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _dbReady = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _initializeDatabaseAndNavigate();
  }

  Future<void> _initializeDatabaseAndNavigate() async {
    final startTime = DateTime.now();

    // Ensure database is initialized before proceeding
    try {
      final dbHelper = ref.read(databaseHelperProvider);
      await dbHelper.database;
      _dbReady = true;
    } catch (e) {
      debugPrint('Database initialization notice: $e');
    }

    // Ensure splash animation feels smooth and intentional (at least 1500ms)
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 1500) {
      await Future.delayed(Duration(milliseconds: 1500 - elapsed));
    }

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: const SaravanasLogo(
                  size: 96,
                  showWordmark: false,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: child,
                    ),
                  );
                },
                child: const Column(
                  children: [
                    Text(
                      'SARAVANAS',
                      style: TextStyle(
                        color: AppColors.primaryNavy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'People. Work. Management.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              if (!_dbReady)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

