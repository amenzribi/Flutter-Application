import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';

/// In-memory [PrayerTimesRepository] for unit/widget tests — no live
/// Aladhan network calls.
class FakePrayerTimesRepository implements PrayerTimesRepository {
  FakePrayerTimesRepository({
    this.byCityResult,
    this.byCoordinatesResult,
    this.throwsError = false,
  });

  PrayerTimesFetchResult? byCityResult;
  PrayerTimesFetchResult? byCoordinatesResult;
  bool throwsError;
  int cityCalls = 0;
  int coordinatesCalls = 0;

  @override
  Future<PrayerTimesFetchResult> fetchByCity({
    required String city,
    required String country,
    required int method,
  }) async {
    cityCalls++;
    if (throwsError) throw Exception('network error');
    return byCityResult ?? const PrayerTimesFetchResult(times: {});
  }

  @override
  Future<PrayerTimesFetchResult> fetchByCoordinates({
    required double latitude,
    required double longitude,
    required int method,
  }) async {
    coordinatesCalls++;
    if (throwsError) throw Exception('network error');
    return byCoordinatesResult ?? const PrayerTimesFetchResult(times: {});
  }
}
