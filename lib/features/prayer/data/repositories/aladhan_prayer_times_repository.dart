import 'package:barakah40_flutter/features/prayer/data/sources/aladhan_api_client.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';

/// [PrayerTimesRepository] backed directly by [AladhanApiClient] — no
/// caching here; same-day cache logic lives in [PrayerSettings]/the
/// schedule controller (legacy `fetchPrayerTimes`'s `timesDate` check).
class AladhanPrayerTimesRepository implements PrayerTimesRepository {
  AladhanPrayerTimesRepository({AladhanApiClient? client})
    : _client = client ?? AladhanApiClient();

  final AladhanApiClient _client;

  @override
  Future<PrayerTimesFetchResult> fetchByCoordinates({
    required double latitude,
    required double longitude,
    required int method,
  }) {
    return _client.fetchByCoordinates(
      latitude: latitude,
      longitude: longitude,
      method: method,
    );
  }

  @override
  Future<PrayerTimesFetchResult> fetchByCity({
    required String city,
    required String country,
    required int method,
  }) {
    return _client.fetchByCity(city: city, country: country, method: method);
  }
}
