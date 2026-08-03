import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_gradients.dart';
import 'package:barakah40_flutter/app/theme/app_motion.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_assets.dart';

enum PremiumScaffoldStyle { plain, atmospheric, splash }

/// Shared page chrome with optional hero photography (welcome only).
class PremiumScaffold extends StatelessWidget {
  const PremiumScaffold({
    super.key,
    required this.body,
    this.style = PremiumScaffoldStyle.plain,
    this.appBar,
    this.safeArea = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PremiumScaffoldStyle style;
  final PreferredSizeWidget? appBar;
  final bool safeArea;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    Widget content = body;
    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: style != PremiumScaffoldStyle.plain,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Background(style: style, colors: colors),
          content,
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.style, required this.colors});

  final PremiumScaffoldStyle style;
  final BarakahColors colors;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case PremiumScaffoldStyle.plain:
        return ColoredBox(color: colors.bg);
      case PremiumScaffoldStyle.splash:
        return DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.splash(colors)),
        );
      case PremiumScaffoldStyle.atmospheric:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.welcomeHero,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.heroScrim(colors),
              ),
            ),
          ],
        );
    }
  }
}

/// Soft fade+slide page content entrance.
class PageEntrance extends StatefulWidget {
  const PageEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.page);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.entrance);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.entrance));
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
