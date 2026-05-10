import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    Key? key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  }) : super(key: key);

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 850;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100 &&
      MediaQuery.of(context).size.width >= 850;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= 1100) {
      return desktop;
    } else if (width >= 850 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }

  /// Helper to get a constrained width for desktop/tablet content
  static Widget constrainedContent({required Widget child, double maxWidth = 1000}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// Helper to get dynamic cross axis count for grids
  static int getGridCount(BuildContext context, {int base = 2}) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1400) return base + 4;
    if (width > 1100) return base + 2;
    if (width > 850) return base + 1;
    return base;
  }
}
