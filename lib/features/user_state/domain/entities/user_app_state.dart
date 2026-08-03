import 'package:barakah40_flutter/features/user_state/domain/entities/json_helpers.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/qibla_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/reminder_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/tasbeeh_settings.dart';

/// Immutable model of legacy `S` (localStorage key `barakah_pro_v1`, mirrored
/// to Firestore `users/{uid}.state`).
///
/// Only the fields confirmed present in `defaults`/`freshDefaults()` are
/// modeled explicitly. Every other top-level key ever observed on `S`
/// (`tree`, `stats`, `activity`, `adhan`, `name`, `qfont`, `reduceMotion`,
/// `imgHi`, `season`, `completedAt`, and any future/unknown key) is kept
/// verbatim in [extra] so this app never silently drops data written by the
/// legacy web client or a newer client version. See
/// `docs/migration-analysis/FLUTTER_USER_STATE.md` for the full field audit
/// and the rationale for this split.
class UserAppState {
  const UserAppState({
    required this.completed,
    this.lastAyah,
    this.palette = 'offwhite',
    this.qscale = 1.0,
    this.intention = const {},
    this.journal = const [],
    this.adhkarCount = const {},
    this.reminder = const ReminderSettings(),
    this.started,
    this.seen = false,
    this.guest = false,
    this.reciter = 'Alafasy_128kbps',
    this.audioPos,
    this.prayer = const PrayerSettings(),
    this.qibla = const QiblaSettings(),
    this.tasbeeh = const TasbeehSettings(),
    this.lang = 'ar',
    this.extra = const {},
  });

  /// Challenge length — `Array(40)` in legacy `defaults`.
  static const int challengeDays = 40;

  /// Total ayahs in Surah Al-Baqarah, used to interpret [lastAyah]/[audioPos]
  /// as a reading-progress percentage (legacy `Math.min(n,286)/286`).
  static const int baqarahAyahCount = 286;

  /// `bool[40]`, one flag per challenge day.
  final List<bool> completed;

  /// Last bookmarked ayah number (1..286) in Surah Al-Baqarah, or `null`.
  final int? lastAyah;

  /// UI color palette id, e.g. `'offwhite'`.
  final String palette;

  /// Quran reading font scale, legacy range `0.8..1.8`.
  final double qscale;

  /// Free-form personal intention notes (legacy shape not fully typed).
  final Map<String, dynamic> intention;

  /// Free-form journal entries (legacy shape not fully typed).
  final List<dynamic> journal;

  /// Adhkar tally keyed `'morning_<i>'` / `'evening_<i>'` → count.
  final Map<String, dynamic> adhkarCount;

  final ReminderSettings reminder;

  /// Epoch ms when the 40-day challenge started, or `null`.
  final int? started;

  /// Whether onboarding has been shown.
  final bool seen;

  /// Whether this session is a guest (no Firebase account).
  final bool guest;

  /// Quran reciter id, e.g. `'Alafasy_128kbps'`.
  final String reciter;

  /// Last audio playback ayah position, or `null`.
  final int? audioPos;

  final PrayerSettings prayer;
  final QiblaSettings qibla;
  final TasbeehSettings tasbeeh;

  /// `'ar'` or `'en'`.
  final String lang;

  /// Every top-level key from the source JSON that isn't one of the
  /// confirmed fields above, preserved verbatim for round-tripping.
  final Map<String, dynamic> extra;

  static UserAppState defaults() =>
      UserAppState(completed: List<bool>.filled(challengeDays, false));

