import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/audio_playback_state.dart';

/// Bottom player bar for the mushaf reader: play/pause, stop, current ayah,
/// position/duration progress, and a tap target to open reciter selection.
class QuranAudioBar extends StatelessWidget {
  const QuranAudioBar({
    super.key,
    required this.playback,
    required this.reciterName,
    required this.onPlayPause,
    required this.onStop,
    required this.onTapReciter,
  });

  final AudioPlaybackState playback;
  final String reciterName;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onTapReciter;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final duration = playback.duration;
    final position = playback.position;
    // A `null` value would render an indeterminate (perpetually animating)
    // indicator, which never settles in widget tests — default to 0 instead
    // of using an indeterminate progress bar before playback has a duration.
    final progress = (duration == null || duration.inMilliseconds == 0)
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    final statusLabel = playback.isError
        ? (playback.errorMessage ?? 'تعذّر تشغيل الصوت')
        : (playback.currentAyah != null
              ? 'الآية ${playback.currentAyah}'
              : 'لم يبدأ التشغيل بعد');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colors.oliveSoft,
                  color: playback.isError ? colors.danger : colors.olive,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  IconButton(
                    tooltip: playback.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                    iconSize: 36,
                    color: colors.oliveDeep,
                    icon: Icon(
                      playback.isLoading
                          ? Icons.hourglass_bottom_rounded
                          : (playback.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded),
                    ),
                    onPressed: playback.isLoading ? null : onPlayPause,
                  ),
                  IconButton(
                    tooltip: 'إيقاف',
                    color: colors.inkSoft,
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: onStop,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: playback.isError
                                    ? colors.danger
                                    : colors.ink,
                              ),
                        ),
                        if (duration != null)
                          Text(
                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  // Shrinks with an ellipsis on narrow phones instead of
                  // pushing the row off screen with a long reciter name.
                  Flexible(
                    child: TextButton.icon(
                      onPressed: onTapReciter,
                      icon: const Icon(Icons.record_voice_over_outlined),
                      label: Text(
                        reciterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
