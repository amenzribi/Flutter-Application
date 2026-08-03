/// Defensive JSON coercion helpers used by [UserAppState] and its nested
/// value types.
///
/// Legacy `barakah_pro_v1` / `users/{uid}.state` payloads were produced by
/// loosely-typed JavaScript and can be hand-edited or partially written
/// during a crash. These helpers make `fromJson` best-effort per field
/// instead of throwing, mirroring legacy's
/// `Object.assign(freshDefaults(), data.state)` recovery behavior — a bad
/// value for one field never invalidates the rest of the document.
abstract final class JsonHelpers {
  static bool asBool(Object? value, bool fallback) {
    if (value is bool) return value;
    return fallback;
  }

  static String asString(Object? value, String fallback) {
    if (value is String) return value;
    return fallback;
  }

  static int asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static int? asIntOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static double asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  static double? asDoubleOrNull(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return <String, dynamic>{};
  }

  static List<dynamic> asList(Object? value) {
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  /// Coerces [value] to a fixed-length bool list, padding/truncating and
  /// substituting [fill] for any non-bool entry. Never throws.
  static List<bool> asBoolList(Object? value, int length, bool fill) {
    final result = List<bool>.filled(length, fill);
    if (value is List) {
      for (var i = 0; i < length && i < value.length; i++) {
        final entry = value[i];
        if (entry is bool) result[i] = entry;
      }
    }
    return result;
  }
}
