/// Application-wide constants for TimeWise.
abstract final class AppConstants {
  static const String appName = 'TimeWise';
  static const String storageKey = 'timewise.planner.v1';
  static const String habitKey = 'timewise.habit.v1';
  static const String themeKey = 'timewise.themeMode';

  static const Duration shortAnimation = Duration(milliseconds: 200);

  // Timeline map zoom, expressed as logical pixels per day.
  static const double minPixelsPerDay = 2; // ~ years at a glance
  static const double maxPixelsPerDay = 2400; // ~ hours at a glance
  static const double defaultPixelsPerDay = 48;

  static const double defaultPadding = 16;
  static const double defaultBorderRadius = 12;
}
