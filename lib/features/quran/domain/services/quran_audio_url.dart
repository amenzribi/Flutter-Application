/// Builds EveryAyah per-ayah MP3 URLs.
///
/// Legacy: `'https://everyayah.com/data/'+reciter().id+'/002'+String(n).padStart(3,'0')+'.mp3'`.
/// `folder` is a candidate from `Reciter.folders` (failover), not always
/// `reciter.id`.
abstract final class QuranAudioUrl {
  static const String baseUrl = 'https://everyayah.com/data';

  /// Surah number for Al-Baqarah, zero-padded to 3 digits in the URL (`002`).
  static const String _surahPrefix = '002';

  static String buildUrl(String folder, int ayah) {
    final padded = ayah.toString().padLeft(3, '0');
    return '$baseUrl/$folder/$_surahPrefix$padded.mp3';
  }
}
