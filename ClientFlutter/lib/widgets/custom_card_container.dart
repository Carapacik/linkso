import 'package:flutter/material.dart';

class CustomCardContainer extends StatelessWidget {
  const CustomCardContainer({
    Key? key,
    required this.child,
    this.borderRadius,
    this.constraints,
    this.padding,
    this.height,
    this.margin,
  }) : super(key: key);

  final Widget child;
  final double? borderRadius;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: height,
      constraints: constraints,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
      ),
      child: child,
    );
  }
}
