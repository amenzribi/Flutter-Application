import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/tree/domain/tree_growth_service.dart';
import 'package:barakah40_flutter/features/tree/presentation/providers/tree_providers.dart';

/// Legacy `.tree-card.glass` home card: the cinematic stage photograph with
/// a warm glow, the stage badge, title, hint and next-stage progress bar.
///
/// Motion (all disabled when the platform asks for reduced motion):
/// - a slow breathing scale on the photo (≈1.5%, 8s) so leaves feel alive;
/// - the legacy `treeGlow` pulse of warm light from above (5s);
/// - a few golden motes drifting upwards in the light;
/// - a crossfade when the stage image changes, and the bar easing to its
///   new value when progress increases.
class TreeCard extends ConsumerWidget {
  const TreeCard({super.key, this.compact = true, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(treePersistProvider);
    final d = ref.watch(treeDisplayProvider);
    return Semantics(
      button: onTap != null,
      label: 'شجرة إنجازاتي: ${d.label}. ${d.hint}',
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment(-0.5, -1),
              end: Alignment(0.5, 1),
              colors: [Color(0xB820261B), Color(0xD112160F)],
            ),
            border: Border.all(color: const Color(0x2ED8B878)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TreeScene(display: d),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact ? 'شجرة إنجازاتي' : 'شجرة الإنجازات',
                        style: const TextStyle(
                          fontFamily: 'ReemKufi',
                          fontSize: 18,
                          color: Color(0xFFD8B878),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.hint,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          height: 1.6,
                          color: Color(0xD9F1ECE0),
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'النمو إلى المرحلة التالية',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xB3F1ECE0),
                                ),
                              ),
                            ),
                            Text(
                              '${d.nextPercent}%',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xB3F1ECE0),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      TreeProgressBar(percent: d.nextPercent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 3:2 photograph with glow, motes and the stage badge.
class TreeScene extends StatefulWidget {
  const TreeScene({super.key, required this.display});

  final TreeDisplay display;

  @override
  State<TreeScene> createState() => _TreeSceneState();
}

class _TreeSceneState extends State<TreeScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _loop
        ..stop()
        ..value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.display;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF0D1108)),
            AnimatedBuilder(
              animation: _loop,
              builder: (context, child) {
                // 8s breathing cycle within the 40s loop.
                final t = _loop.value * 5 * 2 * math.pi;
                final scale = 1.0 + 0.0075 * (1 - math.cos(t));
                return Transform.scale(
                  scale: scale,
                  alignment: const Alignment(0, 0.3),
                  child: child,
                );
              },
              child: AnimatedSwitcher(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 1200),
                switchInCurve: Curves.easeOut,
                child: Image.asset(
                  d.imageAsset,
                  key: ValueKey(d.imageAsset),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
            // Legacy `.tree-frame-glow` + `treeGlow` 5s pulse.
            AnimatedBuilder(
              animation: _loop,
              builder: (context, _) {
                final t = _loop.value * 8 * 2 * math.pi;
                final opacity = reduce ? 0.8 : 0.775 + 0.225 * math.sin(t);
                return Opacity(
                  opacity: opacity,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.56),
                        radius: 0.75,
                        colors: [Color(0x33D8B878), Color(0x00D8B878)],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!reduce && d.healthy)
              IgnorePointer(child: CustomPaint(painter: _MotesPainter(_loop))),
            PositionedDirectional(
              bottom: 12,
              end: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x9E10140C),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x4DD8B878)),
                ),
                child: Text(
                  d.label,
                  style: const TextStyle(
                    fontFamily: 'ReemKufi',
                    fontSize: 13,
                    color: Color(0xFFF1ECE0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Golden dust rising slowly through the light cone.
class _MotesPainter extends CustomPainter {
  _MotesPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static final _seeds = List.generate(14, (i) {
    final r = math.Random(i * 7919 + 13);
    return (
      x: 0.25 + r.nextDouble() * 0.5,
      phase: r.nextDouble(),
      speed: 1 + r.nextInt(3),
      size: 0.8 + r.nextDouble() * 1.6,
      sway: r.nextDouble() * 2 * math.pi,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in _seeds) {
      final p = (animation.value * s.speed + s.phase) % 1.0;
      final y = size.height * (0.85 - 0.8 * p);
      final x =
          size.width * (s.x + 0.02 * math.sin(2 * math.pi * p * 2 + s.sway));
      final alpha = (math.sin(math.pi * p) * 0.75).clamp(0.0, 1.0);
      paint.color = Color.fromRGBO(255, 214, 150, alpha);
      canvas.drawCircle(Offset(x, y), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter oldDelegate) => false;
}

/// Legacy `.tw-bar`: olive→gold fill that eases to its new width.
class TreeProgressBar extends StatelessWidget {
  const TreeProgressBar({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(99),
      ),
      clipBehavior: Clip.antiAlias,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: percent / 100),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B7A4F), Color(0xFFBF9D57)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
