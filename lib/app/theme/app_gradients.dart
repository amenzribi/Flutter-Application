import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

abstract final class AppGradients {
  static LinearGradient oliveCta(BarakahColors c) => LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [c.olive, c.oliveDeep],
  );

  static LinearGradient heroScrim(BarakahColors c) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [c.heroOverlayStart, c.heroOverlayEnd],
  );

  static RadialGradient splash(BarakahColors c) => RadialGradient(
    center: const Alignment(0, -0.2),
    radius: 1.1,
    colors: [c.oliveDeep, const Color(0xFF0D110A)],
  );
}
