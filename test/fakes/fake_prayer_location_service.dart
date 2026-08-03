import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';

/// In-memory [PrayerLocationService] for unit/widget tests — no platform
/// channel calls.
class FakePrayerLocationService implements PrayerLocationService {
  FakePrayerLocationService(this.result);

  PrayerLocationResult result;
  int calls = 0;

  @override
  Future<PrayerLocationResult> getCurrentLocation() async {
    calls++;
    return result;
  }
}
