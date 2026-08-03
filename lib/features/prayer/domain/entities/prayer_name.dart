/// The five daily prayers, in legacy display/iteration order
/// (`const PRAYERS=[['fajr','الفجر'],...]`).
enum PrayerName {
  fajr('fajr', 'الفجر', 0),
  dhuhr('dhuhr', 'الظهر', 1),
  asr('asr', 'العصر', 2),
  maghrib('maghrib', 'المغرب', 3),
  isha('isha', 'العشاء', 4);

  const PrayerName(this.key, this.arabicLabel, this.order);

  /// Legacy storage key, e.g. in `S.prayer.log[dayKey]` and `S.prayer.times`.
  final String key;

  /// Arabic display label (`PNAMES`).
  final String arabicLabel;

  /// 0-based legacy iteration order (fajr..isha).
  final int order;

  /// Resolves a legacy prayer key (e.g. `'fajr'`) back to its [PrayerName],
  /// or `null` when [key] isn't one of the five recognized keys.
  static PrayerName? fromKey(String? key) {
    for (final name in PrayerName.values) {
      if (name.key == key) return name;
    }
    return null;
  }
}
