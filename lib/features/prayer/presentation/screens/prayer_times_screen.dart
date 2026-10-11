import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/home/domain/services/hijri_date.dart';
import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_day_progress.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_sync_state.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/next_prayer_service.dart';
import 'package:barakah40_flutter/features/prayer/presentation/controllers/prayer_schedule_controller.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/prayer/presentation/screens/prayer_city_sheet.dart';
import 'package:barakah40_flutter/features/prayer/presentation/widgets/next_prayer_card.dart';
import 'package:barakah40_flutter/features/prayer/presentation/widgets/prayer_progress_bar.dart';
import 'package:barakah40_flutter/features/prayer/presentation/widgets/prayer_row.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Prayer times + five-prayer tracking (Option A, legacy-faithful): Aladhan
/// timings only, method fixed at id 5, manual toggle marking with no
/// confirm dialog, and **never** an invented time. See
/// `docs/migration-analysis/FLUTTER_PRAYER_TIMES.md`.
class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _openCitySheet(BuildContext context, WidgetRef ref) {
    final controller = ref.read(prayerScheduleControllerProvider.notifier);
    final settings = ref.read(userAppStateProvider).prayer;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PrayerCitySheet(
        initialCity: settings.city,
        initialCountry: settings.country,
        onSave: controller.saveCity,
        onUseLocation: controller.locate,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleState = ref.watch(prayerScheduleControllerProvider);
    final appState = ref.watch(userAppStateProvider);
    final dayProgress = ref.watch(prayerDayProgressProvider);
    final streak = ref.watch(prayerStreakProvider);
    final now = DateTime.now();
    final gregorianLabel = DateFormat('EEEE d MMMM y', 'ar').format(now);
    final hijriLabel = HijriDate.fromGregorian(now).formatAr();

    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: AppAssets.pagePrayer,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () => _goBack(context),
        ),
        title: const Text('الصلاة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          child: PageEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                _LocationHeader(
                  city: appState.prayer.city,
                  gregorianLabel: gregorianLabel,
                  hijriLabel: hijriLabel,
                  onTap: () => _openCitySheet(context, ref),
                ),
                const SizedBox(height: AppSpacing.md),
                _ScheduleBody(
                  state: scheduleState,
                  dayProgress: dayProgress,
                  streak: streak,
                  now: now,
                  onRetry: () => ref
                      .read(prayerScheduleControllerProvider.notifier)
                      .refresh(),
                  onLocate: () => ref
                      .read(prayerScheduleControllerProvider.notifier)
                      .locate(),
                  onOpenCity: () => _openCitySheet(context, ref),
                  onTogglePrayer: (name) => ref
                      .read(userStateControllerProvider.notifier)
                      .togglePrayerCompleted(name),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({
    required this.city,
    required this.gregorianLabel,
    required this.hijriLabel,
    required this.onTap,
  });

  final String city;
  final String gregorianLabel;
  final String hijriLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final hasCity = city.trim().isNotEmpty;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(gregorianLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            hijriLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: colors.oliveDeep),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    hasCity
                        ? 'صلاة ${city.trim()}'
                        : 'حدّدي مدينتك لأوقات الصلاة',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_left, color: colors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.state,
    required this.dayProgress,
    required this.streak,
    required this.now,
    required this.onRetry,
    required this.onLocate,
    required this.onOpenCity,
    required this.onTogglePrayer,
  });

  final PrayerScheduleState state;
  final PrayerDayProgress dayProgress;
  final PrayerStreakSummary streak;
  final DateTime now;
  final VoidCallback onRetry;
  final VoidCallback onLocate;
  final VoidCallback onOpenCity;
  final void Function(PrayerName name) onTogglePrayer;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case PrayerSyncState.loading:
        return const _LoadingCard();
      case PrayerSyncState.needsCity:
        return _MessageCard(
          icon: Icons.location_off_outlined,
          message:
              'لم تُحدَّد مدينة لأوقات الصلاة بعد. اختاري مدينتك لعرض '
              'مواقيت اليوم.',
          primaryLabel: 'تحديد المدينة',
          onPrimary: onOpenCity,
        );
      case PrayerSyncState.permissionDenied:
        return _MessageCard(
          icon: Icons.location_disabled_outlined,
          message: PrayerLocationCopy.permissionDeniedExplanation,
          primaryLabel: 'إدخال المدينة يدويًا',
          onPrimary: onOpenCity,
          secondaryLabel: 'إعادة المحاولة',
          onSecondary: onLocate,
        );
      case PrayerSyncState.offline:
      case PrayerSyncState.error:
        return _MessageCard(
          icon: Icons.wifi_off_rounded,
          message: state.errorMessage ?? 'تعذّر جلب أوقات الصلاة.',
          primaryLabel: 'إعادة المحاولة',
          onPrimary: onRetry,
        );
      case PrayerSyncState.ready:
        final schedule = state.schedule;
        if (schedule == null || !schedule.hasFajr) {
          return _MessageCard(
            icon: Icons.wifi_off_rounded,
            message: 'تعذّر جلب أوقات الصلاة.',
            primaryLabel: 'إعادة المحاولة',
            onPrimary: onRetry,
          );
        }
        final nextInfo = NextPrayerService.nextPrayerInfo(schedule.times, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nextInfo != null) ...[
              NextPrayerCard(info: nextInfo),
              const SizedBox(height: AppSpacing.md),
            ],
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrayerProgressBar(progress: dayProgress),
                  const SizedBox(height: AppSpacing.md),
                  for (final name in PrayerName.values)
                    PrayerRow(
                      name: name,
                      time: schedule.times[name],
                      completed: dayProgress.isCompleted(name),
                      onToggle: () => onTogglePrayer(name),
                    ),
                ],
              ),
            ),
            if (streak.current > 0 || streak.longest > 0) ...[
              const SizedBox(height: AppSpacing.md),
              _StreakCard(current: streak.current, longest: streak.longest),
            ],
          ],
        );
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: colors.gold, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.inkSoft,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            PremiumButton(
              label: secondaryLabel!,
              variant: PremiumButtonVariant.secondary,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return PremiumCard(
      child: Row(
        children: [
          Icon(Icons.military_tech_outlined, color: colors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$current يوم متتالٍ بالحفاظ على الصلوات',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'أطول سلسلة: $longest يوم',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
