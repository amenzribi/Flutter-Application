import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// Pure port of legacy `markPrayer(key)`'s log mutation.
abstract final class PrayerTrackingService {
  /// Toggles [key] within [dayKey]'s record inside [log] and returns a
  /// **new** log map — [log] itself is never mutated.
  ///
  /// A no-op (returns [log] unchanged, by identity) when [key] isn't one of
  /// the five recognized prayer keys, so callers can detect "nothing
  /// changed" with `identical(result, log)` and skip persisting/syncing.
  static Map<String, dynamic> togglePrayer(
    Map<String, dynamic> log,
    String dayKey,
    String key,
  ) {
    if (PrayerName.fromKey(key) == null) return log;

    final nextLog = Map<String, dynamic>.from(log);
    final existing = nextLog[dayKey];
    final record = existing is Map
        ? existing.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final wasCompleted = record[key] == true;
    record[key] = !wasCompleted;
    nextLog[dayKey] = record;
    return nextLog;
  }
}
