/// Application-wide constants for TimeWise
abstract final class AppConstants {
  // App Info
  static const String appName = 'TimeWise';
  static const String appVersion = '1.0.0';

  // Database
  static const String isarDbName = 'timewise_db';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Timeline Calendar
  static const double minZoomLevel = 0.5;
  static const double maxZoomLevel = 4.0;
  static const double defaultZoomLevel = 1.0;

  // Layout
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 12.0;
}
