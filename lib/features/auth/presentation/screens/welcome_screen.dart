import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/shared/widgets/animated_logo.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;

    return PremiumScaffold(
      style: PremiumScaffoldStyle.atmospheric,
      body: ResponsiveContent(
        child: PageEntrance(
          child: Column(
            children: [
              const Spacer(flex: 2),
              const AnimatedLogoMark(light: true, showTitle: true, size: 68),
              const SizedBox(height: AppSpacing.md),
              Text(
                'رفيقُكِ لختم سورة البقرة في أربعين يوماً، بثباتٍ وطمأنينة.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onOlive.withValues(alpha: 0.92),
                  height: 1.6,
                ),
              ),
              const Spacer(),
              PremiumCard(
                variant: PremiumCardVariant.glass,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumButton(
                      label: 'تسجيل الدخول',
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PremiumButton(
                      label: 'إنشاء حساب',
                      variant: PremiumButtonVariant.secondary,
                      onPressed: () => context.go(AppRoutes.register),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
