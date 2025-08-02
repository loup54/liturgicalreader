import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/offline_first_liturgical_service.dart';

class CacheInfoWidget extends StatefulWidget {
  const CacheInfoWidget({super.key});

  @override
  State<CacheInfoWidget> createState() => _CacheInfoWidgetState();
}

class _CacheInfoWidgetState extends State<CacheInfoWidget> {
  final OfflineFirstLiturgicalService _service =
      OfflineFirstLiturgicalService();
  Map<String, dynamic>? _cacheStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await _service.getCacheStats();
      if (mounted) {
        setState(() {
          _cacheStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(width: 2.w),
              Text(
                'Offline Cache Status',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadCacheStats,
                child: Icon(
                  Icons.refresh,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_cacheStats != null)
            _buildCacheDetails()
          else
            _buildErrorState(),
        ],
      ),
    );
  }

  Widget _buildCacheDetails() {
    final stats = _cacheStats!;
    final cachedDays = stats['cached_days'] ?? 0;
    final cachedReadings = stats['cached_readings'] ?? 0;
    final cacheSizeMB = stats['cache_size_mb'] ?? '0.00';
    final lastSyncTime = stats['last_sync_time'];

    // Calculate 90-day coverage
    final coveragePercentage = (cachedDays / 90 * 100).clamp(0, 100);

    return Column(
      children: [
        _buildStatRow('Cached Days', '$cachedDays / 90',
            _getCoverageColor(coveragePercentage)),
        SizedBox(height: 1.h),
        _buildStatRow('Total Readings', '$cachedReadings', null),
        SizedBox(height: 1.h),
        _buildStatRow('Cache Size', '${cacheSizeMB} MB', null),
        SizedBox(height: 2.h),
        _buildCoverageBar(coveragePercentage),
        if (lastSyncTime != null) ...[
          SizedBox(height: 2.h),
          _buildLastSyncInfo(lastSyncTime),
        ],
        SizedBox(height: 2.h),
        _buildOfflineCapabilityInfo(cachedDays),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageBar(double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '90-Day Coverage',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _getCoverageColor(percentage),
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Container(
                height: 8,
                width:
                    (percentage / 100) * (100.w - 16.w), // Account for padding
                decoration: BoxDecoration(
                  color: _getCoverageColor(percentage),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLastSyncInfo(String lastSyncTime) {
    try {
      final syncDate = DateTime.parse(lastSyncTime);
      final timeDiff = DateTime.now().difference(syncDate);
      final timeAgo = _formatTimeAgo(timeDiff);

      return Row(
        children: [
          Icon(
            Icons.update,
            size: 16,
            color: Colors.grey[600],
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              'Last sync: $timeAgo',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildOfflineCapabilityInfo(int cachedDays) {
    final isFullyReady =
        cachedDays >= 60; // At least 60 days for good offline experience

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isFullyReady ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFullyReady ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFullyReady ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: isFullyReady ? Colors.green[700] : Colors.orange[700],
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              isFullyReady
                  ? 'Ready for extended offline use'
                  : 'Building offline capability...',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: isFullyReady ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: Colors.grey[400],
          ),
          SizedBox(height: 1.h),
          Text(
            'Unable to load cache stats',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCoverageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'} ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'} ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
