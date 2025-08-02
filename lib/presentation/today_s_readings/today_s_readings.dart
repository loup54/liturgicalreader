import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../models/liturgical_day.dart';
import '../../models/liturgical_reading.dart';
import '../../routes/app_routes.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_first_liturgical_service.dart';
import './widgets/cache_info_widget.dart';
import './widgets/liturgical_header_widget.dart';
import './widgets/navigation_controls_widget.dart';
import './widgets/offline_sync_status_widget.dart';
import './widgets/reading_card_widget.dart';

class TodayReadingsScreen extends StatefulWidget {
  const TodayReadingsScreen({super.key});

  @override
  State<TodayReadingsScreen> createState() => _TodayReadingsScreenState();
}

class _TodayReadingsScreenState extends State<TodayReadingsScreen> {
  final OfflineFirstLiturgicalService _offlineFirstService =
      OfflineFirstLiturgicalService();
  final ConnectivityService _connectivityService = ConnectivityService();

  DateTime _selectedDate = DateTime.now();
  List<LiturgicalReading> _readings = [];
  LiturgicalDay? _liturgicalDay;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showCacheInfo = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadTodaysReadings();
  }

  Future<void> _initializeServices() async {
    try {
      await _offlineFirstService.initialize();
      await _connectivityService.initialize();
    } catch (e) {
      debugPrint('TodayReadingsScreen: Failed to initialize services: $e');
    }
  }

  Future<void> _loadTodaysReadings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Use offline-first service instead of direct liturgical service
      final readings =
          await _offlineFirstService.getReadingsForDate(_selectedDate);
      final liturgicalDay =
          await _offlineFirstService.getLiturgicalDay(date: _selectedDate);

      if (mounted) {
        setState(() {
          _readings = readings;
          _liturgicalDay = liturgicalDay;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load readings: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadReadingsForDate(DateTime date) async {
    if (!mounted) return;

    setState(() {
      _selectedDate = date;
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Use offline-first service
      final readings = await _offlineFirstService.getReadingsForDate(date);
      final liturgicalDay =
          await _offlineFirstService.getLiturgicalDay(date: date);

      if (mounted) {
        setState(() {
          _readings = readings;
          _liturgicalDay = liturgicalDay;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to load readings for ${DateFormat('MMM dd, yyyy').format(date)}: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Today\'s Readings',
                style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            backgroundColor: Theme.of(context).primaryColor,
            elevation: 0,
            actions: [
              IconButton(
                  icon: Icon(_showCacheInfo ? Icons.info : Icons.info_outline,
                      color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showCacheInfo = !_showCacheInfo;
                    });
                  }),
            ]),
        body: Column(children: [
          const OfflineSyncStatusWidget(),
          if (_showCacheInfo) ...[
            const CacheInfoWidget(),
            SizedBox(height: 1.h),
          ],
          LiturgicalHeaderWidget(
              currentDate: DateFormat('MMM dd, yyyy').format(_selectedDate),
              liturgicalSeason: _liturgicalDay?.liturgicalSeason ?? '',
              seasonColor: Theme.of(context).primaryColor),
          NavigationControlsWidget(
              previousDate: DateFormat('MMM dd, yyyy')
                  .format(_selectedDate.subtract(const Duration(days: 1))),
              nextDate: DateFormat('MMM dd, yyyy')
                  .format(_selectedDate.add(const Duration(days: 1)))),
          Expanded(child: _buildMainContent()),
        ]));
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.grey[400]),
                    SizedBox(height: 2.h),
                    Text(_errorMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14.sp, color: Colors.grey[600])),
                    SizedBox(height: 2.h),
                    ElevatedButton(
                        onPressed: _loadTodaysReadings,
                        child: const Text('Retry')),
                  ])));
    }

    if (_readings.isEmpty) {
      return Center(
          child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined,
                        size: 48, color: Colors.grey[400]),
                    SizedBox(height: 2.h),
                    Text(
                        'No readings available for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14.sp, color: Colors.grey[600])),
                  ])));
    }

    return ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        itemCount: _readings.length,
        separatorBuilder: (context, index) => SizedBox(height: 2.h),
        itemBuilder: (context, index) {
          final reading = _readings[index];
          return ReadingCardWidget(
              title: reading.citation ?? '',
              citation: reading.citation ?? '',
              previewText: reading.content ?? '',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.readingDetail,
                    arguments: {
                      'reading': _readings[index],
                      'liturgicalDay': _liturgicalDay,
                      'allReadings': _readings,
                      'currentIndex': index,
                    });
              });
        });
  }

  @override
  void dispose() {
    // Services will be disposed by app lifecycle
    super.dispose();
  }
}