  factory UserAppState.fromJson(Map<String, dynamic>? json) {
    final map = Map<String, dynamic>.from(json ?? const {});

    final completed = JsonHelpers.asBoolList(
      map.remove('completed'),
      challengeDays,
      false,
    );
    final lastAyah = JsonHelpers.asIntOrNull(map.remove('lastAyah'));
    final palette = JsonHelpers.asString(map.remove('palette'), 'offwhite');
    final qscale = JsonHelpers.asDouble(map.remove('qscale'), 1.0);
    final intention = JsonHelpers.asMap(map.remove('intention'));
    final journal = JsonHelpers.asList(map.remove('journal'));
    final adhkarCount = JsonHelpers.asMap(map.remove('adhkarCount'));
    final reminder = ReminderSettings.fromJson(
      JsonHelpers.asMap(map.remove('reminder')),
    );
    final started = JsonHelpers.asIntOrNull(map.remove('started'));
    final seen = JsonHelpers.asBool(map.remove('seen'), false);
    final guest = JsonHelpers.asBool(map.remove('guest'), false);
    final reciter = JsonHelpers.asString(
      map.remove('reciter'),
      'Alafasy_128kbps',
    );
    final audioPos = JsonHelpers.asIntOrNull(map.remove('audioPos'));
    final prayer = PrayerSettings.fromJson(
      JsonHelpers.asMap(map.remove('prayer')),
    );
    final qibla = QiblaSettings.fromJson(
      JsonHelpers.asMap(map.remove('qibla')),
    );
    final tasbeeh = TasbeehSettings.fromJson(
      JsonHelpers.asMap(map.remove('tasbeeh')),
    );
    final lang = JsonHelpers.asString(map.remove('lang'), 'ar');

    return UserAppState(
      completed: completed,
      lastAyah: lastAyah,
      palette: palette,
      qscale: qscale,
      intention: intention,
      journal: journal,
      adhkarCount: adhkarCount,
      reminder: reminder,
      started: started,
      seen: seen,
      guest: guest,
      reciter: reciter,
      audioPos: audioPos,
      prayer: prayer,
      qibla: qibla,
      tasbeeh: tasbeeh,
      lang: lang,
      extra: map,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...extra,
      'completed': completed,
      'lastAyah': lastAyah,
      'palette': palette,
      'qscale': qscale,
      'intention': intention,
      'journal': journal,
      'adhkarCount': adhkarCount,
      'reminder': reminder.toJson(),
      'started': started,
      'seen': seen,
      'guest': guest,
      'reciter': reciter,
      'audioPos': audioPos,
      'prayer': prayer.toJson(),
      'qibla': qibla.toJson(),
      'tasbeeh': tasbeeh.toJson(),
      'lang': lang,
    };
  }

  UserAppState copyWith({
    List<bool>? completed,
    int? lastAyah,
    bool clearLastAyah = false,
    String? palette,
    double? qscale,
    Map<String, dynamic>? intention,
    List<dynamic>? journal,
    Map<String, dynamic>? adhkarCount,
    ReminderSettings? reminder,
    int? started,
    bool? seen,
    bool? guest,
    String? reciter,
    int? audioPos,
    bool clearAudioPos = false,
    PrayerSettings? prayer,
    QiblaSettings? qibla,
    TasbeehSettings? tasbeeh,
    String? lang,
    Map<String, dynamic>? extra,
  }) {
    return UserAppState(
      completed: completed ?? this.completed,
      lastAyah: clearLastAyah ? null : (lastAyah ?? this.lastAyah),
      palette: palette ?? this.palette,
      qscale: qscale ?? this.qscale,
      intention: intention ?? this.intention,
      journal: journal ?? this.journal,
      adhkarCount: adhkarCount ?? this.adhkarCount,
      reminder: reminder ?? this.reminder,
      started: started ?? this.started,
      seen: seen ?? this.seen,
      guest: guest ?? this.guest,
      reciter: reciter ?? this.reciter,
      audioPos: clearAudioPos ? null : (audioPos ?? this.audioPos),
      prayer: prayer ?? this.prayer,
      qibla: qibla ?? this.qibla,
      tasbeeh: tasbeeh ?? this.tasbeeh,
      lang: lang ?? this.lang,
      extra: extra ?? this.extra,
    );
  }

  /// Sets or removes a single [extra] key without touching confirmed fields
  /// or any other extra key. Prefer this over passing a whole replacement
  /// [extra] map when only one runtime field (e.g. `tree`) is changing.
  UserAppState copyWithExtra(String key, Object? value) {
    final next = Map<String, dynamic>.from(extra);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(extra: next);
  }

  /// Reads an [extra] entry as a string-keyed map, or `null` if absent/typed
  /// differently. Convenience for consumers like the home dashboard mapper
  /// that read partial/unknown fields such as `tree`.
  Map<String, dynamic>? extraMap(String key) {
    final value = extra[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
