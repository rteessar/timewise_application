import 'dart:math' as math;
import 'dart:ui';

/// Whole days since 1970-01-01 for a calendar date (DST-safe).
int dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Local midnight of [dayNumber].
DateTime dateOfDay(int n) => DateTime(1970, 1, 1 + n);

double hourOfDay(DateTime t) => t.hour + t.minute / 60 + t.second / 3600;

/// The single coordinate system of the map: x is days (unbounded), y is the
/// hour of the day. Everything is derived from [leftDay], [topHour] and
/// [zoom], so panning and zooming are plain arithmetic.
class MapViewport {
  const MapViewport({
    required this.leftDay,
    required this.topHour,
    required this.zoom,
    required this.size,
  });

  static const double baseColumnWidth = 110; // px per day at zoom 1
  static const double baseHourHeight = 56; // px per hour at zoom 1
  static const double gutterWidth = 40;
  static const double headerHeight = 54;
  static const double minZoom = 0.2;
  static const double maxZoom = 4;

  /// Fractional day number at the left edge of the day area.
  final double leftDay;

  /// Hour of day (0..24) at the top of the day area.
  final double topHour;
  final double zoom;
  final Size size;

  double get columnWidth => baseColumnWidth * zoom;
  double get hourHeight => baseHourHeight * zoom;

  double xOfDay(num day) => gutterWidth + (day - leftDay) * columnWidth;
  double yOfHour(double h) => headerHeight + (h - topHour) * hourHeight;
  double dayAtX(double x) => leftDay + (x - gutterWidth) / columnWidth;
  double hourAtY(double y) => topHour + (y - headerHeight) / hourHeight;

  int get firstDay => leftDay.floor();
  int get lastDay => dayAtX(size.width).ceil();
  double get visibleHours => (size.height - headerHeight) / hourHeight;

  MapViewport copyWith({double? leftDay, double? topHour, double? zoom}) =>
      MapViewport(
        leftDay: leftDay ?? this.leftDay,
        topHour: topHour ?? this.topHour,
        zoom: zoom ?? this.zoom,
        size: size,
      ).clamped();

  /// Keeps the vertical position inside the 24 h day (horizontal is free).
  MapViewport clamped() {
    final z = zoom.clamp(minZoom, maxZoom).toDouble();
    final vis = (size.height - headerHeight) / (baseHourHeight * z);
    final maxTop = math.max(-0.25, 24.25 - vis);
    return MapViewport(
      leftDay: leftDay,
      topHour: topHour.clamp(-0.25, maxTop).toDouble(),
      zoom: z,
      size: size,
    );
  }

  /// Zoom by [factor] keeping the map point under [focal] where it is.
  MapViewport zoomAt(Offset focal, double factor) {
    final day = dayAtX(focal.dx);
    final hour = hourAtY(focal.dy);
    final z = (zoom * factor).clamp(minZoom, maxZoom).toDouble();
    return MapViewport(
      leftDay: day - (focal.dx - gutterWidth) / (baseColumnWidth * z),
      topHour: hour - (focal.dy - headerHeight) / (baseHourHeight * z),
      zoom: z,
      size: size,
    ).clamped();
  }

  /// Move the map by a finger/cursor delta in pixels.
  MapViewport panBy(Offset delta) => copyWith(
    leftDay: leftDay - delta.dx / columnWidth,
    topHour: topHour - delta.dy / hourHeight,
  );
}
