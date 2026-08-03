import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/shell/app_shell.dart';
import 'package:barakah40_flutter/app/theme/app_motion.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/home/presentation/widgets/home_hero_header.dart';
import 'package:barakah40_flutter/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:barakah40_flutter/features/home/presentation/widgets/home_section_card.dart';
import 'package:barakah40_flutter/features/user_state/presentation/widgets/user_state_diagnostics_panel.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Premium Home Dashboard — real clock/profile + empty local progress states.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncModel = ref.watch(homeDashboardProvider);

    return AppShell(
      child: Stack(
        children: [
          asyncModel.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'تعذّر تحميل لوحة المتابعة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            data: (model) => _HomeBody(model: model),
          ),
          // Debug-only sync/state inspector — never present in release
          // builds. Overlaid rather than wired into PremiumScaffold/AppShell
          // to avoid touching their layout contracts.
          if (kDebugMode)
            const Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: UserStateDiagnosticsFab(),
            ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.model});

  final HomeDashboardViewModel model;

  void _showComingSoon(BuildContext context, String feature) {
    final colors = context.barakahColors;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«$feature» قريباً — لم تبدأ هجرة هذه الميزة بعد.'),
        backgroundColor: colors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = model.progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: () async {
            // Local store has no remote pull yet; keep gesture for future sync.
            await Future<void>.delayed(AppMotion.fast);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            child: ResponsiveContent(
              child: PageEntrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    HomeHeroHeader(model: model),
                    const SizedBox(height: AppSpacing.md),
                    HomeQuickActions(
                      onUnavailable: (label) => _showComingSoon(context, label),
                      onQuran: () => context.push(AppRoutes.quran),
                      onPrayer: () => context.push(AppRoutes.prayer),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StreakCard(progress: progress),
                    const SizedBox(height: AppSpacing.md),
                    _ChallengeCard(
                      progress: progress,
                      onTap: () => context.push(AppRoutes.challenge),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _QuranCard(
                      progress: progress,
                      onTap: () => context.push(AppRoutes.quran),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReadingCard(
                      progress: progress,
                      onContinue: () =>
                          context.push('${AppRoutes.quran}?continue=1'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PrayerCard(
                      progress: progress,
                      onTap: () => context.push(AppRoutes.prayer),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AdhkarCard(
                      progress: progress,
                      onTap: () => _showComingSoon(context, 'الأذكار'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TreeCard(
                      progress: progress,
                      onTap: () => _showComingSoon(context, 'الحديقة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.progress});
  final HomeProgress progress;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: 'سلسلة المواظبة',
      icon: Icons.local_fire_department_outlined,
      isEmpty: !progress.hasStreak,
      emptyMessage: 'ابدئي يوماً واحداً من التلاوة أو الذكر لتظهر سلسلتك هنا.',
      child: progress.hasStreak
          ? Text(
              '${progress.streakDays} يوم متواصل',
              style: Theme.of(context).textTheme.headlineSmall,
            )
          : null,
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.progress, required this.onTap});
  final HomeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: 'تحدّي الأربعين',
      icon: Icons.flag_outlined,
      heroTag: 'home-challenge-card',
      onTap: onTap,
      isEmpty: !progress.hasChallenge,
      emptyMessage:
          'لم يبدأ تحدّي الأربعين بعد. افتحي المصحف وابدئي القراءة، ثم '
          'علّمي كل يوم تُتمّينه بنفسك.',
      child: progress.hasChallenge
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${progress.completedChallengeDays} من '
                  '${progress.challengeGoalDays} يوماً مكتملة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (progress.currentChallengeDay != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'اليوم الحالي: ${progress.currentChallengeDay}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            )
          : null,
    );
  }
}

class _QuranCard extends StatelessWidget {
  const _QuranCard({required this.progress, required this.onTap});
  final HomeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final value = ((progress.quranPercent ?? 0) / 100).clamp(0.0, 1.0);

    return HomeSectionCard(
      title: 'تقدّم القرآن',
      icon: Icons.menu_book_rounded,
      heroTag: 'home-quran-card',
      onTap: onTap,
      isEmpty: !progress.hasQuranProgress,
      emptyMessage: 'لا يوجد تقدّم قرآني محفوظ بعد على هذا الجهاز.',
      child: progress.hasQuranProgress
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${progress.quranPercent!.round()}٪ من سورة البقرة',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: colors.oliveSoft,
                    color: colors.olive,
                  ),
                ),
                if (progress.hasLastReading) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    progress.lastReadingLabel!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            )
          : null,
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.progress, required this.onContinue});
  final HomeProgress progress;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: 'آخر قراءة',
      icon: Icons.bookmark_border_rounded,
      isEmpty: !progress.hasLastReading,
      emptyMessage: 'عند استئناف التلاوة ستُحفظ آخر آية هنا.',
      child: progress.hasLastReading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  progress.lastReadingLabel!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                PremiumButton(
                  label: 'متابعة القراءة',
                  icon: Icons.play_arrow_rounded,
                  expand: false,
                  variant: PremiumButtonVariant.secondary,
                  onPressed: onContinue,
                ),
              ],
            )
          : null,
    );
  }
}

