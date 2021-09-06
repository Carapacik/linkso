import 'package:flutter/material.dart';
import 'package:linkso/resources/palette.dart';

class AnimatedGradientBackground extends StatelessWidget {
  const AnimatedGradientBackground({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(gradient: _getBackgroundGradient(Theme.of(context))),
        ),
        child,
      ],
    );
  }

  LinearGradient _getBackgroundGradient(ThemeData themeData) {
    if (themeData.brightness == Brightness.light) {
      return AppColors.lightGradient;
    } else {
      return AppColors.darkGradient;
    }
  }
}
