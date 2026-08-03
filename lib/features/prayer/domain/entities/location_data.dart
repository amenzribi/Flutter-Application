/// Runtime location context for prayer times (legacy `S.prayer.{city,
/// country, lat, lng, tz}`). `lat`/`lng`/`tz` are only ever populated by a
/// GPS fetch (never by the manual-city path).
class LocationData {
  const LocationData({
    this.city = '',
    this.country = '',
    this.lat,
    this.lng,
    this.tz,
  });

  final String city;
  final String country;
  final double? lat;
  final double? lng;
  final String? tz;

  bool get hasCity => city.trim().isNotEmpty;
  bool get hasCoordinates => lat != null && lng != null;
}
