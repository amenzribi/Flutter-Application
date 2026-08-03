import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';

/// Thrown when every configured Quran text source failed or returned an
/// incomplete/unparseable payload.
class QuranTextUnavailableException implements Exception {
  const QuranTextUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'QuranTextUnavailableException: $message';
}

/// Fetches the Al-Baqarah Uthmani text from the three legacy sources, in
/// order, with a 12s timeout per attempt (`withTimeout(fetch(...), 12000)`
/// in `web/index.html`).
///
/// Parsing is split into standalone static methods so unit tests can feed
/// fixture JSON without any network access.
class QuranApiClient {
  QuranApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Duration timeout = Duration(seconds: 12);

  static const String alquranCloudUrl =
      'https://api.alquran.cloud/v1/surah/2/quran-uthmani';
  static const String quranComUrl =
      'https://api.quran.com/api/v4/quran/verses/uthmani?chapter_number=2';
  static const String jsDelivrUrl =
      'https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/chapters/ar/2.json';

  static const int expectedAyahCount = 286;

  /// Tries each source in the legacy-specified order; returns the first
  /// one that parses to exactly [expectedAyahCount] ayahs. Throws
  /// [QuranTextUnavailableException] if none do.
  Future<List<Ayah>> fetchBaqarah() async {
    for (final attempt in <Future<List<Ayah>?> Function()>[
      _fetchAlquranCloud,
      _fetchQuranCom,
      _fetchJsDelivr,
    ]) {
      List<Ayah>? result;
      try {
        result = await attempt();
      } catch (_) {
        result = null;
      }
      if (result != null && result.length == expectedAyahCount) {
        return result;
      }
    }
    throw const QuranTextUnavailableException('Quran text sources unavailable');
  }

  Future<List<Ayah>?> _fetchAlquranCloud() async {
    final response = await _httpClient
        .get(Uri.parse(alquranCloudUrl))
        .timeout(timeout);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    return parseAlquranCloud(Map<String, dynamic>.from(json));
  }

  Future<List<Ayah>?> _fetchQuranCom() async {
    final response = await _httpClient
        .get(Uri.parse(quranComUrl))
        .timeout(timeout);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    return parseQuranCom(Map<String, dynamic>.from(json));
  }

  Future<List<Ayah>?> _fetchJsDelivr() async {
    final response = await _httpClient
        .get(Uri.parse(jsDelivrUrl))
        .timeout(timeout);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    return parseJsDelivr(Map<String, dynamic>.from(json));
  }

  /// `{data:{ayahs:[{numberInSurah,text},...]}}` — basmala stripped from
  /// ayah 1, other ayahs trimmed.
  static List<Ayah>? parseAlquranCloud(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) return null;
    final ayahs = data['ayahs'];
    if (ayahs is! List) return null;
    final result = <Ayah>[];
    for (final entry in ayahs) {
      if (entry is! Map) return null;
      final n = entry['numberInSurah'];
      final text = entry['text'];
      if (n is! num || text is! String) return null;
      final numberInSurah = n.toInt();
      result.add(
        Ayah(
          n: numberInSurah,
          text: numberInSurah == 1 ? stripBasmala(text) : text.trim(),
        ),
      );
    }
    return result;
  }

  /// `{verses:[{verse_key:"2:N",text_uthmani},...]}`.
  static List<Ayah>? parseQuranCom(Map<String, dynamic> json) {
    final verses = json['verses'];
    if (verses is! List) return null;
    final result = <Ayah>[];
    for (final entry in verses) {
      if (entry is! Map) return null;
      final verseKey = entry['verse_key'];
      final text = entry['text_uthmani'];
      if (verseKey is! String || text is! String) return null;
      final parts = verseKey.split(':');
      if (parts.length != 2) return null;
      final n = int.tryParse(parts[1]);
      if (n == null) return null;
      result.add(Ayah(n: n, text: n == 1 ? stripBasmala(text) : text.trim()));
    }
    return result;
  }

  /// `{verses:[{id,text},...]}` — legacy does **not** strip the basmala on
  /// this fallback (`text:String(v.text).trim()`); kept faithful.
  static List<Ayah>? parseJsDelivr(Map<String, dynamic> json) {
    final verses = json['verses'];
    if (verses is! List) return null;
    final result = <Ayah>[];
    for (final entry in verses) {
      if (entry is! Map) return null;
      final id = entry['id'];
      final text = entry['text'];
      if (id is! num || text == null) return null;
      result.add(Ayah(n: id.toInt(), text: text.toString().trim()));
    }
    return result;
  }

  /// Legacy `stripBasmala`: strips a leading basmala in either its
  /// Uthmani-diacritic form or the Uthmani-orthography (small-letter) form,
  /// then trims. Matches:
  /// `/^بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\s*/` and
  /// `/^بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِیمِ\s*/`.
  static String stripBasmala(String text) {
    final variant1 = RegExp(r'^بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\s*');
    final variant2 = RegExp(r'^بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِیمِ\s*');
    return text.replaceFirst(variant1, '').replaceFirst(variant2, '').trim();
  }

  void close() => _httpClient.close();
}