/// Next prayer + live countdown when a schedule is known; falls back to a
/// plain "X من 5" completion count when only the log (no schedule) is
/// present; empty state when there's neither.
class _PrayerCard extends StatefulWidget {
  const _PrayerCard({required this.progress, required this.onTap});
  final HomeProgress progress;
  final VoidCallback onTap;

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _PrayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final needsTicker = widget.progress.nextPrayerAt != null;
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
    final clamped = duration.isNegative ? Duration.zero : duration;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(clamped.inHours)}:${two(clamped.inMinutes % 60)}:'
        '${two(clamped.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final hasAny = progress.hasNextPrayer || progress.hasPrayerSummary;

    Widget? child;
    if (progress.hasNextPrayer) {
      final at = progress.nextPrayerAt;
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${progress.nextPrayerName} — ${progress.nextPrayerTime}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (at != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _formatCountdown(at.difference(_now)),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
          if (progress.hasPrayerSummary) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${progress.prayerCompletedToday} من '
              '${progress.prayerTotalToday} اليوم',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      );
    } else if (progress.hasPrayerSummary) {
      child = Text(
        '${progress.prayerCompletedToday} من ${progress.prayerTotalToday}',
        style: Theme.of(context).textTheme.headlineSmall,
      );
    }

    return HomeSectionCard(
      title: 'ملخّص الصلاة',
      icon: Icons.mosque_outlined,
      onTap: widget.onTap,
      isEmpty: !hasAny,
      emptyMessage: 'لم يُسجَّل أداء صلوات اليوم بعد.',
      child: child,
    );
  }
}

class _AdhkarCard extends StatelessWidget {
  const _AdhkarCard({required this.progress, required this.onTap});
  final HomeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final morning = progress.adhkarMorningDone == true ? 'تم' : '—';
    final evening = progress.adhkarEveningDone == true ? 'تم' : '—';

    return HomeSectionCard(
      title: 'الأذكار',
      icon: Icons.auto_awesome_outlined,
      onTap: onTap,
      isEmpty: !progress.hasAdhkar,
      emptyMessage: 'أذكار الصباح والمساء ستظهر حالتها هنا بعد التفعيل.',
      child: progress.hasAdhkar
          ? Text(
              'صباح: $morning  ·  مساء: $evening',
              style: Theme.of(context).textTheme.titleMedium,
            )
          : null,
    );
  }
}

class _TreeCard extends StatelessWidget {
  const _TreeCard({required this.progress, required this.onTap});
  final HomeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: 'شجرة البركة',
      icon: Icons.park_outlined,
      heroTag: 'home-tree-card',
      variant: PremiumCardVariant.elevated,
      onTap: onTap,
      isEmpty: !progress.hasTree,
      emptyMessage:
          'حديقتك لم تُزرع بعد. ستظهر معاينة الشجرة الحيّة هنا عند البدء.',
      child: progress.hasTree
          ? Text(
              progress.treeStageLabel!,
              style: Theme.of(context).textTheme.titleLarge,
            )
          : null,
    );
  }
}
