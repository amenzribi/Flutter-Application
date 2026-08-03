/// Responsive breakpoints (logical width).
abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;

  static double contentMaxWidth(double width) {
    if (width >= desktop) return 480;
    if (width >= tablet) return 440;
    return 420;
  }
}
