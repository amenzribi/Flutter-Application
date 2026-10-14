import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

/// One legacy `.qcard`: icon tile + Reem Kufi title + muted subtitle.
class QuickCardSpec {
  const QuickCardSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

/// Legacy `.quick` two-column grid. Only destinations that exist in this
/// app are listed, so nothing here leads to a "coming soon" dead end.
class LegacyQuickGrid extends StatelessWidget {
  const LegacyQuickGrid({super.key, required this.items});

  final List<QuickCardSpec> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 13));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _QuickCard(spec: items[i])),
              const SizedBox(width: 13),
              Expanded(
                child: i + 1 < items.length
                    ? _QuickCard(spec: items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _QuickCard extends StatefulWidget {
  const _QuickCard({required this.spec});

  final QuickCardSpec spec;

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final s = widget.spec;
    return Semantics(
      button: true,
      label: '${s.title}، ${s.subtitle}',
      onTap: s.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: s.onTap,
          child: AnimatedScale(
            scale: reduce || !_pressed ? 1 : 0.98,
            duration: const Duration(milliseconds: 200),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.oliveSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s.icon, size: 21, color: colors.oliveDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            fontFamily: 'ReemKufi',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          s.subtitle,
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
