import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_constants.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Authenticated app shell — top brand bar only (no fake nav destinations).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;

    return PremiumScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: ResponsiveContent(
              child: Row(
                children: [
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  Text(
                    'الرئيسية',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: colors.oliveDeep),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.line),
          Expanded(child: child),
        ],
      ),
    );
  }
}
