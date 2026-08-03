import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/quran/data/sources/quran_api_client.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';

void main() {
  group('QuranApiClient.stripBasmala', () {
    test('strips the diacritic-form basmala from the start of ayah 1', () {
      const text = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الم';
      expect(QuranApiClient.stripBasmala(text), 'الم');
    });

    test('strips the Uthmani small-letter basmala variant', () {
      const text = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِیمِ الم';
      expect(QuranApiClient.stripBasmala(text), 'الم');
    });

    test('leaves text with no leading basmala untouched (only trimmed)', () {
      const text = '  ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ  ';
      expect(
        QuranApiClient.stripBasmala(text),
        'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ',
      );
    });
  });

  group('QuranApiClient.parseAlquranCloud', () {
    test('normalizes ayahs and strips basmala only from ayah 1', () {
      final json = <String, dynamic>{
        'code': 200,
        'status': 'OK',
        'data': {
          'number': 2,
          'name': 'سورة البقرة',
          'ayahs': [
            {
              'number': 8,
              'text': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الم',
              'numberInSurah': 1,
            },
            {
              'number': 9,
              'text': ' ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى ',
              'numberInSurah': 2,
            },
          ],
        },
      };

      final result = QuranApiClient.parseAlquranCloud(json);

      expect(result, isNotNull);
      expect(result, hasLength(2));
      expect(result![0], const Ayah(n: 1, text: 'الم'));
      expect(
        result[1],
        const Ayah(n: 2, text: 'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى'),
      );
    });

    test('returns null when the "data" key is missing', () {
      expect(QuranApiClient.parseAlquranCloud({'foo': 'bar'}), isNull);
    });

    test('returns null when "data.ayahs" is missing', () {
      expect(
        QuranApiClient.parseAlquranCloud({
          'data': {'number': 2},
        }),
        isNull,
      );
    });

    test('returns null when an ayah entry is malformed', () {
      final json = <String, dynamic>{
        'data': {
          'ayahs': [
            {'numberInSurah': 1}, // missing text
          ],
        },
      };
      expect(QuranApiClient.parseAlquranCloud(json), isNull);
    });
  });

  group('QuranApiClient.parseQuranCom', () {
    test('parses verse_key surah:ayah and strips basmala from ayah 1', () {
      final json = <String, dynamic>{
        'verses': [
          {
            'id': 1,
            'verse_key': '2:1',
            'text_uthmani': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الم',
          },
          {'id': 2, 'verse_key': '2:2', 'text_uthmani': ' ذَٰلِكَ الْكِتَابُ '},
        ],
      };

      final result = QuranApiClient.parseQuranCom(json);

      expect(result, isNotNull);
      expect(result, hasLength(2));
      expect(result![0], const Ayah(n: 1, text: 'الم'));
      expect(result[1], const Ayah(n: 2, text: 'ذَٰلِكَ الْكِتَابُ'));
    });

    test('returns null when "verses" is missing', () {
      expect(QuranApiClient.parseQuranCom({'foo': 'bar'}), isNull);
    });

    test('returns null when verse_key has an unexpected shape', () {
      final json = <String, dynamic>{
        'verses': [
          {'verse_key': 'not-a-key', 'text_uthmani': 'x'},
        ],
      };
      expect(QuranApiClient.parseQuranCom(json), isNull);
    });
  });

  group('QuranApiClient.parseJsDelivr', () {
    test('parses {id,text} pairs and does NOT strip the basmala', () {
      final json = <String, dynamic>{
        'id': 2,
        'name': 'البقرة',
        'verses': [
          {'id': 1, 'text': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الم'},
          {'id': 2, 'text': ' ذَٰلِكَ الْكِتَابُ '},
        ],
      };

      final result = QuranApiClient.parseJsDelivr(json);

      expect(result, isNotNull);
      expect(result, hasLength(2));
      // Legacy jsdelivr fallback trims but never strips the basmala.
      expect(
        result![0],
        const Ayah(n: 1, text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الم'),
      );
      expect(result[1], const Ayah(n: 2, text: 'ذَٰلِكَ الْكِتَابُ'));
    });

    test('returns null when "verses" is missing', () {
      expect(QuranApiClient.parseJsDelivr({'id': 2}), isNull);
    });
  });
}
