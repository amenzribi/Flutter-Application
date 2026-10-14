import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_constants.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/features/user_state/presentation/widgets/sync_status_label.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';

class HomeHeroHeader extends ConsumerWidget {
  const HomeHeroHeader({super.key, required this.model});

  final HomeDashboardViewModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final busy = ref.watch(authControllerProvider).isSubmitting;
    final syncStatus = ref.watch(userSyncStatusProvider);
    final name = model.user?.displayName?.trim();
    final email = model.user?.email ?? '';
    final initial = (name?.isNotEmpty ?? false)
        ? name!.characters.first
        : (email.isNotEmpty ? email.characters.first.toUpperCase() : 'ب');

    return PremiumCard(
      variant: PremiumCardVariant.glass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Hero(
                tag: 'home-profile-avatar',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.oliveSoft,
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.oliveDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.greeting,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name?.isNotEmpty == true ? name! : AppConstants.appName,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: colors.inkSoft),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      syncStatus.labelAr,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.inkSoft),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: busy
                    ? null
                    : () => ref.read(authControllerProvider.notifier).logout(),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.logout_rounded, color: colors.oliveDeep),
              ),
            ],
          ),
          if (model.user?.needsEmailVerification ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            const _VerifyEmailNotice(),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: model.timeLabel,
                emphasize: true,
              ),
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                label: model.gregorianLabel,
              ),
              _MetaChip(icon: Icons.nightlight_round, label: model.hijriLabel),
            ],
          ),
        ],
      ),
    );
  }
}

/// Legacy "تأكيد البريد" sheet as an inline notice: progress stays on this
/// device until the email is confirmed, then syncs.
class _VerifyEmailNotice extends ConsumerStatefulWidget {
  const _VerifyEmailNotice();

  @override
  ConsumerState<_VerifyEmailNotice> createState() => _VerifyEmailNoticeState();
}

class _VerifyEmailNoticeState extends ConsumerState<_VerifyEmailNotice> {
  String? _busy;

  Future<void> _run(String key, Future<String> Function() action) async {
    setState(() => _busy = key);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await action();
    } catch (_) {
      message = 'تعذّر الاتصال. تحقّقي من الشبكة ثم أعيدي المحاولة.';
    }
    if (!mounted) return;
    setState(() => _busy = null);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final repo = ref.read(authRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أكّدي بريدكِ لتفعيل المزامنة. حتى ذلك الحين يُحفظ تقدّمكِ على هذا الجهاز فقط.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: _busy != null
                    ? null
                    : () => _run('send', () async {
                        await repo.sendEmailVerification();
                        return 'أُرسل الرابط — افحصي مجلد الرسائل غير المرغوبة (Spam)';
                      }),
                child: Text(_busy == 'send' ? 'جارٍ الإرسال…' : 'إرسال الرابط'),
              ),
              FilledButton(
                onPressed: _busy != null
                    ? null
                    : () => _run('check', () async {
                        final user = await repo.reloadUser();
                        return user?.emailVerified == true
                            ? 'تمّ التحقّق — المزامنة مفعّلة'
                            : 'لم يتمّ التأكيد بعد';
                      }),
                child: Text(_busy == 'check' ? 'جارٍ التحقّق…' : 'لقد أكّدت'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: emphasize ? colors.oliveSoft : colors.surfaceMuted,
        borderRadius: AppRadii.smAll,
        border: Border.all(
          color: emphasize ? colors.olive.withValues(alpha: 0.35) : colors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: emphasize ? colors.oliveDeep : colors.inkSoft,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: emphasize ? colors.oliveDeep : colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
