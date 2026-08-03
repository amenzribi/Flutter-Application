import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.onUnavailable});

  /// Called when a not-yet-migrated feature is tapped.
  final void Function(String featureLabel) onUnavailable;

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionSpec>[
      _ActionSpec('القرآن', Icons.menu_book_rounded),
      _ActionSpec('الأذكار', Icons.auto_awesome_outlined),
      _ActionSpec('الصلاة', Icons.mosque_outlined),
      _ActionSpec('الحديقة', Icons.park_outlined),
    ];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('اختصارات', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ستُفعَّل عند هجرة كل ميزة.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _QuickActionButton(
                    label: actions[i].label,
                    icon: actions[i].icon,
                    onTap: () => onUnavailable(actions[i].label),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: reduce ? 1 : (_pressed ? 0.96 : 1),
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                Icon(widget.icon, color: colors.oliveDeep),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
