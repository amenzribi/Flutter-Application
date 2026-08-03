import 'package:just_audio/just_audio.dart' as ja;

/// Coarse, platform-agnostic mirror of `just_audio`'s `ProcessingState`,
/// so [QuranAudioController] and its tests never import `just_audio`
/// directly.
enum QuranAudioProcessingState { idle, loading, ready, completed }

class QuranAudioPlayerState {
  const QuranAudioPlayerState({
    required this.playing,
    required this.processingState,
  });

  final bool playing;
  final QuranAudioProcessingState processingState;
}

/// Minimal audio-player surface [QuranAudioController] needs. Kept
/// abstract so unit tests exercise the controller with a fake instead of
/// pulling in the `just_audio` platform channel.
abstract class QuranAudioPlayer {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<QuranAudioPlayerState> get playerStateStream;

  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// [QuranAudioPlayer] backed by the real `just_audio` plugin.
class JustAudioQuranPlayer implements QuranAudioPlayer {
  JustAudioQuranPlayer([ja.AudioPlayer? player])
    : _player = player ?? ja.AudioPlayer();

  final ja.AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<QuranAudioPlayerState> get playerStateStream =>
      _player.playerStateStream.map(
        (state) => QuranAudioPlayerState(
          playing: state.playing,
          processingState: _mapProcessingState(state.processingState),
        ),
      );

  static QuranAudioProcessingState _mapProcessingState(
    ja.ProcessingState state,
  ) {
    switch (state) {
      case ja.ProcessingState.idle:
        return QuranAudioProcessingState.idle;
      case ja.ProcessingState.loading:
      case ja.ProcessingState.buffering:
        return QuranAudioProcessingState.loading;
      case ja.ProcessingState.ready:
        return QuranAudioProcessingState.ready;
      case ja.ProcessingState.completed:
        return QuranAudioProcessingState.completed;
    }
  }

  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
