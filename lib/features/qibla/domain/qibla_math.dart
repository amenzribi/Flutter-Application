import 'dart:math' as math;

/// Exact port of the legacy qibla maths (`KAABA`, `bearingTo`,
/// `distanceTo` in `Barakah40_Delivery/web/index.html`).
abstract final class QiblaMath {
  static const kaabaLat = 21.4225;
  static const kaabaLng = 39.8262;

  static double _rad(double x) => x * math.pi / 180;

  /// Initial great-circle bearing from (lat1, lng1) to (lat2, lng2), in
  /// degrees clockwise from true north, 0 ≤ result < 360.
  static double bearingTo(double lat1, double lng1, double lat2, double lng2) {
    final dL = _rad(lng2 - lng1);
    final y = math.sin(dL) * math.cos(_rad(lat2));
    final x =
        math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(dL);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Haversine distance in whole kilometres (R = 6371).
  static int distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371;
    final dLa = _rad(lat2 - lat1);
    final dLo = _rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLa / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLo / 2), 2);
    return (r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))).round();
  }

  static double qiblaBearing(double lat, double lng) =>
      bearingTo(lat, lng, kaabaLat, kaabaLng);

  static int distanceToMakkah(double lat, double lng) =>
      distanceKm(lat, lng, kaabaLat, kaabaLng);
}

/// One compass sample: heading in degrees from north, and the reported
/// accuracy when the platform gives one (legacy shows the "move in a figure
/// 8" hint when accuracy is unknown-bad, i.e. `acc < 0 || acc > 20`).
class CompassReading {
  const CompassReading({required this.heading, this.accuracy});

  final double heading;
  final double? accuracy;

  bool get needsCalibration =>
      accuracy != null && (accuracy! < 0 || accuracy! > 20);
}
