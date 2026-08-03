import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/app/shell/app_shell.dart';
import 'package:barakah40_flutter/app/theme/app_motion.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/home/presentation/widgets/home_hero_header.dart';
import 'package:barakah40_flutter/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:barakah40_flutter/features/home/presentation/widgets/home_section_card.dart';
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
      child: asyncModel.when(
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
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StreakCard(progress: progress),
                    const SizedBox(height: AppSpacing.md),
                    _ChallengeCard(
                      progress: progress,
                      onTap: () => _showComingSoon(context, 'تحدّي الأربعين'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _QuranCard(
                      progress: progress,
                      onTap: () => _showComingSoon(context, 'القرآن'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReadingCard(progress: progress),
                    const SizedBox(height: AppSpacing.md),
                    _PrayerCard(
                      progress: progress,
                      onTap: () => _showComingSoon(context, 'الصلاة'),
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
      title: 'تحدّي اليوم',
      icon: Icons.flag_outlined,
      heroTag: 'home-challenge-card',
      onTap: onTap,
      isEmpty: !progress.hasChallenge,
      emptyMessage:
          'لم يبدأ تحدّي الأربعين بعد. سيظهر يومك الحالي هنا عند التفعيل.',
      child: progress.hasChallenge
          ? Text(
              'اليوم ${progress.challengeDay} من ${progress.challengeGoalDays}',
              style: Theme.of(context).textTheme.titleLarge,
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
                  '${progress.quranPercent!.round()}٪',
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
              ],
            )
          : null,
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.progress});
  final HomeProgress progress;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: 'آخر قراءة',
      icon: Icons.bookmark_border_rounded,
      isEmpty: !progress.hasLastReading,
      emptyMessage: 'عند استئناف التلاوة ستُحفظ آخر آية هنا.',
      child: progress.hasLastReading
          ? Text(
              progress.lastReadingLabel!,
              style: Theme.of(context).textTheme.titleLarge,
            )
          : null,
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.progress, required this.onTap});
  final HomeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: 'ملخّص الصلاة',
      icon: Icons.mosque_outlined,
      onTap: onTap,
      isEmpty: !progress.hasPrayerSummary,
      emptyMessage: 'لم يُسجَّل أداء صلوات اليوم بعد.',
      child: progress.hasPrayerSummary
          ? Text(
              '${progress.prayerCompletedToday} من ${progress.prayerTotalToday}',
              style: Theme.of(context).textTheme.headlineSmall,
            )
          : null,
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
