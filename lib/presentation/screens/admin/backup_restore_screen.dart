import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/confirm_dialog.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final _restoreTextController = TextEditingController();
  bool _isProcessing = false;
  String? _lastExportedJson;

  @override
  void dispose() {
    _restoreTextController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    setState(() => _isProcessing = true);
    try {
      final json = await ref.read(adminActionNotifierProvider.notifier).exportBackup();
      setState(() {
        _lastExportedJson = json;
      });

      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup JSON exported and copied to clipboard!'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRestore() async {
    final text = _restoreTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste the backup JSON content to restore.'),
          backgroundColor: AppColors.warningAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Restore Database Backup',
      message:
          'This will safely import and merge all employee, attendance, salary, and advance records from this backup file. Are you sure you want to proceed?',
      confirmLabel: 'Restore Records',
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final success = await ref.read(adminActionNotifierProvider.notifier).restoreBackup(text);
      if (success) {
        _restoreTextController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored and verified successfully!'),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid backup JSON format or corrupted data.'),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore error: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Export Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_download_outlined, color: AppColors.primaryNavy, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Export Backup Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Exports all company records (employees, attendance rolls, salary history, and advances) into a versioned JSON format with full UUID preservation.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleExport,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Generate & Copy Backup JSON'),
                  ),
                  if (_lastExportedJson != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Backup snapshot generated (${_lastExportedJson!.length} characters). Copied to clipboard.',
                        style: const TextStyle(fontSize: 12, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Restore Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings_backup_restore, color: AppColors.accentTeal, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Restore from Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste your previously exported JSON backup below to restore. Schema and UUID integrity will be validated prior to database insertion.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _restoreTextController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Paste backup JSON here...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_outlined, size: 20),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data != null && data.text != null) {
                            setState(() {
                              _restoreTextController.text = data.text!;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleRestore,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Validate & Restore Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                    ),
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

