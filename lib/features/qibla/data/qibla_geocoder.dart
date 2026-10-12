import 'dart:convert';

import 'package:http/http.dart' as http;

/// Legacy `geocodeCity`: coordinates of a city from Aladhan's
/// `timingsByCity` response metadata (method 5), or `null` when not found.
Future<({double lat, double lng})?> geocodeCity(
  String city,
  String country, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final uri =
        Uri.parse(
          'https://api.aladhan.com/v1/timingsByCity/'
          '${two(now.day)}-${two(now.month)}-${now.year}',
        ).replace(
          queryParameters: {'city': city, 'country': country, 'method': '5'},
        );
    final response = await c.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    final meta = json is Map && json['data'] is Map
        ? (json['data'] as Map)['meta']
        : null;
    if (meta is! Map) return null;
    final lat = meta['latitude'];
    final lng = meta['longitude'];
    if (lat is! num || lng is! num) return null;
    return (lat: lat.toDouble(), lng: lng.toDouble());
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
