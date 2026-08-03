import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/quran/data/catalogs/reciters_catalog.dart';
import 'package:barakah40_flutter/features/quran/data/repositories/cached_quran_text_repository.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/audio_playback_state.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/challenge_progress.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/quran_reading_position.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/reciter.dart';
import 'package:barakah40_flutter/features/quran/domain/repositories/quran_text_repository.dart';
import 'package:barakah40_flutter/features/quran/domain/services/challenge_progress_service.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_controller.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_player.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

/// [QuranTextRepository] backed by [sharedPreferencesProvider] — the same
/// SharedPreferences instance the user-state repository uses, but writing
/// to a separate, device-local key (`baq_cache_v1`), never synced.
final quranTextRepositoryProvider = Provider<QuranTextRepository>((ref) {
  return CachedQuranTextRepository(prefs: ref.watch(sharedPreferencesProvider));
});

/// Loads (and caches) the full 286-ayah Al-Baqarah mushaf.
class BaqarahNotifier extends AsyncNotifier<List<Ayah>> {
  @override
  Future<List<Ayah>> build() {
    return ref.watch(quranTextRepositoryProvider).loadBaqarah();
  }

  /// Forces a fresh network fetch, bypassing memory/on-device caches.
  Future<void> refresh() async {
    state = const AsyncLoading<List<Ayah>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () =>
          ref.read(quranTextRepositoryProvider).loadBaqarah(forceRefresh: true),
    );
  }
}

final baqarahProvider = AsyncNotifierProvider<BaqarahNotifier, List<Ayah>>(
  BaqarahNotifier.new,
);

/// Current reciter (`RECITERS.find(r=>r.id===S.reciter)||RECITERS[0]`).
final currentReciterProvider = Provider<Reciter>((ref) {
  final reciterId = ref.watch(userAppStateProvider).reciter;
  return RecitersCatalog.byId(reciterId);
});

/// 40-day challenge overview read-model, derived from [UserAppState] plus
/// the current reading position — never from an invented day/ayah mapping.
final challengeProgressProvider = Provider<ChallengeProgress>((ref) {
  final appState = ref.watch(userAppStateProvider);
  final position = QuranReadingPosition(
    lastAyah: appState.lastAyah,
    audioPos: appState.audioPos,
  );
  return ChallengeProgressService.buildProgress(
    appState,
    surahEffectiveAyah: position.effectiveAyah,
  );
});

/// Long-lived audio controller for the reader screen; persists
/// `S.audioPos` through [UserStateController.setAudioPos].
final quranAudioControllerProvider =
    StateNotifierProvider<QuranAudioController, AudioPlaybackState>((ref) {
      final controller = QuranAudioController(
        player: JustAudioQuranPlayer(),
        reciterId: () => ref.read(userAppStateProvider).reciter,
        onAudioPosChanged: (ayah) =>
            ref.read(userStateControllerProvider.notifier).setAudioPos(ayah),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
