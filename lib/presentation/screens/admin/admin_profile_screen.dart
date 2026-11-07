import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/saravanas_logo.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Administrator Name'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Administrator Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                await ref
                    .read(adminActionNotifierProvider.notifier)
                    .updateAdminName(controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminNameAsync = ref.watch(adminNameProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.adminProfile, style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Admin Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryNavy,
                        child: Icon(Icons.person, size: 48, color: Colors.white),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.accentTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  adminNameAsync.when(
                    data: (name) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                          onPressed: () => _showEditNameDialog(context, ref, name),
                          tooltip: 'Edit Name',
                        ),
                      ],
                    ),
                    loading: () => const Text('Loading...'),
                    error: (e, s) => const Text('Administrator'),
                  ),
                  const Text(
                    'Company Owner • Saravanas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings & Actions
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined, color: AppColors.accentTeal),
                    title: const Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Export JSON snapshot or restore database', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => context.push(AppRoutes.backupRestore),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined, color: AppColors.primaryNavy),
                    title: const Text('Database Engine', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('SQLite (Persistent Local Storage)', style: TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.successGreen),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_outlined, color: AppColors.infoBlue),
                    title: const Text('Architecture Readiness', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Repository Pattern (MySQL / API Ready)', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.check, color: AppColors.infoBlue, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About Saravanas Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Column(
                children: [
                  SaravanasLogo(size: 48, showWordmark: true, showTagline: true),
                  SizedBox(height: 16),
                  Text(
                    'Saravanas Employee Management application designed for reliable offline corporate operations, attendance tracking, and integer-precision salary advance ledgers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Version 1.0.0 (Build 1)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
