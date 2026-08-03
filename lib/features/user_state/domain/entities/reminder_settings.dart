import 'package:barakah40_flutter/features/user_state/domain/entities/json_helpers.dart';

/// Mirrors legacy `S.reminder` = `{enabled, morning, evening, baqarah, prayer}`.
///
/// Legacy always deep-fills this nested object on load
/// (`S.reminder = Object.assign(freshDefaults().reminder, S.reminder || {})`),
/// so [fromJson] does the same per-field instead of replacing the whole
/// object when partially present.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.morning = '06:30',
    this.evening = '18:30',
    this.baqarah = '20:00',
    this.prayer = true,
    this.extra = const {},
  });

  final bool enabled;
  final String morning;
  final String evening;
  final String baqarah;
  final bool prayer;

  /// Unknown sibling keys (e.g. legacy `motivate`) preserved for round-trip.
  final Map<String, dynamic> extra;

  factory ReminderSettings.fromJson(Map<String, dynamic>? json) {
    final map = Map<String, dynamic>.from(json ?? const {});
    final enabled = JsonHelpers.asBool(map.remove('enabled'), false);
    final morning = JsonHelpers.asString(map.remove('morning'), '06:30');
    final evening = JsonHelpers.asString(map.remove('evening'), '18:30');
    final baqarah = JsonHelpers.asString(map.remove('baqarah'), '20:00');
    final prayer = JsonHelpers.asBool(map.remove('prayer'), true);
    return ReminderSettings(
      enabled: enabled,
      morning: morning,
      evening: evening,
      baqarah: baqarah,
      prayer: prayer,
      extra: map,
    );
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'enabled': enabled,
    'morning': morning,
    'evening': evening,
    'baqarah': baqarah,
    'prayer': prayer,
  };

  ReminderSettings copyWith({
    bool? enabled,
    String? morning,
    String? evening,
    String? baqarah,
    bool? prayer,
    Map<String, dynamic>? extra,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      morning: morning ?? this.morning,
      evening: evening ?? this.evening,
      baqarah: baqarah ?? this.baqarah,
      prayer: prayer ?? this.prayer,
      extra: extra ?? this.extra,
    );
  }
}
