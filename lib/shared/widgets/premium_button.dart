import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_gradients.dart';
import 'package:barakah40_flutter/app/theme/app_motion.dart';
import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

enum PremiumButtonVariant { primary, secondary }

/// Primary/secondary actions with press scale + disabled/loading states.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.busy = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = (!_enabled || reduceMotion)
        ? 1.0
        : (_pressed ? 0.97 : (_hovered ? 1.01 : 1.0));

    final child = AnimatedScale(
      scale: scale,
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      child: _buildSurface(context, colors),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _enabled ? widget.onPressed : null,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: child)
              : child,
        ),
      ),
    );
  }

  Widget _buildSurface(BuildContext context, BarakahColors colors) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final content = widget.busy
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: widget.variant == PremiumButtonVariant.primary
                  ? colors.onOlive
                  : colors.olive,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
            ],
          );

    if (widget.variant == PremiumButtonVariant.primary) {
      return AnimatedOpacity(
        opacity: _enabled ? 1 : 0.55,
        duration: AppMotion.fast,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.oliveCta(colors),
            borderRadius: AppRadii.mdAll,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: DefaultTextStyle(
                style: (labelStyle ?? const TextStyle()).copyWith(
                  color: colors.onOlive,
                ),
                child: IconTheme(
                  data: IconThemeData(color: colors.onOlive),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedOpacity(
      opacity: _enabled ? 1 : 0.55,
      duration: AppMotion.fast,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: colors.line),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Center(
            child: DefaultTextStyle(
              style: (labelStyle ?? const TextStyle()).copyWith(
                color: colors.ink,
              ),
              child: IconTheme(
                data: IconThemeData(color: colors.olive),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact circular/square icon control.
class PremiumIconButton extends StatelessWidget {
  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final button = IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      color: colors.ink,
      disabledColor: colors.muted,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: colors.surfaceMuted,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),
    );
    return button;
  }
}
