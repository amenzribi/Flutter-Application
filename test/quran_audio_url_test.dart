import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/quran/data/catalogs/reciters_catalog.dart';
import 'package:barakah40_flutter/features/quran/domain/services/quran_audio_url.dart';

void main() {
  group('QuranAudioUrl.buildUrl', () {
    test('pads the ayah number to 3 digits', () {
      expect(
        QuranAudioUrl.buildUrl('Alafasy_128kbps', 1),
        'https://everyayah.com/data/Alafasy_128kbps/002001.mp3',
      );
    });

    test('does not pad a 3-digit ayah number', () {
      expect(
        QuranAudioUrl.buildUrl('Alafasy_128kbps', 286),
        'https://everyayah.com/data/Alafasy_128kbps/002286.mp3',
      );
    });

    test('pads a 2-digit ayah number', () {
      expect(
        QuranAudioUrl.buildUrl('Alafasy_128kbps', 12),
        'https://everyayah.com/data/Alafasy_128kbps/002012.mp3',
      );
    });

    test('uses the given folder verbatim, not the reciter id', () {
      expect(
        QuranAudioUrl.buildUrl('Abdurrahmaan_As-Sudais_64kbps', 5),
        'https://everyayah.com/data/Abdurrahmaan_As-Sudais_64kbps/002005.mp3',
      );
    });

    test('always prefixes with the Al-Baqarah surah number "002"', () {
      final url = QuranAudioUrl.buildUrl('Ghamadi_40kbps', 200);
      expect(url, contains('/Ghamadi_40kbps/002200.mp3'));
    });
  });

  group('RecitersCatalog', () {
    test('has exactly the 11 legacy reciters', () {
      expect(RecitersCatalog.all, hasLength(11));
    });

    test('default reciter is Alafasy_128kbps (RECITERS[0])', () {
      expect(RecitersCatalog.defaultReciterId, 'Alafasy_128kbps');
      expect(RecitersCatalog.all.first.id, 'Alafasy_128kbps');
    });

    test('byId finds a known reciter', () {
      final reciter = RecitersCatalog.byId('Saood_ash-Shuraym_128kbps');
      expect(reciter.arabicName, 'سعود الشريم');
      expect(reciter.folders, [
        'Saood_ash-Shuraym_128kbps',
        'Saood_ash-Shuraym_64kbps',
      ]);
    });

    test('byId falls back to the first reciter for an unknown/null id', () {
      expect(RecitersCatalog.byId('does-not-exist').id, 'Alafasy_128kbps');
      expect(RecitersCatalog.byId(null).id, 'Alafasy_128kbps');
    });

    test('buildUrl composes correctly with each reciter folder failover', () {
      for (final reciter in RecitersCatalog.all) {
        for (final folder in reciter.folders) {
          final url = QuranAudioUrl.buildUrl(folder, 1);
          expect(url, 'https://everyayah.com/data/$folder/002001.mp3');
        }
      }
    });
  });
}
