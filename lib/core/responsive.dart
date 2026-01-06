import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const tablet = 840.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tablet;
  }
}
