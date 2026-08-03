import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_calculation_method.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';

/// Thrown when an Aladhan request fails outright or returns a payload with
/// no usable timings. Callers never fabricate a schedule to paper over this.
class AladhanApiException implements Exception {
  const AladhanApiException(this.message);

  final String message;

  @override
  String toString() => 'AladhanApiException: $message';
}

/// Thin client for the two legacy Aladhan endpoints
/// (`docs/migration-analysis/FLUTTER_PRAYER_TIMES.md` § 1):
/// `/v1/timings/{dd-MM-yyyy}` (GPS) and `/v1/timingsByCity/{dd-MM-yyyy}`
/// (manual city). 12s timeout per request, matching legacy's
/// `navigator.geolocation` timeout and the app's other network calls.
class AladhanApiClient {
  AladhanApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Duration timeout = Duration(seconds: 12);
  static const String _baseUrl = 'https://api.aladhan.com/v1';

  Future<PrayerTimesFetchResult> fetchByCoordinates({
    required double latitude,
    required double longitude,
    int method = PrayerCalculationMethod.legacyDefault,
    DateTime? date,
  }) {
    final uri =
        Uri.parse(
          '$_baseUrl/timings/${_dateSegment(date ?? DateTime.now())}',
        ).replace(
          queryParameters: {
            'latitude': '$latitude',
            'longitude': '$longitude',
            'method': '$method',
          },
        );
    return _fetch(uri);
  }

  Future<PrayerTimesFetchResult> fetchByCity({
    required String city,
    required String country,
    int method = PrayerCalculationMethod.legacyDefault,
    DateTime? date,
  }) {
    final uri =
        Uri.parse(
          '$_baseUrl/timingsByCity/${_dateSegment(date ?? DateTime.now())}',
        ).replace(
          queryParameters: {
            'city': city,
            'country': country,
            'method': '$method',
          },
        );
    return _fetch(uri);
  }

  Future<PrayerTimesFetchResult> _fetch(Uri uri) async {
    final http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(timeout);
    } catch (error) {
      throw AladhanApiException('Aladhan request failed: $error');
    }

    if (response.statusCode != 200) {
      throw AladhanApiException(
        'Aladhan returned status ${response.statusCode}',
      );
    }

    Object? json;
    try {
      json = jsonDecode(response.body);
    } catch (error) {
      throw AladhanApiException('Aladhan returned invalid JSON: $error');
    }

    if (json is! Map) {
      throw const AladhanApiException('Aladhan payload was not a JSON object');
    }

    final result = parseTimings(Map<String, dynamic>.from(json));
    if (result == null || result.times.isEmpty) {
      throw const AladhanApiException('Aladhan payload had no usable timings');
    }
    return result;
  }

  /// `dd-MM-yyyy`, matching legacy's date segment exactly.
  static String _dateSegment(DateTime date) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}-${pad(date.month)}-${date.year}';
  }

  /// Parses `{data:{timings:{Fajr,...}, meta:{timezone}}}`, cleaning each
  /// time string to `HH:MM` (legacy `clean=s=>(s||'').split(' ')[0]`, which
  /// strips e.g. Aladhan's `"04:12 (EET)"` suffix). Prayers with an empty or
  /// missing value are simply absent from the result — never defaulted.
  /// Returns `null` when the response doesn't have the expected shape.
  static PrayerTimesFetchResult? parseTimings(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) return null;
    final timings = data['timings'];
    if (timings is! Map) return null;

    String? clean(Object? value) {
      if (value is! String || value.isEmpty) return null;
      final head = value.split(' ').first;
      return head.isEmpty ? null : head;
    }

    const mapping = {
      PrayerName.fajr: 'Fajr',
      PrayerName.dhuhr: 'Dhuhr',
      PrayerName.asr: 'Asr',
      PrayerName.maghrib: 'Maghrib',
      PrayerName.isha: 'Isha',
    };

    final times = <PrayerName, String>{};
    for (final entry in mapping.entries) {
      final cleaned = clean(timings[entry.value]);
      if (cleaned != null) times[entry.key] = cleaned;
    }

    String? timezone;
    final meta = data['meta'];
    if (meta is Map) {
      final tz = meta['timezone'];
      if (tz is String && tz.isNotEmpty) timezone = tz;
    }

    return PrayerTimesFetchResult(times: times, timezone: timezone);
  }

  void close() => _httpClient.close();
}
