/// Adhkar and duas content, copied verbatim from the legacy app's `ADHKAR`
/// and `DUAS` constants into `assets/data/adhkar.json` and
/// `assets/data/duas.json` (never retyped).
library;

enum AdhkarSession {
  morning,
  evening;

  String get label => this == morning ? 'الصباح' : 'المساء';
}

/// One dhikr. Quranic entries ([quranRef] `kursi` or `muawidhat`) carry no
/// text: it is loaded from the Quran sources, as in the legacy app.
class Dhikr {
  const Dhikr({
    required this.text,
    required this.count,
    required this.source,
    this.quranRef,
  });

  final String text;

  /// How many times it is said (legacy `c`).
  final int count;

  /// Source or note shown under the text (legacy `s`).
  final String source;
  final String? quranRef;

  bool get isQuran => quranRef != null;

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
    text: json['t'] as String? ?? '',
    count: (json['c'] as num?)?.toInt() ?? 1,
    source: json['s'] as String? ?? '',
    quranRef: json['ref'] as String?,
  );
}

class AdhkarCatalog {
  const AdhkarCatalog({required this.morning, required this.evening});

  final List<Dhikr> morning;
  final List<Dhikr> evening;

  List<Dhikr> of(AdhkarSession session) =>
      session == AdhkarSession.morning ? morning : evening;

  /// Legacy `adhKey(i)`: `'morning_3'`, the key in `S.adhkarCount`.
  static String key(AdhkarSession session, int index) =>
      '${session.name}_$index';

  factory AdhkarCatalog.fromJson(Map<String, dynamic> json) {
    List<Dhikr> list(String k) => [
      for (final e in (json[k] as List? ?? const []))
        Dhikr.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    return AdhkarCatalog(morning: list('morning'), evening: list('evening'));
  }
}

class Dua {
  const Dua({required this.category, required this.text, required this.source});

  final String category;
  final String text;
  final String source;

  factory Dua.fromJson(Map<String, dynamic> json) => Dua(
    category: json['cat'] as String? ?? '',
    text: json['t'] as String? ?? '',
    source: json['s'] as String? ?? '',
  );
}

/// Legacy `S.adhkarCount[key]`, tolerant of missing or odd values.
int dhikrCountOf(Map<String, dynamic> counts, String key) {
  final v = counts[key];
  return v is num ? v.toInt() : 0;
}
