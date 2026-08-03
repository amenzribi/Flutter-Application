import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';

/// A fully-loaded surah's ayah list.
///
/// Milestone 6 only ever constructs this for Al-Baqarah (surah 2, 286
/// ayahs), so the constructor validates that invariant rather than trusting
/// callers — a truncated/partial fetch must never silently become a
/// "surah" with fewer ayahs than the real mushaf.
class Surah {
  Surah({required this.number, required this.name, required List<Ayah> ayahs})
    : ayahs = List.unmodifiable(ayahs) {
    if (number == alBaqarahNumber && this.ayahs.length != alBaqarahAyahCount) {
      throw ArgumentError.value(
        this.ayahs.length,
        'ayahs.length',
        'Surah Al-Baqarah must have exactly $alBaqarahAyahCount ayahs',
      );
    }
  }

  static const int alBaqarahNumber = 2;
  static const int alBaqarahAyahCount = 286;

  final int number;
  final String name;
  final List<Ayah> ayahs;

  factory Surah.baqarah(List<Ayah> ayahs, {String name = 'البقرة'}) =>
      Surah(number: alBaqarahNumber, name: name, ayahs: ayahs);
}
