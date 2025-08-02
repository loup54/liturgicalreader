import 'package:flutter/material.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/liturgical_calendar/liturgical_calendar.dart';
import '../presentation/reading_detail/reading_detail.dart';
import '../presentation/today_s_readings/today_s_readings.dart';
import '../presentation/admin_review/admin_review_screen.dart';

class AppRoutes {
  // TODO: Add your routes here
  static const String initial = '/';
  static const String initialRoute = '/'; // Added missing initialRoute
  static const String splashScreen = '/splash-screen';
  static const String todaySReadings = '/today-s-readings';
  static const String todayReadings =
      '/today-s-readings'; // Added missing todayReadings
  static const String liturgicalCalendar = '/liturgical-calendar';
  static const String readingDetail = '/reading-detail';
  static const String adminReview = '/admin-review';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    splashScreen: (context) => const SplashScreen(),
    liturgicalCalendar: (context) => const LiturgicalCalendar(),
    readingDetail: (context) => const ReadingDetail(),
    todaySReadings: (context) => const TodayReadingsScreen(),
    adminReview: (context) => const AdminReviewScreen(),
    // TODO: Add your other routes here
  };
}
