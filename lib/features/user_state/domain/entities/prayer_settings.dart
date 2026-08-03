import 'package:barakah40_flutter/features/user_state/domain/entities/json_helpers.dart';

/// Mirrors legacy `S.prayer` = `{log, city, country, method, times, timesDate}`.
///
/// `log` is keyed by `dayKey()` (`yyyy-MM-dd`, local time) → per-prayer bool
/// map, e.g. `{fajr: true, dhuhr: false, ...}`. Runtime-only keys observed on
/// some documents (`lat`, `lng`, `tz`) are preserved in [extra].
class PrayerSettings {
  const PrayerSettings({
    this.log = const {},
    this.city = '',
    this.country = '',
    this.method = 5,
    this.times = const {},
    this.timesDate = '',
    this.extra = const {},
  });

  final Map<String, dynamic> log;
  final String city;
  final String country;
  final int method;
  final Map<String, dynamic> times;
  final String timesDate;
  final Map<String, dynamic> extra;

  factory PrayerSettings.fromJson(Map<String, dynamic>? json) {
    final map = Map<String, dynamic>.from(json ?? const {});
    final log = JsonHelpers.asMap(map.remove('log'));
    final city = JsonHelpers.asString(map.remove('city'), '');
    final country = JsonHelpers.asString(map.remove('country'), '');
    final method = JsonHelpers.asInt(map.remove('method'), 5);
    final times = JsonHelpers.asMap(map.remove('times'));
    final timesDate = JsonHelpers.asString(map.remove('timesDate'), '');
    return PrayerSettings(
      log: log,
      city: city,
      country: country,
      method: method,
      times: times,
      timesDate: timesDate,
      extra: map,
    );
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'log': log,
    'city': city,
    'country': country,
    'method': method,
    'times': times,
    'timesDate': timesDate,
  };

  PrayerSettings copyWith({
    Map<String, dynamic>? log,
    String? city,
    String? country,
    int? method,
    Map<String, dynamic>? times,
    String? timesDate,
    Map<String, dynamic>? extra,
  }) {
    return PrayerSettings(
      log: log ?? this.log,
      city: city ?? this.city,
      country: country ?? this.country,
      method: method ?? this.method,
      times: times ?? this.times,
      timesDate: timesDate ?? this.timesDate,
      extra: extra ?? this.extra,
    );
  }

  /// Today's per-prayer record (legacy `dayRec(k)`), or empty if unset.
  Map<String, dynamic> recordFor(String dayKey) {
    final record = log[dayKey];
    if (record is Map) {
      return record.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }
}
