import 'package:flutter/material.dart';
import 'package:linkso/helpers/responsiveness.dart';

import 'horizontal_menu_items.dart';
import 'vertical_menu_items.dart';

class SideMenuItem extends StatelessWidget {
  const SideMenuItem({
    Key? key,
    required this.itemName,
    this.onTap,
  }) : super(key: key);

  final String itemName;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveWidget.isCustomSize(context)) return VerticalMenuItem(itemName: itemName, onTap: onTap);
    return HorizontalMenuItem(itemName: itemName, onTap: onTap);
  }
}
