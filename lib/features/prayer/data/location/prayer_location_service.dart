import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Outcome of a single one-shot location lookup.
enum PrayerLocationStatus {
  success,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error,
}

/// Result of [PrayerLocationService.getCurrentLocation].
class PrayerLocationResult {
  const PrayerLocationResult._({
    required this.status,
    this.latitude,
    this.longitude,
    this.message,
  });

  final PrayerLocationStatus status;
  final double? latitude;
  final double? longitude;
  final String? message;

  bool get isSuccess => status == PrayerLocationStatus.success;

  factory PrayerLocationResult.success({
    required double latitude,
    required double longitude,
  }) => PrayerLocationResult._(
    status: PrayerLocationStatus.success,
    latitude: latitude,
    longitude: longitude,
  );

  factory PrayerLocationResult.permissionDenied() =>
      const PrayerLocationResult._(
        status: PrayerLocationStatus.permissionDenied,
      );

  factory PrayerLocationResult.permissionDeniedForever() =>
      const PrayerLocationResult._(
        status: PrayerLocationStatus.permissionDeniedForever,
      );

  factory PrayerLocationResult.serviceDisabled() =>
      const PrayerLocationResult._(
        status: PrayerLocationStatus.serviceDisabled,
      );

  factory PrayerLocationResult.error(String message) => PrayerLocationResult._(
    status: PrayerLocationStatus.error,
    message: message,
  );
}

/// User-facing explanations for each non-success [PrayerLocationStatus],
/// shown by the prayer times screen (never a silent failure).
abstract final class PrayerLocationCopy {
  static const permissionDeniedExplanation =
      'يحتاج التطبيق إذن الوصول للموقع لجلب أوقات الصلاة حسب موقعكِ مرة واحدة، '
      'دون تتبّع مستمر. يمكنكِ منح الإذن من إعدادات الجهاز أو إدخال المدينة '
      'يدويًا.';
  static const serviceDisabledExplanation =
      'خدمة الموقع غير مُفعّلة على جهازكِ. فعّليها من الإعدادات أو أدخلي '
      'المدينة يدويًا.';
  static const genericErrorExplanation =
      'تعذّر تحديد موقعكِ. حاولي مرة أخرى أو أدخلي المدينة يدويًا.';
}

/// One-shot device location lookup for prayer times (legacy `locatePrayer`).
/// Never watches position continuously.
abstract class PrayerLocationService {
  Future<PrayerLocationResult> getCurrentLocation();
}

/// [PrayerLocationService] backed by `package:geolocator`.
class GeolocatorPrayerLocationService implements PrayerLocationService {
  const GeolocatorPrayerLocationService();

  @override
  Future<PrayerLocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return PrayerLocationResult.serviceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return PrayerLocationResult.permissionDenied();
      }
      if (permission == LocationPermission.deniedForever) {
        return PrayerLocationResult.permissionDeniedForever();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return PrayerLocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      return PrayerLocationResult.error(
        PrayerLocationCopy.genericErrorExplanation,
      );
    } catch (_) {
      return PrayerLocationResult.error(
        PrayerLocationCopy.genericErrorExplanation,
      );
    }
  }
}
