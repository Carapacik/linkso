import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:linkso/helpers/responsiveness.dart';
import 'package:linkso/helpers/routes.dart';

import '../controller_instances.dart';
import 'side_menu_item.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: sideMenuItems
              .map(
                (item) => SideMenuItem(
                  itemName: item.routeName,
                  onTap: () {
                    if (!menuController.isActive(item.routeName)) {
                      menuController.activeItem.value = item.routeName;
                      if (ResponsiveWidget.isSmallScreen(context)) {
                        Get.back();
                      }
                      navigationController.navigateTo(item.route);
                    }
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
