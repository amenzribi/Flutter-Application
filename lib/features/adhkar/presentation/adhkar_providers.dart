import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/core/utils/arabic_numbers.dart';
import 'package:barakah40_flutter/features/adhkar/domain/adhkar_models.dart';
import 'package:barakah40_flutter/features/quran/data/sources/quran_api_client.dart';
import 'package:barakah40_flutter/features/quran/presentation/providers/quran_providers.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

/// Reads a bundled UTF-8 text asset directly (rootBundle.loadString decodes
/// large files on a background isolate, which buys nothing here).
Future<String> _asset(String path) async =>
    utf8.decode((await rootBundle.load(path)).buffer.asUint8List());

final adhkarCatalogProvider = FutureProvider<AdhkarCatalog>((ref) async {
  final raw = await _asset('assets/data/adhkar.json');
  return AdhkarCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

final duasProvider = FutureProvider<List<Dua>>((ref) async {
  final raw = await _asset('assets/data/duas.json');
  return [
    for (final e in jsonDecode(raw) as List)
      Dua.fromJson(Map<String, dynamic>.from(e as Map)),
  ];
});

/// Text of the Quranic adhkar (legacy `ensureAdhQuran`): Ayat al-Kursi from
/// the cached Al-Baqarah text, and Al-Ikhlas + Al-Falaq + An-Nas joined with
/// ayah numbers. Cached on the device under the legacy key `qadh_cache_v1`.
final adhkarQuranTextsProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  const cacheKey = 'qadh_cache_v1';
  final prefs = ref.watch(sharedPreferencesProvider);
  final cached = prefs.getString(cacheKey);
  if (cached != null) {
    try {
      final map = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      final kursi = map['kursi'];
      final muawidhat = map['muawidhat'];
      if (kursi is String &&
          kursi.isNotEmpty &&
          muawidhat is String &&
          muawidhat.isNotEmpty) {
        return {'kursi': kursi, 'muawidhat': muawidhat};
      }
    } catch (_) {
      // Rebuild below.
    }
  }

  final baqarah = await ref.watch(baqarahProvider.future);
  final kursi = baqarah.where((a) => a.n == 255).firstOrNull?.text ?? '';
  final client = QuranApiClient();
  try {
    final surahs = await Future.wait([
      client.fetchSurah(112),
      client.fetchSurah(113),
      client.fetchSurah(114),
    ]);
    String join(List<dynamic> ayahs) =>
        ayahs.map((a) => '${a.text} ﴿${arabicDigits(a.n)}﴾').join(' ');
    final muawidhat = surahs.map(join).join('  ۝  ');
    final texts = {'kursi': kursi, 'muawidhat': muawidhat};
    if (kursi.isNotEmpty) await prefs.setString(cacheKey, jsonEncode(texts));
    return texts;
  } finally {
    client.close();
  }
});
