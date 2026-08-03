import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';

/// Single mushaf verse row: surah-local number marker + Uthmani text,
/// with per-row bookmark and play-from-here controls.
class AyahVerseTile extends StatelessWidget {
  const AyahVerseTile({
    super.key,
    required this.ayah,
    required this.qscale,
    required this.isBookmarked,
    required this.isPlaying,
    required this.onToggleBookmark,
    required this.onPlayFrom,
  });

  final Ayah ayah;

  /// Legacy `S.qscale`, clamped 0.8..1.8 by the caller.
  final double qscale;

  final bool isBookmarked;
  final bool isPlaying;
  final VoidCallback onToggleBookmark;
  final VoidCallback onPlayFrom;

  static const double _baseFontSize = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final background = isPlaying
        ? colors.oliveSoft
        : (isBookmarked ? colors.goldSoft : Colors.transparent);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.mdAll,
        border: isPlaying
            ? Border.all(color: colors.olive.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _NumberMarker(number: ayah.n, isPlaying: isPlaying),
              const Spacer(),
              IconButton(
                tooltip: isBookmarked ? 'إزالة العلامة' : 'وصلت هنا',
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isBookmarked ? colors.gold : colors.inkSoft,
                ),
                onPressed: onToggleBookmark,
              ),
              IconButton(
                tooltip: isPlaying ? 'إيقاف الآية' : 'تشغيل من هنا',
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_outline_rounded,
                  color: colors.oliveDeep,
                ),
                onPressed: onPlayFrom,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            ayah.text,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: _baseFontSize * qscale,
              height: 2.35,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberMarker extends StatelessWidget {
  const _NumberMarker({required this.number, required this.isPlaying});

  final int number;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPlaying ? colors.olive : colors.oliveSoft,
        border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isPlaying ? colors.onOlive : colors.oliveDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
