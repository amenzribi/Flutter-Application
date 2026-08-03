/// Coarse playback status for the Quran audio player.
enum AudioPlaybackStatus { idle, loading, playing, paused, error }

/// Immutable snapshot of [QuranAudioController]'s player state.
class AudioPlaybackState {
  const AudioPlaybackState({
    this.status = AudioPlaybackStatus.idle,
    this.currentAyah,
    this.position = Duration.zero,
    this.duration,
    this.errorMessage,
  });

  static const AudioPlaybackState idleState = AudioPlaybackState();

  final AudioPlaybackStatus status;

  /// Surah-local ayah currently loaded/playing, or `null` when idle.
  final int? currentAyah;

  final Duration position;

  final Duration? duration;

  /// Set only when [status] is [AudioPlaybackStatus.error].
  final String? errorMessage;

  bool get isPlaying => status == AudioPlaybackStatus.playing;
  bool get isPaused => status == AudioPlaybackStatus.paused;
  bool get isLoading => status == AudioPlaybackStatus.loading;
  bool get isError => status == AudioPlaybackStatus.error;

  AudioPlaybackState copyWith({
    AudioPlaybackStatus? status,
    int? currentAyah,
    bool clearCurrentAyah = false,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AudioPlaybackState(
      status: status ?? this.status,
      currentAyah: clearCurrentAyah ? null : (currentAyah ?? this.currentAyah),
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
