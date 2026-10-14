import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/quran/data/catalogs/reciters_catalog.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/audio_playback_state.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/quran_reading_position.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/reciter.dart';
import 'package:barakah40_flutter/features/quran/domain/services/quran_audio_url.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_player.dart';

/// Drives Al-Baqarah per-ayah audio playback: play/pause/resume/stop,
/// EveryAyah folder failover on error, and auto-advance to the next ayah
/// on completion (legacy `audioEl.onended`).
///
/// Persists `S.audioPos` via [onAudioPosChanged] (wire this to
/// `UserStateController.setAudioPos`) rather than depending on the
/// controller directly, so this stays unit-testable with a fake player.
class QuranAudioController extends StateNotifier<AudioPlaybackState> {
  QuranAudioController({
    required QuranAudioPlayer player,
    required String Function() reciterId,
    required void Function(int? ayah) onAudioPosChanged,
    int totalAyahs = QuranReadingPosition.totalAyahs,
  }) : // Named parameters keep call sites readable (`player: ...`), so
       // initializing formals (which would require underscore-prefixed
       // parameter names) aren't used here.
       // ignore: prefer_initializing_formals
       _player = player,
       // ignore: prefer_initializing_formals
       _reciterId = reciterId,
       // ignore: prefer_initializing_formals
       _onAudioPosChanged = onAudioPosChanged,
       // ignore: prefer_initializing_formals
       _totalAyahs = totalAyahs,
       super(AudioPlaybackState.idleState) {
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      state = state.copyWith(position: position);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted) return;
      state = state.copyWith(
        duration: duration,
        clearDuration: duration == null,
      );
    });
    _playerStateSub = _player.playerStateStream.listen(_handlePlayerState);
  }

  final QuranAudioPlayer _player;
  final String Function() _reciterId;
  final void Function(int? ayah) _onAudioPosChanged;
  final int _totalAyahs;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<QuranAudioPlayerState>? _playerStateSub;

  /// Index into the current reciter's `folders` failover list for the
  /// in-flight load attempt.
  int _folderAttemptIndex = 0;

  /// Bumped on every user-initiated load so a stale async failure/success
  /// from an outdated attempt can't clobber newer state.
  int _loadGeneration = 0;

  /// Starts (or restarts) playback from ayah [ayah] (legacy `playFrom`).
  Future<void> playFrom(int ayah) async {
    if (ayah < 1 || ayah > _totalAyahs) return;
    _folderAttemptIndex = 0;
    final generation = ++_loadGeneration;
    await _loadAndPlay(ayah, generation);
  }

  Future<void> _loadAndPlay(int ayah, int generation) async {
    if (!mounted || generation != _loadGeneration) return;
    final reciter = RecitersCatalog.byId(_reciterId());
    state = state.copyWith(
      status: AudioPlaybackStatus.loading,
      currentAyah: ayah,
      clearErrorMessage: true,
    );
    try {
      final folderIndex = _folderAttemptIndex.clamp(
        0,
        reciter.folders.length - 1,
      );
      final url = QuranAudioUrl.buildUrl(reciter.folders[folderIndex], ayah);
      await _player.setUrl(url);
      if (!mounted || generation != _loadGeneration) return;
      // just_audio's play() completes only when playback stops or pauses, so
      // it must not be awaited: the ayah is playing as soon as it starts.
      unawaited(
        _player.play().catchError((Object _) {
          if (mounted && generation == _loadGeneration) {
            unawaited(_handlePlaybackError(ayah, reciter, generation));
          }
        }),
      );
      state = state.copyWith(status: AudioPlaybackStatus.playing);
      _onAudioPosChanged(ayah);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      await _handlePlaybackError(ayah, reciter, generation);
    }
  }

  Future<void> _handlePlaybackError(
    int ayah,
    Reciter reciter,
    int generation,
  ) async {
    if (_folderAttemptIndex + 1 < reciter.folders.length) {
      _folderAttemptIndex++;
      await _loadAndPlay(ayah, generation);
      return;
    }
    if (!mounted || generation != _loadGeneration) return;
    state = state.copyWith(
      status: AudioPlaybackStatus.error,
      errorMessage: 'تعذّر تشغيل الصوت',
    );
  }

  Future<void> pause() async {
    if (!state.isPlaying) return;
    await _player.pause();
    if (!mounted) return;
    state = state.copyWith(status: AudioPlaybackStatus.paused);
  }

  /// Resumes a paused ayah, or (re)starts the current/last ayah if idle.
  Future<void> resume() async {
    if (state.isPaused) {
      // Not awaited: completes only when playback stops again (see above).
      unawaited(_player.play().catchError((Object _) {}));
      state = state.copyWith(status: AudioPlaybackStatus.playing);
      return;
    }
    final ayah = state.currentAyah;
    if (ayah != null) {
      await playFrom(ayah);
    }
  }

  /// Stops playback and clears the persisted audio position (legacy
  /// `stopPlay`: `S.audioPos=null; save();`).
  Future<void> stop() async {
    _loadGeneration++;
    await _player.stop();
    if (!mounted) return;
    state = AudioPlaybackState.idleState;
    _onAudioPosChanged(null);
  }

  void _handlePlayerState(QuranAudioPlayerState playerState) {
    if (!mounted) return;
    if (playerState.processingState == QuranAudioProcessingState.completed) {
      unawaited(_advanceToNextAyah());
    }
  }

  /// Auto-advance on `ended` (legacy `audioEl.onended`): play the next
  /// ayah, or stop once past the last ayah of the surah.
  Future<void> _advanceToNextAyah() async {
    final ayah = state.currentAyah;
    if (ayah == null) return;
    final next = ayah + 1;
    if (next > _totalAyahs) {
      await stop();
      return;
    }
    _folderAttemptIndex = 0;
    final generation = ++_loadGeneration;
    await _loadAndPlay(next, generation);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }
}
