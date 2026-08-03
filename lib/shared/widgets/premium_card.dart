import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_shadows.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

enum PremiumCardVariant { elevated, glass }

/// Elevated surface or selective glass — not for every layout.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.variant = PremiumCardVariant.elevated,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final PremiumCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final pad = padding ?? const EdgeInsets.all(AppSpacing.cardPadding);

    final content = Padding(padding: pad, child: child);

    if (variant == PremiumCardVariant.glass) {
      return ClipRRect(
        borderRadius: AppRadii.lgAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppShadows.glassBlur,
            sigmaY: AppShadows.glassBlur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.78),
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: onTap == null
                  ? content
                  : InkWell(
                      onTap: onTap,
                      borderRadius: AppRadii.lgAll,
                      child: content,
                    ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: colors.line),
        boxShadow: AppShadows.card(colors.ink),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: AppRadii.lgAll,
                child: content,
              ),
      ),
    );
  }
}
