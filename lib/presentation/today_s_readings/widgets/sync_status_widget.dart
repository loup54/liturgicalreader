import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/catholic_api_service.dart';
import '../../../services/liturgical_service.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSyncTime;
  final bool isSyncing;

  const SyncStatusWidget({
    super.key,
    required this.isOnline,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  String _formatLastSync() {
    if (lastSyncTime == null) return 'Never synced';

    final now = DateTime.now();
    final difference = now.difference(lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.successGreen.withValues(alpha: 0.1)
            : AppTheme.warningAmber.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: isOnline
                ? AppTheme.successGreen.withValues(alpha: 0.3)
                : AppTheme.warningAmber.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isSyncing) ...[
            SizedBox(
              width: 4.w,
              height: 4.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(width: 2.w),
            Text(
              'Syncing...',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ] else ...[
            CustomIconWidget(
              iconName: isOnline ? 'wifi' : 'wifi_off',
              color: isOnline ? AppTheme.successGreen : AppTheme.warningAmber,
              size: 16,
            ),
            SizedBox(width: 2.w),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isOnline
                        ? AppTheme.successGreen
                        : AppTheme.warningAmber,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
          const Spacer(),
          if (!isSyncing) ...[
            Text(
              'Last sync: ${_formatLastSync()}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  // Add real API connectivity status
  Widget _buildStatusContent() {
    return FutureBuilder<bool>(
      future: _checkApiConnectivity(),
      builder: (context, snapshot) {
        final hasApiConnectivity = snapshot.data ?? false;
        final supabaseAvailable = LiturgicalService().isAvailable;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // Add API connectivity check
  Future<bool> _checkApiConnectivity() async {
    try {
      return await CatholicApiService().hasConnectivity;
    } catch (e) {
      return false;
    }
  }
}
