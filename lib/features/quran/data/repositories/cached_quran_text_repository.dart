import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/quran/data/sources/quran_api_client.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';
import 'package:barakah40_flutter/features/quran/domain/repositories/quran_text_repository.dart';

/// memory -> SharedPreferences (`baq_cache_v1`) -> network fallback chain,
/// matching legacy `ensureBaqarah`/`Store.get('baq_cache_v1')`.
///
/// This cache is deliberately **device-local only** — it is never part of
/// [UserAppState]/`users/{uid}.state`, matching legacy's separation of the
/// Quran text cache from the synced progress blob.
///
/// Never returns a partial/placeholder surah: a corrupt or short cache
/// entry is discarded (and the stored key cleared) instead of being
/// returned, falling through to a fresh network fetch.
class CachedQuranTextRepository implements QuranTextRepository {
  CachedQuranTextRepository({
    required SharedPreferences prefs,
    QuranApiClient? apiClient,
  }) : // Named `prefs:` keeps call sites readable; see the analogous
       // comment in UserStateController.
       // ignore: prefer_initializing_formals
       _prefs = prefs,
       _apiClient = apiClient ?? QuranApiClient();

  /// Legacy `Store.get('baq_cache_v1')` key.
  static const String cacheKey = 'baq_cache_v1';

  static const int expectedAyahCount = QuranApiClient.expectedAyahCount;

  final SharedPreferences _prefs;
  final QuranApiClient _apiClient;

  List<Ayah>? _memoryCache;

  @override
  Future<List<Ayah>> loadBaqarah({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (_memoryCache != null) return _memoryCache!;

      final cached = _readPrefsCache();
      if (cached != null) {
        _memoryCache = cached;
        return cached;
      }
    }

    final fetched = await _apiClient.fetchBaqarah();
    if (fetched.length != expectedAyahCount) {
      throw const QuranTextUnavailableException(
        'Incomplete Quran text received from network',
      );
    }
    _memoryCache = fetched;
    await _writePrefsCache(fetched);
    return fetched;
  }

  List<Ayah>? _readPrefsCache() {
    final raw = _prefs.getString(cacheKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Cached Quran text is not a JSON array');
      }
      final ayahs = <Ayah>[];
      for (final entry in decoded) {
        if (entry is! Map) {
          throw const FormatException('Cached Quran ayah entry is not a map');
        }
        final n = entry['n'];
        final text = entry['text'];
        if (n is! num || text is! String || text.trim().isEmpty) {
          throw const FormatException('Cached Quran ayah entry is malformed');
        }
        ayahs.add(Ayah(n: n.toInt(), text: text));
      }
      if (ayahs.length != expectedAyahCount) {
        throw const FormatException('Cached Quran text has the wrong length');
      }
      return ayahs;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Corrupt Quran text cache ($cacheKey) — clearing and refetching',
        error,
        stackTrace,
      );
      unawaited(_prefs.remove(cacheKey));
      return null;
    }
  }

  Future<void> _writePrefsCache(List<Ayah> ayahs) async {
    final encoded = jsonEncode(
      ayahs.map((a) => {'n': a.n, 'text': a.text}).toList(),
    );
    await _prefs.setString(cacheKey, encoded);
  }
}
