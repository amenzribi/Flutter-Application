import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/domain/repositories/user_state_local_repository.dart';

/// [SharedPreferences]-backed local store, one JSON blob per uid.
///
/// Key format: `barakah_user_state_v1_<uid>` — versioned like legacy's
/// `barakah_pro_v1` so a future schema break can migrate by key prefix
/// instead of guessing content shape.
class SharedPreferencesUserStateRepository implements UserStateLocalRepository {
  SharedPreferencesUserStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'barakah_user_state_v1_';

  static String keyFor(String uid) => '$_keyPrefix$uid';

  @override
  Future<UserAppState> load(String uid) async {
    final raw = _prefs.getString(keyFor(uid));
    if (raw == null || raw.trim().isEmpty) {
      return UserAppState.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Stored user state is not a JSON object');
      }
      return UserAppState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error, stackTrace) {
      AppLogger.error(
        'Corrupt local user state for uid=$uid — resetting to defaults',
        error,
        stackTrace,
      );
      final fresh = UserAppState.defaults();
      await save(uid, fresh);
      return fresh;
    }
  }

  @override
  Future<void> save(String uid, UserAppState state) async {
    await _prefs.setString(keyFor(uid), jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear(String uid) async {
    await _prefs.remove(keyFor(uid));
  }
}
