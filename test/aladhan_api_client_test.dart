import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:barakah40_flutter/features/prayer/data/sources/aladhan_api_client.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

void main() {
  group('AladhanApiClient.parseTimings', () {
    test('parses Fajr..Isha and strips trailing timezone annotations', () {
      final json = {
        'data': {
          'timings': {
            'Fajr': '04:12 (EET)',
            'Sunrise': '05:47 (EET)',
            'Dhuhr': '12:34 (EET)',
            'Asr': '16:02 (EET)',
            'Sunset': '19:10 (EET)',
            'Maghrib': '19:10 (EET)',
            'Isha': '20:35 (EET)',
          },
          'meta': {'timezone': 'Africa/Tripoli'},
        },
      };

      final result = AladhanApiClient.parseTimings(json);

      expect(result, isNotNull);
      expect(result!.times[PrayerName.fajr], '04:12');
      expect(result.times[PrayerName.dhuhr], '12:34');
      expect(result.times[PrayerName.asr], '16:02');
      expect(result.times[PrayerName.maghrib], '19:10');
      expect(result.times[PrayerName.isha], '20:35');
      // Sunrise/Sunset are not one of the five tracked prayers.
      expect(result.times.length, 5);
      expect(result.timezone, 'Africa/Tripoli');
      expect(result.timezoneCityLabel, 'Tripoli');
    });

    test('returns null when data.timings is missing', () {
      expect(AladhanApiClient.parseTimings({'foo': 'bar'}), isNull);
    });

    test('returns null when "data" is missing entirely', () {
      expect(AladhanApiClient.parseTimings({}), isNull);
    });

    test('omits a prayer whose value is an empty string', () {
      final json = {
        'data': {
          'timings': {
            'Fajr': '',
            'Dhuhr': '12:00',
            'Asr': '15:30',
            'Maghrib': '18:45',
            'Isha': '20:00',
          },
        },
      };
      final result = AladhanApiClient.parseTimings(json);
      expect(result!.times.containsKey(PrayerName.fajr), isFalse);
      expect(result.times[PrayerName.dhuhr], '12:00');
    });

    test('has no timezoneCityLabel when meta.timezone is absent', () {
      final json = {
        'data': {
          'timings': {'Fajr': '04:00'},
        },
      };
      final result = AladhanApiClient.parseTimings(json);
      expect(result!.timezone, isNull);
      expect(result.timezoneCityLabel, isNull);
    });
  });

  group('AladhanApiClient.fetchByCity', () {
    test(
      'builds the legacy timingsByCity URL and parses the response',
      () async {
        late Uri requestedUri;
        final mockClient = MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'data': {
                'timings': {
                  'Fajr': '04:12',
                  'Dhuhr': '12:34',
                  'Asr': '16:02',
                  'Maghrib': '19:10',
                  'Isha': '20:35',
                },
              },
            }),
            200,
          );
        });
        final client = AladhanApiClient(httpClient: mockClient);

        final result = await client.fetchByCity(
          city: 'Tripoli',
          country: 'Libya',
          method: 5,
          date: DateTime(2026, 8, 4),
        );

        expect(requestedUri.path, contains('timingsByCity/04-08-2026'));
        expect(requestedUri.queryParameters['city'], 'Tripoli');
        expect(requestedUri.queryParameters['country'], 'Libya');
        expect(requestedUri.queryParameters['method'], '5');
        expect(result.times[PrayerName.fajr], '04:12');
      },
    );

    test('throws AladhanApiException on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('', 500));
      final client = AladhanApiClient(httpClient: mockClient);

      expect(
        () => client.fetchByCity(city: 'Tripoli', country: 'Libya', method: 5),
        throwsA(isA<AladhanApiException>()),
      );
    });

    test(
      'throws AladhanApiException when the payload has no timings',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response(jsonEncode({'data': {}}), 200),
        );
        final client = AladhanApiClient(httpClient: mockClient);

        expect(
          () =>
              client.fetchByCity(city: 'Tripoli', country: 'Libya', method: 5),
          throwsA(isA<AladhanApiException>()),
        );
      },
    );

    test('throws AladhanApiException on invalid JSON', () async {
      final mockClient = MockClient(
        (request) async => http.Response('not json', 200),
      );
      final client = AladhanApiClient(httpClient: mockClient);

      expect(
        () => client.fetchByCity(city: 'Tripoli', country: 'Libya', method: 5),
        throwsA(isA<AladhanApiException>()),
      );
    });
  });

  group('AladhanApiClient.fetchByCoordinates', () {
    test('builds the legacy timings URL with lat/lng and method', () async {
      late Uri requestedUri;
      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'data': {
              'timings': {
                'Fajr': '04:12',
                'Dhuhr': '12:34',
                'Asr': '16:02',
                'Maghrib': '19:10',
                'Isha': '20:35',
              },
              'meta': {'timezone': 'Africa/Tripoli'},
            },
          }),
          200,
        );
      });
      final client = AladhanApiClient(httpClient: mockClient);

      final result = await client.fetchByCoordinates(
        latitude: 32.9,
        longitude: 13.2,
        method: 5,
        date: DateTime(2026, 8, 4),
      );

      expect(requestedUri.path, contains('timings/04-08-2026'));
      expect(requestedUri.queryParameters['latitude'], '32.9');
      expect(requestedUri.queryParameters['longitude'], '13.2');
      expect(result.timezone, 'Africa/Tripoli');
    });
  });
}
