import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../services/validation_cross_reference_service.dart';

class QualityScoresWidget extends StatefulWidget {
  final ValidationCrossReferenceService validationService;

  const QualityScoresWidget({
    Key? key,
    required this.validationService,
  }) : super(key: key);

  @override
  State<QualityScoresWidget> createState() => _QualityScoresWidgetState();
}

class _QualityScoresWidgetState extends State<QualityScoresWidget> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _qualityData = [];

  @override
  void initState() {
    super.initState();
    _loadQualityData();
  }

  Future<void> _loadQualityData() async {
    try {
      setState(() => _isLoading = true);

      // Simulate loading quality score data
      // In production, this would call actual service methods
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _qualityData = _generateMockQualityData();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _generateMockQualityData() {
    return [
      {
        'grade': 'A+',
        'count': 45,
        'percentage': 0.45,
        'color': Colors.green[600],
      },
      {
        'grade': 'A',
        'count': 30,
        'percentage': 0.30,
        'color': Colors.green[400],
      },
      {
        'grade': 'B+',
        'count': 15,
        'percentage': 0.15,
        'color': Colors.yellow[600],
      },
      {
        'grade': 'B',
        'count': 7,
        'percentage': 0.07,
        'color': Colors.orange[400],
      },
      {
        'grade': 'C+',
        'count': 2,
        'percentage': 0.02,
        'color': Colors.red[400],
      },
      {
        'grade': 'Needs Review',
        'count': 1,
        'percentage': 0.01,
        'color': Colors.red[600],
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple.shade300),
            SizedBox(height: 2.h),
            Text(
              'Loading quality scores...',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60.sp, color: Colors.red[300]),
            SizedBox(height: 2.h),
            Text(
              'Failed to load quality scores',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            ElevatedButton(
              onPressed: _loadQualityData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQualityData,
      color: Colors.purple.shade300,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Content Quality Analytics',
                  style: GoogleFonts.inter(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.purple[800],
                  ),
                ),
                IconButton(
                  onPressed: _loadQualityData,
                  icon: Icon(Icons.refresh, color: Colors.purple[700]),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // Overall quality metrics
            _buildOverallMetrics(),

            SizedBox(height: 4.h),

            // Quality distribution chart
            _buildQualityDistributionChart(),

            SizedBox(height: 4.h),

            // Quality breakdown list
            _buildQualityBreakdownList(),

            SizedBox(height: 4.h),

            // Quality improvement recommendations
            _buildQualityRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallMetrics() {
    final totalReadings =
        _qualityData.fold<int>(0, (sum, item) => sum + (item['count'] as int));
    final highQualityCount = _qualityData
        .where((item) => ['A+', 'A'].contains(item['grade']))
        .fold<int>(0, (sum, item) => sum + (item['count'] as int));
    final lowQualityCount = _qualityData
        .where((item) => ['C+', 'Needs Review'].contains(item['grade']))
        .fold<int>(0, (sum, item) => sum + (item['count'] as int));

    final highQualityRate =
        totalReadings > 0 ? (highQualityCount / totalReadings) : 0.0;
    final averageScore = 0.87; // Mock average score

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Quality Metrics',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Average Score',
                '${(averageScore * 100).toStringAsFixed(1)}%',
                Icons.analytics,
                Colors.purple,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildMetricCard(
                'High Quality',
                '${(highQualityRate * 100).toStringAsFixed(1)}%',
                Icons.star,
                Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Readings',
                totalReadings.toString(),
                Icons.book,
                Colors.blue,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildMetricCard(
                'Need Attention',
                lowQualityCount.toString(),
                Icons.warning,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24.sp),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Live',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityDistributionChart() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quality Distribution',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 3.h),

          SizedBox(
            height: 30.h,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 8.w,
                sections: _qualityData.map((data) {
                  return PieChartSectionData(
                    value: (data['percentage'] as double) * 100,
                    color: data['color'] as Color,
                    title: '${data['count']}',
                    titleStyle: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    radius: 12.w,
                  );
                }).toList(),
              ),
            ),
          ),

          SizedBox(height: 3.h),

          // Legend
          Wrap(
            spacing: 4.w,
            runSpacing: 1.h,
            children: _qualityData.map((data) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4.w,
                    height: 4.w,
                    decoration: BoxDecoration(
                      color: data['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    data['grade'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBreakdownList() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Quality Breakdown',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 3.h),
          ..._qualityData.map((data) {
            final percentage = (data['percentage'] as double) * 100;
            return Column(
              children: [
                _buildQualityRow(
                  data['grade'] as String,
                  data['count'] as int,
                  percentage,
                  data['color'] as Color,
                ),
                if (data != _qualityData.last) SizedBox(height: 2.h),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQualityRow(
      String grade, int count, double percentage, Color color) {
    return Row(
      children: [
        // Grade badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            grade,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),

        SizedBox(width: 4.w),

        // Progress bar and details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count readings',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 0.8.h,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityRecommendations() {
    final recommendations = [
      {
        'title': 'Cross-Reference Validation',
        'description':
            'Run batch validation on recent readings to identify potential issues',
        'icon': Icons.batch_prediction,
        'color': Colors.blue[700],
        'action': 'Run Validation',
      },
      {
        'title': 'Source Diversification',
        'description':
            'Add more Catholic sources for better cross-referencing accuracy',
        'icon': Icons.source,
        'color': Colors.green[700],
        'action': 'Configure Sources',
      },
      {
        'title': 'Quality Rules Update',
        'description':
            'Review and update data quality rules to catch more issues',
        'icon': Icons.rule,
        'color': Colors.purple[700],
        'action': 'Update Rules',
      },
      {
        'title': 'User Feedback Integration',
        'description':
            'Encourage users to report quality issues for continuous improvement',
        'icon': Icons.feedback,
        'color': Colors.orange[700],
        'action': 'View Reports',
      },
    ];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quality Improvement Recommendations',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 3.h),
          ...recommendations.map((rec) {
            return Column(
              children: [
                _buildRecommendationItem(rec),
                if (rec != recommendations.last) SizedBox(height: 3.h),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: (recommendation['color'] as Color).withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: (recommendation['color'] as Color).withAlpha(51)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: (recommendation['color'] as Color).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              recommendation['icon'] as IconData,
              color: recommendation['color'] as Color,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  recommendation['description'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          TextButton(
            onPressed: () {
              // Handle recommendation action
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${recommendation['action']} feature would be implemented here'),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: recommendation['color'] as Color,
            ),
            child: Text(
              recommendation['action'] as String,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
