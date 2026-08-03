import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// One prayer's row: name, time (or nothing — never an invented time), and
/// a toggle checkbox (legacy `markPrayer` — no confirm dialog).
class PrayerRow extends StatelessWidget {
  const PrayerRow({
    super.key,
    required this.name,
    required this.time,
    required this.completed,
    required this.onToggle,
  });

  final PrayerName name;
  final String? time;
  final bool completed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: completed ? colors.oliveSoft : colors.surfaceMuted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.mosque_outlined, color: colors.oliveDeep),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.arabicLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (time != null)
                  Text(
                    time!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkSoft),
                    textDirection: TextDirection.ltr,
                  ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${name.arabicLabel}${completed ? '، تم التسجيل' : ''}',
            child: Checkbox(
              value: completed,
              onChanged: (_) => onToggle(),
              activeColor: colors.olive,
            ),
          ),
        ],
      ),
    );
  }
}
