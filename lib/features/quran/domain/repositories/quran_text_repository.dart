import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';

/// Loads the full 286-ayah Al-Baqarah mushaf text.
///
/// Implementations own the memory/on-device-cache/network fallback chain;
/// callers only ever see either a complete, verified 286-ayah list or a
/// thrown error — never a partial/placeholder surah.
abstract class QuranTextRepository {
  /// Returns all 286 Al-Baqarah ayahs.
  ///
  /// When [forceRefresh] is `true`, bypasses memory/on-device caches and
  /// re-fetches from network, refreshing the cache on success.
  ///
  /// Throws when no source (cache or network) yields a complete, valid
  /// 286-ayah list.
  Future<List<Ayah>> loadBaqarah({bool forceRefresh = false});
}
