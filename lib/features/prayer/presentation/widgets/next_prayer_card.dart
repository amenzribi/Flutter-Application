import 'dart:async';

import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/next_prayer_service.dart';

/// Next-prayer name/time with a live `HH:MM:SS` countdown, ticking every
/// second while [info] is non-null (legacy `renderNextPrayer`'s
/// `setInterval`). Renders nothing when there's no valid schedule for today.
class NextPrayerCard extends StatefulWidget {
  const NextPrayerCard({super.key, required this.info});

  final NextPrayerInfo? info;

  @override
  State<NextPrayerCard> createState() => _NextPrayerCardState();
}

class _NextPrayerCardState extends State<NextPrayerCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant NextPrayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final needsTicker = widget.info != null;
    if (needsTicker && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else if (!needsTicker && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _formatCountdown(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes % 60)}:'
        '${two(duration.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    if (info == null) return const SizedBox.shrink();

    final colors = context.barakahColors;
    final countdown = _formatCountdown(info.countdownAt(_now));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.oliveDeep,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الوقت المتبقي',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onOlive),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            countdown,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colors.onOlive,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'الصلاة القادمة: ${info.name.arabicLabel} - ${info.time}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onOlive),
          ),
        ],
      ),
    );
  }
}
