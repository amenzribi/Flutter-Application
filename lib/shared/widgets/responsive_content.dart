import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_breakpoints.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';

/// Centers content with a max width suitable for auth / readable columns.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cap = maxWidth ?? AppBreakpoints.contentMaxWidth(width);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: child,
        ),
      ),
    );
  }
}
