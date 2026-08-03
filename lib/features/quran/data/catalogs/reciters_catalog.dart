import 'package:barakah40_flutter/features/quran/domain/entities/reciter.dart';

/// The 11 legacy `RECITERS` entries, verbatim (ids, Arabic names, and
/// folder failover lists) from `web/index.html`.
abstract final class RecitersCatalog {
  static const String defaultReciterId = 'Alafasy_128kbps';

  static const List<Reciter> all = [
    Reciter(
      id: 'Alafasy_128kbps',
      arabicName: 'مشاري راشد العفاسي',
      folders: ['Alafasy_128kbps'],
    ),
    Reciter(
      id: 'Salaah_AbdulRahman_Bukhatir_128kbps',
      arabicName: 'صلاح بو خاطر',
      folders: ['Salaah_AbdulRahman_Bukhatir_128kbps'],
    ),
    Reciter(
      id: 'Fares_Abbad_64kbps',
      arabicName: 'فارس عبّاد',
      folders: ['Fares_Abbad_64kbps'],
    ),
    Reciter(
      id: 'Abdurrahmaan_As-Sudais_192kbps',
      arabicName: 'عبد الرحمن السديس',
      folders: [
        'Abdurrahmaan_As-Sudais_192kbps',
        'Abdurrahmaan_As-Sudais_64kbps',
      ],
    ),
    Reciter(
      id: 'Ghamadi_40kbps',
      arabicName: 'سعد الغامدي',
      folders: ['Ghamadi_40kbps'],
    ),
    Reciter(
      id: 'Maher_AlMuaiqly_64kbps',
      arabicName: 'ماهر المعيقلي',
      folders: ['Maher_AlMuaiqly_64kbps', 'MaherAlMuaiqly128kbps'],
    ),
    Reciter(
      id: 'Yasser_Ad-Dussary_128kbps',
      arabicName: 'ياسر الدوسري',
      folders: ['Yasser_Ad-Dussary_128kbps'],
    ),
    Reciter(
      id: 'Ahmed_ibn_Ali_al-Ajamy_128kbps',
      arabicName: 'أحمد العجمي',
      folders: [
        'Ahmed_ibn_Ali_al-Ajamy_128kbps',
        'ahmed_ibn_ali_al_ajamy_128kbps',
        'Ahmed_ibn_Ali_al-Ajamy_64kbps',
      ],
    ),
    Reciter(
      id: 'Nasser_Alqatami_128kbps',
      arabicName: 'ناصر القطامي',
      folders: ['Nasser_Alqatami_128kbps'],
    ),
    Reciter(
      id: 'Saood_ash-Shuraym_128kbps',
      arabicName: 'سعود الشريم',
      folders: ['Saood_ash-Shuraym_128kbps', 'Saood_ash-Shuraym_64kbps'],
    ),
    Reciter(
      id: 'Ali_Jaber_64kbps',
      arabicName: 'علي جابر',
      folders: ['Ali_Jaber_64kbps'],
    ),
  ];

  /// `reciter()` — looks up by `S.reciter` id, falling back to
  /// [defaultReciterId]'s entry (`RECITERS[0]`) when unknown.
  static Reciter byId(String? id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}
