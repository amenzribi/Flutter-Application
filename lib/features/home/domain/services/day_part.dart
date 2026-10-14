import 'package:barakah40_flutter/features/prayer/domain/entities/daily_prayer_schedule.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// Legacy `dayPeriod()` + `periodSky()`: drives the time-of-day home
/// background and greeting.
enum DayPart {
  fajr('الفجر', 'بدايةٌ جديدة ورزقٌ من الله'),
  morning('الصباح', 'صباح الخير، تفاءلي واستبشري'),
  dhuhr('الظهر', 'وقت العمل والإنجاز'),
  asr('العصر', 'واصلي طريقكِ نحو الأفضل'),
  maghrib('المغرب', 'لحظة شكرٍ وبداية راحة'),
  night('الليل', 'وقت السكينة والتأمل');

  const DayPart(this.arabicName, this.subtitle);

  final String arabicName;
  final String subtitle;

  String get backgroundAsset => 'assets/images/bg/bg_$name.webp';

  /// Uses today's prayer times when known (Fajr+80min, Dhuhr, Asr, Maghrib,
  /// Isha or Maghrib+90), else the legacy fixed-hour fallback.
  static DayPart of(DateTime now, {DailyPrayerSchedule? schedule}) {
    final mins = now.hour * 60 + now.minute;
    int? m(PrayerName p) {
      final raw = schedule?.times[p];
      if (raw == null) return null;
      final parts = RegExp(
        r'\d+',
      ).allMatches(raw).map((x) => x.group(0)!).toList();
      if (parts.length < 2) return null;
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    final f = m(PrayerName.fajr);
    final d = m(PrayerName.dhuhr);
    final a = m(PrayerName.asr);
    final mg = m(PrayerName.maghrib);
    if (f != null && d != null && a != null && mg != null) {
      final isha = m(PrayerName.isha) ?? mg + 90;
      if (mins < f) return DayPart.night;
      if (mins < f + 80) return DayPart.fajr;
      if (mins < d) return DayPart.morning;
      if (mins < a) return DayPart.dhuhr;
      if (mins < mg) return DayPart.asr;
      if (mins < isha) return DayPart.maghrib;
      return DayPart.night;
    }
    final h = now.hour;
    if (h >= 4 && h < 6) return DayPart.fajr;
    if (h >= 6 && h < 11) return DayPart.morning;
    if (h >= 11 && h < 15) return DayPart.dhuhr;
    if (h >= 15 && h < 17) return DayPart.asr;
    if (h >= 17 && h < 19) return DayPart.maghrib;
    return DayPart.night;
  }
}
