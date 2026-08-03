/// Aladhan calculation method configuration.
///
/// Legacy has **no** method/madhhab picker UI — it always sends
/// `S.prayer.method || 5`. Option A (legacy-faithful) keeps this the same:
/// there is no method list or picker anywhere in the Flutter client, only
/// this documented constant. See
/// `docs/migration-analysis/FLUTTER_PRAYER_TIMES.md` § 3.
abstract final class PrayerCalculationMethod {
  /// Aladhan method id `5` — Egyptian General Authority of Survey. The only
  /// method this app ever requests.
  static const int legacyDefault = 5;

  /// Human label for the (single, non-configurable) method, for any
  /// diagnostic/about text — never shown as a choice.
  static const String legacyDefaultLabel = 'الهيئة المصرية العامة للمساحة';
}
