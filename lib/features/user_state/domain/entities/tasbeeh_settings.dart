import 'package:barakah40_flutter/features/user_state/domain/entities/json_helpers.dart';

/// Mirrors legacy `S.tasbeeh` = `{count, target}`.
class TasbeehSettings {
  const TasbeehSettings({
    this.count = 0,
    this.target = 0,
    this.extra = const {},
  });

  final int count;
  final int target;
  final Map<String, dynamic> extra;

  factory TasbeehSettings.fromJson(Map<String, dynamic>? json) {
    final map = Map<String, dynamic>.from(json ?? const {});
    final count = JsonHelpers.asInt(map.remove('count'), 0);
    final target = JsonHelpers.asInt(map.remove('target'), 0);
    return TasbeehSettings(count: count, target: target, extra: map);
  }

  Map<String, dynamic> toJson() => {...extra, 'count': count, 'target': target};

  TasbeehSettings copyWith({
    int? count,
    int? target,
    Map<String, dynamic>? extra,
  }) {
    return TasbeehSettings(
      count: count ?? this.count,
      target: target ?? this.target,
      extra: extra ?? this.extra,
    );
  }
}
