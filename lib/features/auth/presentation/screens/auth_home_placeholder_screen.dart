import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/app/shell/app_shell.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_constants.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';
import 'package:barakah40_flutter/shared/widgets/animated_logo.dart';

/// Polished temporary verification screen — no fake dashboard content.
class AuthHomePlaceholderScreen extends ConsumerWidget {
  const AuthHomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final formState = ref.watch(authControllerProvider);
    final busy = formState.isSubmitting;
    final colors = context.barakahColors;

    return AppShell(
      child: ResponsiveContent(
        child: PageEntrance(
          child: Column(
            children: [
              const Spacer(),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AnimatedLogoMark(size: 64)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppConstants.appNameLatin,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      user?.email ?? 'بدون بريد',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: colors.inkSoft),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'تمّت المصادقة بنجاح. هجرة ميزات المنتج (المنزل، القرآن، الصلاة…) '
                      'تبدأ في المرحلة التالية — هذه شاشة تحقّق مؤقّتة فقط.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.inkSoft,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ErrorBanner(message: formState.message),
                    LoadingButton(
                      label: 'تسجيل الخروج',
                      busy: busy,
                      variant: PremiumButtonVariant.secondary,
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
