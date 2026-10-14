import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/challenge_day.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/challenge_progress.dart';
import 'package:barakah40_flutter/features/quran/presentation/providers/quran_providers.dart';
import 'package:barakah40_flutter/features/quran/presentation/widgets/challenge_day_grid.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// The 40-day Al-Baqarah challenge overview (Option A, legacy-faithful):
/// the user reads the full surah in the mushaf reader and **manually**
/// marks each day complete here. There is no assigned daily ayah range and
/// no automatic day/ayah mapping anywhere on this screen.
class ChallengeOverviewScreen extends ConsumerWidget {
  const ChallengeOverviewScreen({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleTapDay(
    BuildContext context,
    WidgetRef ref,
    ChallengeDay day,
  ) async {
    final controller = ref.read(userStateControllerProvider.notifier);
    if (day.completed) {
      final confirmed = await _confirm(
        context,
        title: 'التراجع عن اليوم ${day.displayNumber}',
        message: 'هل تريدين التراجع عن إكمال هذا اليوم؟',
        confirmLabel: 'تراجع',
      );
      if (confirmed == true) controller.uncompleteChallengeDay(day.index);
    } else {
      final confirmed = await _confirm(
        context,
        title: 'إكمال اليوم ${day.displayNumber}',
        message:
            'هل انتهيتِ من قراءة اليوم؟ سيُسجَّل اليوم ${day.displayNumber} '
            'كمكتمل.',
        confirmLabel: 'تم، أكملته',
      );
      if (confirmed == true) controller.completeChallengeDay(day.index);
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(challengeProgressProvider);
    final appState = ref.watch(userAppStateProvider);
    final hasReadingPosition =
        appState.lastAyah != null || appState.audioPos != null;

    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: AppAssets.pageChallenge,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () => _goBack(context),
        ),
        title: const Text('تحدّي الأربعين'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          child: PageEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const _ExplanationCard(),
                const SizedBox(height: AppSpacing.md),
                _ProgressCard(progress: progress),
                const SizedBox(height: AppSpacing.md),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'الأيام الأربعون',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ChallengeDayGrid(
                        days: progress.days,
                        onTapDay: (day) => _handleTapDay(context, ref, day),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PremiumButton(
                  label: 'فتح المصحف',
                  icon: Icons.menu_book_rounded,
                  onPressed: () => context.push(AppRoutes.quran),
                ),
                if (hasReadingPosition) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PremiumButton(
                    label: 'متابعة القراءة',
                    variant: PremiumButtonVariant.secondary,
                    icon: Icons.play_arrow_rounded,
                    onPressed: () =>
                        context.push('${AppRoutes.quran}?continue=1'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: colors.oliveDeep),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'كيف يعمل التحدّي؟',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'اقرئي سورة البقرة كاملةً في المصحف بحسب وتيرتك الخاصة، ثم '
            'علّمي كل يوم تُتمّينه بنفسك من الشبكة أدناه. لا يوجد تقسيم '
            'تلقائي للآيات على الأيام — أنتِ من تُحدّد متى تنتهي قراءتك '
            'اليومية وتُثبّتينها هنا يدوياً.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final ChallengeProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final started = progress.started != null;

    if (!started) {
      return PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.spa_outlined, color: colors.gold, size: 28),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'لم يبدأ تحدّيك بعد',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'افتحي المصحف وابدئي بالقراءة، وحين تنتهين من أول يوم '
              'علّميه في الشبكة أدناه ليبدأ عدّاد تقدّمك.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.inkSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final value = progress.dayPercent / 100;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${progress.completedDays} من ${progress.goalDays} يوماً مكتملة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!progress.isComplete) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'اليوم الحالي: ${progress.currentIndex + 1}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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
          if (progress.surahPercent != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'نسبة القراءة في المصحف: ${progress.surahPercent!.round()}٪',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}
