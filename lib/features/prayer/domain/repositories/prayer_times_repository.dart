import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// Result of a single Aladhan timings fetch (by coordinates or by city).
class PrayerTimesFetchResult {
  const PrayerTimesFetchResult({required this.times, this.timezone});

  /// Cleaned `HH:MM` strings for whichever of the five prayers the response
  /// included — never padded/invented for a missing one.
  final Map<PrayerName, String> times;

  /// IANA timezone from the Aladhan response's `data.meta.timezone`
  /// (present on GPS fetches; legacy only reads it on the coordinates path).
  final String? timezone;

  /// Legacy derives a display city from the GPS fetch's timezone
  /// (`timezone.split('/').pop().replace(/_/g,' ')`), e.g.
  /// `"Africa/Tripoli"` → `"Tripoli"`. `null` when [timezone] is absent or
  /// has no `/` segment.
  String? get timezoneCityLabel {
    final tz = timezone;
    if (tz == null || !tz.contains('/')) return null;
    final last = tz.split('/').last;
    if (last.isEmpty) return null;
    return last.replaceAll('_', ' ');
  }
}

/// Fetches prayer timings for a single day from a remote source (Aladhan).
abstract class PrayerTimesRepository {
  /// Legacy `locatePrayer`'s GPS path (`/v1/timings/{date}`).
  Future<PrayerTimesFetchResult> fetchByCoordinates({
    required double latitude,
    required double longitude,
    required int method,
  });

  /// Legacy `fetchPrayerTimes`'s manual-city path (`/v1/timingsByCity/{date}`).
  Future<PrayerTimesFetchResult> fetchByCity({
    required String city,
    required String country,
    required int method,
  });
}
