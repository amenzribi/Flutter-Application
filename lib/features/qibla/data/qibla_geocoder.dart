import 'dart:convert';

import 'package:http/http.dart' as http;

/// Coordinates of a city for the qibla, from the Open-Meteo geocoding API
/// (free, no key).
///
/// The legacy app used Aladhan's `timingsByCity` metadata, but that endpoint
/// now returns placeholder coordinates (8.8888888, 7.7777777) for every
/// city, which gives a wrong qibla direction. Prayer times by city are not
/// affected: Aladhan still computes those correctly.
///
/// When [country] is given, the first result whose country name or code
/// contains it wins; otherwise the most relevant result. `null` when nothing
/// matches or the service is unreachable.
Future<({double lat, double lng})?> geocodeCity(
  String city,
  String country, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': city.trim(),
      'count': '10',
      'language': 'en',
      'format': 'json',
    });
    final response = await c.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    final results = json is Map ? json['results'] : null;
    if (results is! List || results.isEmpty) return null;
    return pickGeocodeResult(results, country);
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Chooses the result for [country] (see [geocodeCity]). Public for tests.
({double lat, double lng})? pickGeocodeResult(List results, String country) {
  final want = country.trim().toLowerCase();
  Map? chosen;
  for (final r in results) {
    if (r is! Map) continue;
    if (want.isEmpty) {
      chosen = r;
      break;
    }
    final name = '${r['country'] ?? ''}'.toLowerCase();
    final code = '${r['country_code'] ?? ''}'.toLowerCase();
    if (name.contains(want) ||
        want.contains(name) && name.isNotEmpty ||
        code == want) {
      chosen = r;
      break;
    }
  }
  // Country typed in Arabic cannot match the English names: fall back to the
  // most relevant result rather than failing.
  if (chosen == null && RegExp('[؀-ۿ]').hasMatch(want)) {
    chosen = results.whereType<Map>().firstOrNull;
  }
  if (chosen == null) return null;
  final lat = chosen['latitude'];
  final lng = chosen['longitude'];
  if (lat is! num || lng is! num) return null;
  return (lat: lat.toDouble(), lng: lng.toDouble());
}
