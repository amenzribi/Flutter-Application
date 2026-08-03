import 'package:barakah40_flutter/features/user_state/domain/entities/json_helpers.dart';

/// Mirrors legacy `S.qibla` = `{lat, lng, city}`.
class QiblaSettings {
  const QiblaSettings({
    this.lat,
    this.lng,
    this.city = '',
    this.extra = const {},
  });

  final double? lat;
  final double? lng;
  final String city;
  final Map<String, dynamic> extra;

  factory QiblaSettings.fromJson(Map<String, dynamic>? json) {
    final map = Map<String, dynamic>.from(json ?? const {});
    final lat = JsonHelpers.asDoubleOrNull(map.remove('lat'));
    final lng = JsonHelpers.asDoubleOrNull(map.remove('lng'));
    final city = JsonHelpers.asString(map.remove('city'), '');
    return QiblaSettings(lat: lat, lng: lng, city: city, extra: map);
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'lat': lat,
    'lng': lng,
    'city': city,
  };

  QiblaSettings copyWith({
    double? lat,
    bool clearLat = false,
    double? lng,
    bool clearLng = false,
    String? city,
    Map<String, dynamic>? extra,
  }) {
    return QiblaSettings(
      lat: clearLat ? null : (lat ?? this.lat),
      lng: clearLng ? null : (lng ?? this.lng),
      city: city ?? this.city,
      extra: extra ?? this.extra,
    );
  }
}
