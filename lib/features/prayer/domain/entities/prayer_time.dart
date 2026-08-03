import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// A single prayer's cleaned `HH:MM` time string, resolved against a
/// specific calendar day (legacy `t.split(':').map(Number)` +
/// `d.setHours(pr[0],pr[1],0,0)`).
class PrayerTime {
  const PrayerTime({required this.name, this.time, this.dateTime});

  final PrayerName name;

  /// Cleaned `HH:MM` string (legacy `clean=s=>(s||'').split(' ')[0]`), or
  /// `null` when no time is known — never an invented placeholder.
  final String? time;

  /// [time] combined with the day it was resolved for, or `null` when
  /// [time] is absent/unparseable.
  final DateTime? dateTime;

  bool get hasTime => time != null && time!.isNotEmpty;

  /// Builds a [PrayerTime] for [name] on [day] from a raw `HH:MM` string
  /// (or `null`/malformed, in which case both [time] and [dateTime] stay
  /// `null` — this never fabricates a prayer time).
  factory PrayerTime.forDay(PrayerName name, String? rawTime, DateTime day) {
    final cleaned = (rawTime != null && rawTime.isNotEmpty) ? rawTime : null;
    return PrayerTime(
      name: name,
      time: cleaned,
      dateTime: _combine(day, cleaned),
    );
  }

  static DateTime? _combine(DateTime day, String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
