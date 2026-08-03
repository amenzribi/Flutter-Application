import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_day_progress.dart';

/// "X / 5 صلوات اليوم" summary bar (legacy `.p-summary`).
class PrayerProgressBar extends StatelessWidget {
  const PrayerProgressBar({super.key, required this.progress});

  final PrayerDayProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final value = progress.completedCount / PrayerDayProgress.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progress.completedCount} / ${PrayerDayProgress.total}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'صلوات اليوم',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.oliveSoft,
            color: colors.olive,
          ),
        ),
      ],
    );
  }
}
