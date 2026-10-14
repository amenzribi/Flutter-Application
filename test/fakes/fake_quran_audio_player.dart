import 'dart:async';

import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_player.dart';

/// In-memory [QuranAudioPlayer] for [QuranAudioController] unit tests — no
/// `just_audio` platform channel required.
///
/// [setUrl] consults [failingUrls] to simulate a folder 404, and playback
/// completion is simulated explicitly via [completeCurrent] rather than a
/// real timer, so tests stay deterministic.
class FakeQuranAudioPlayer implements QuranAudioPlayer {
  final List<String> setUrlCalls = [];
  final List<String> playCalls = [];
  final List<String> pauseCalls = [];
  final List<String> stopCalls = [];

  /// URLs that should make [setUrl] throw, simulating a broken EveryAyah
  /// folder mirror.
  final Set<String> failingUrls = {};

  String? currentUrl;
  bool disposed = false;

  /// Like just_audio, [play] completes only when playback pauses, stops or
  /// reaches the end — never right away.
  Completer<void>? _playback;

  void _endPlayback() {
    final p = _playback;
    _playback = null;
    if (p != null && !p.isCompleted) p.complete();
  }

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<QuranAudioPlayerState> _playerStateController =
      StreamController<QuranAudioPlayerState>.broadcast();

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<QuranAudioPlayerState> get playerStateStream =>
      _playerStateController.stream;

  @override
  Future<void> setUrl(String url) async {
    setUrlCalls.add(url);
    if (failingUrls.contains(url)) {
      throw Exception('Simulated 404 for $url');
    }
    currentUrl = url;
  }

  @override
  Future<void> play() {
    playCalls.add(currentUrl ?? '');
    _playerStateController.add(
      const QuranAudioPlayerState(
        playing: true,
        processingState: QuranAudioProcessingState.ready,
      ),
    );
    _playback ??= Completer<void>();
    return _playback!.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls.add(currentUrl ?? '');
    _endPlayback();
    _playerStateController.add(
      const QuranAudioPlayerState(
        playing: false,
        processingState: QuranAudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCalls.add(currentUrl ?? '');
    _endPlayback();
    _playerStateController.add(
      const QuranAudioPlayerState(
        playing: false,
        processingState: QuranAudioProcessingState.idle,
      ),
    );
  }

  /// Test helper — simulates `audioEl.onended` for the currently loaded url.
  void completeCurrent() {
    _endPlayback();
    _playerStateController.add(
      const QuranAudioPlayerState(
        playing: false,
        processingState: QuranAudioProcessingState.completed,
      ),
    );
  }

  void emitPosition(Duration position) => _positionController.add(position);

  void emitDuration(Duration? duration) => _durationController.add(duration);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _positionController.close();
    await _durationController.close();
    await _playerStateController.close();
  }
}
