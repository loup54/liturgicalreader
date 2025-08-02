import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/sync_manager_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/offline_first_liturgical_service.dart';

class OfflineSyncStatusWidget extends StatefulWidget {
  const OfflineSyncStatusWidget({super.key});

  @override
  State<OfflineSyncStatusWidget> createState() =>
      _OfflineSyncStatusWidgetState();
}

class _OfflineSyncStatusWidgetState extends State<OfflineSyncStatusWidget> {
  final OfflineFirstLiturgicalService _service =
      OfflineFirstLiturgicalService();
  final SyncManagerService _syncManager = SyncManagerService();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: _syncManager.statusStream,
      initialData: _syncManager.syncStatus,
      builder: (context, syncSnapshot) {
        return StreamBuilder<ConnectivityStatus>(
          stream: _connectivity.statusStream,
          initialData: _connectivity.currentStatus,
          builder: (context, connectivitySnapshot) {
            return StreamBuilder<String>(
              stream: _syncManager.messageStream,
              builder: (context, messageSnapshot) {
                return _buildStatusWidget(
                  syncSnapshot.data ?? SyncStatus.idle,
                  connectivitySnapshot.data ?? ConnectivityStatus.unknown,
                  messageSnapshot.data,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatusWidget(
    SyncStatus syncStatus,
    ConnectivityStatus connectivityStatus,
    String? message,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: _getStatusColor(syncStatus, connectivityStatus).withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(syncStatus, connectivityStatus).withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(syncStatus, connectivityStatus),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(syncStatus, connectivityStatus),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(syncStatus, connectivityStatus),
                  ),
                ),
                if (message != null) ...[
                  SizedBox(height: 0.5.h),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (syncStatus == SyncStatus.syncing) ...[
                  SizedBox(height: 1.h),
                  _buildProgressBar(),
                ],
              ],
            ),
          ),
          if (_connectivity.isOnline && syncStatus != SyncStatus.syncing) ...[
            _buildSyncButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(
      SyncStatus syncStatus, ConnectivityStatus connectivityStatus) {
    IconData iconData;

    switch (syncStatus) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getStatusColor(syncStatus, connectivityStatus),
            ),
          ),
        );
      case SyncStatus.success:
        iconData = Icons.cloud_done;
        break;
      case SyncStatus.error:
        iconData = Icons.cloud_off;
        break;
      case SyncStatus.paused:
        iconData = Icons.pause_circle;
        break;
      default:
        iconData = connectivityStatus == ConnectivityStatus.online
            ? Icons.cloud_queue
            : Icons.offline_bolt;
    }

    return Icon(
      iconData,
      size: 20,
      color: _getStatusColor(syncStatus, connectivityStatus),
    );
  }

  Widget _buildProgressBar() {
    final progress = _syncManager.syncProgress;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            _getStatusColor(SyncStatus.syncing, _connectivity.currentStatus),
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% complete',
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: () async {
        await _syncManager.triggerManualSync();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).primaryColor.withAlpha(77),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(width: 1.w),
            Text(
              'Sync',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(
      SyncStatus syncStatus, ConnectivityStatus connectivityStatus) {
    switch (syncStatus) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.paused:
        return Colors.orange;
      default:
        return connectivityStatus == ConnectivityStatus.online
            ? Colors.green
            : Colors.grey;
    }
  }

  String _getStatusTitle(
      SyncStatus syncStatus, ConnectivityStatus connectivityStatus) {
    switch (syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing Data';
      case SyncStatus.success:
        return 'Data Up to Date';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.paused:
        return 'Sync Paused';
      default:
        return connectivityStatus == ConnectivityStatus.online
            ? 'Online - Ready to Sync'
            : 'Offline - Using Cache';
    }
  }
}
