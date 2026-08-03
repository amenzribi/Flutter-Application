import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';

/// Shared home section card with optional empty state.
class HomeSectionCard extends StatelessWidget {
  const HomeSectionCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.child,
    this.emptyMessage,
    this.isEmpty = false,
    this.variant = PremiumCardVariant.elevated,
    this.onTap,
    this.heroTag,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? child;
  final String? emptyMessage;
  final bool isEmpty;
  final PremiumCardVariant variant;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.oliveSoft,
                borderRadius: AppRadii.smAll,
              ),
              child: Icon(icon, color: colors.oliveDeep, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (isEmpty)
          _EmptyState(message: emptyMessage ?? 'لا توجد بيانات بعد')
        else
          ?child,
      ],
    );

    final card = PremiumCard(variant: variant, onTap: onTap, child: body);
    if (heroTag == null) return card;
    return Hero(tag: heroTag!, child: card);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Icon(Icons.spa_outlined, color: colors.gold, size: 28),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
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
}
