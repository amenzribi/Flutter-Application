import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/core/constants/app_constants.dart';
import 'package:barakah40_flutter/shared/widgets/animated_logo.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumScaffold(
      style: PremiumScaffoldStyle.splash,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedLogoMark(light: true, showTitle: true, size: 72),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Color(0xFFE9D9A8),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              AppConstants.appNameLatin,
              style: TextStyle(
                color: Color(0xFFE9D9A8),
                fontFamily: 'Tajawal',
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
