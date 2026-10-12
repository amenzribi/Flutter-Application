import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

/// Legacy `avatarColor(seed)`: stable earthy color per uid.
Color legacyAvatarColor(String seed) {
  const palette = [
    Color(0xFF6B7A48),
    Color(0xFF7C8A52),
    Color(0xFF8A7A3F),
    Color(0xFF9A6B3A),
    Color(0xFF5F6F44),
    Color(0xFF6F7A52),
    Color(0xFF7A6A8F),
    Color(0xFF4E6A52),
  ];
  var h = 0;
  for (final unit in seed.codeUnits) {
    h = (h * 31 + unit) & 0xFFFFFFFF;
  }
  return palette[h % palette.length];
}

String initialOf(String name) =>
    name.trim().isEmpty ? '؟' : String.fromCharCode(name.trim().runes.first);

/// Round initial avatar (legacy `.fr-av` / `.ures-av`).
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.size = 42,
  });

  final String uid;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: legacyAvatarColor(uid),
          shape: BoxShape.circle,
        ),
        child: Text(
          initialOf(name),
          style: TextStyle(
            fontFamily: 'ReemKufi',
            fontSize: size * 0.43,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Segmented tabs in the legacy `.comm-tabs` / `.sub-seg` style.
class LegacySegmentedTabs extends StatelessWidget {
  const LegacySegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.badges = const {},
    this.icons,
    this.dense = false,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Map<int, int> badges;
  final List<IconData>? icons;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      padding: EdgeInsets.all(dense ? 4 : 5),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(dense ? 12 : 14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) SizedBox(width: dense ? 4 : 6),
            Expanded(
              child: _SegButton(
                label: labels[i],
                icon: icons?[i],
                selected: i == selected,
                badge: badges[i] ?? 0,
                dense: dense,
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.badge,
    required this.dense,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final int badge;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final fg = selected ? Colors.white : colors.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.olive : Colors.transparent,
        borderRadius: BorderRadius.circular(dense ? 9 : 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(dense ? 9 : 10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: dense ? 8 : 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: fg),
                    const SizedBox(width: 5),
                  ],
                  // Shrinks instead of truncating on 320px screens.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w700,
                          fontSize: dense ? 12 : 13.5,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  if (badge > 0) ...[
                    const SizedBox(width: 4),
                    CountBadge(count: badge),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold pill count (legacy `.ct-badge`).
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.gold,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3A3320),
        ),
      ),
    );
  }
}

enum MiniButtonTone { ok, no, plain }

/// Small action pill (legacy `.mini.ok` / `.mini.no`), 44px touch target.
class MiniButton extends StatelessWidget {
  const MiniButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = MiniButtonTone.plain,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final MiniButtonTone tone;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final (bg, fg, border) = switch (tone) {
      MiniButtonTone.ok => (colors.olive, Colors.white, Colors.transparent),
      MiniButtonTone.no => (
        Colors.transparent,
        const Color(0xFFB15B4E),
        const Color(0x66B15B4E),
      ),
      MiniButtonTone.plain => (colors.surface, colors.ink, colors.line),
    };
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled || busy ? 1 : 0.55,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 15, color: fg),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// List row container (legacy `.fr-row`).
class LegacyRow extends StatelessWidget {
  const LegacyRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: colors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Dashed empty-state note (legacy `.empty-c`).
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              height: 1.8,
              color: colors.muted,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

/// Inline error with a retry action, used for failed loads.
class RetryNote extends StatelessWidget {
  const RetryNote({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyNote(
      message: message,
      action: MiniButton(
        label: 'إعادة المحاولة',
        icon: Icons.refresh_rounded,
        tone: MiniButtonTone.ok,
        onPressed: onRetry,
      ),
    );
  }
}

void showSocialSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool destructive = false,
}) async {
  final colors = context.barakahColors;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? colors.danger : colors.olive,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
