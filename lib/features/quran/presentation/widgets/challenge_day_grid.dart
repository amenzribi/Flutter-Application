import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/challenge_day.dart';

/// The 40-day challenge grid: completed / current / upcoming styling.
///
/// Option A (legacy-faithful): every cell is a plain completion flag —
/// tapping it never implies or reveals an ayah range for that day.
class ChallengeDayGrid extends StatelessWidget {
  const ChallengeDayGrid({
    super.key,
    required this.days,
    required this.onTapDay,
  });

  final List<ChallengeDay> days;
  final ValueChanged<ChallengeDay> onTapDay;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 1,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return _DayCell(day: day, onTap: () => onTapDay(day));
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.onTap});

  final ChallengeDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;

    late final Color background;
    late final Color foreground;
    late final Color border;
    Widget? overlayIcon;

    if (day.completed) {
      background = colors.olive;
      foreground = colors.onOlive;
      border = colors.olive;
      overlayIcon = Icon(
        Icons.check_rounded,
        size: 14,
        color: colors.onOlive.withValues(alpha: 0.9),
      );
    } else if (day.isCurrent) {
      background = colors.goldSoft;
      foreground = colors.ink;
      border = colors.gold;
    } else {
      background = colors.surfaceMuted;
      foreground = colors.muted;
      border = colors.line;
    }

    final semanticState = day.completed
        ? 'مكتمل'
        : (day.isCurrent ? 'اليوم الحالي' : 'لم يبدأ بعد');

    return Semantics(
      button: true,
      label: 'اليوم ${day.displayNumber}، $semanticState',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(),
          borderRadius: AppRadii.smAll,
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadii.smAll,
              border: Border.all(color: border, width: day.isCurrent ? 1.6 : 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${day.displayNumber}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (overlayIcon != null)
                  Positioned(top: 3, right: 3, child: overlayIcon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
