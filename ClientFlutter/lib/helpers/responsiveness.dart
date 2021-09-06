import 'package:flutter/material.dart';

const largeScreenSize = 1366;
const mediumScreenSize = 768;
const smallScreenSize = 360;
const customScreenSize = 1100;

class ResponsiveWidget extends StatelessWidget {
  const ResponsiveWidget({
    Key? key,
    required this.largeScreen,
    this.mediumScreen,
    this.smallScreen,
    this.customScreen,
  }) : super(key: key);

  final Widget largeScreen;
  final Widget? mediumScreen;
  final Widget? smallScreen;
  final Widget? customScreen;

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < mediumScreenSize;
  }

  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= mediumScreenSize && MediaQuery.of(context).size.width < largeScreenSize;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > largeScreenSize;
  }

  static bool isCustomSize(BuildContext context) {
    return MediaQuery.of(context).size.width <= customScreenSize && MediaQuery.of(context).size.width >= mediumScreenSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double _width = constraints.maxWidth;
        if (_width >= largeScreenSize) {
          return largeScreen;
        } else if (_width >= mediumScreenSize) {
          return mediumScreen ?? largeScreen;
        } else {
          return smallScreen ?? largeScreen;
        }
      },
    );
  }
}
