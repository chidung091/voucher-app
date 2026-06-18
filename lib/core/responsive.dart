import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const tablet = 840.0;
  static const desktop = 1200.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tablet;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktop;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) {
      return const EdgeInsets.all(32);
    }
    if (width >= tablet) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(16);
  }

  static int columnsForWidth(
    double width, {
    double minColumnWidth = 320,
    int maxColumns = 3,
  }) {
    if (width <= 0) return 1;
    return (width / minColumnWidth).floor().clamp(1, maxColumns);
  }
}
