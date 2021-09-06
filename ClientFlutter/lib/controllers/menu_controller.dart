import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linkso/helpers/routes.dart';
import 'package:linkso/resources/palette.dart';

class MenuController extends GetxController {
  static MenuController instance = Get.find();
  RxString activeItem = overviewRouteName.obs;
  RxString hoverItem = "".obs;

  void onHover(String itemName) {
    if (!isActive(itemName)) hoverItem.value = itemName;
  }

  bool isActive(String itemName) => activeItem.value == itemName;

  bool isHover(String itemName) => hoverItem.value == itemName;

  Widget returnIconFor(String itemName) {
    switch (itemName) {
      case overviewRouteName:
        return _customIcon(Icons.trending_up, itemName);
      case shortRouteName:
        return _customIcon(Icons.shortcut, itemName);
      case clientsRouteName:
        return _customIcon(Icons.people_alt_outlined, itemName);
      case linksRouteName:
        return _customIcon(Icons.link, itemName);
      case settingsRouteName:
      default:
        return _customIcon(Icons.manage_accounts, itemName);
    }
  }

  Widget _customIcon(IconData icon, String itemName) {
    if (isActive(itemName)) {
      return Icon(icon, size: 22, color: AppColors.darkPrimary);
    } else {
      return Icon(icon, color: isHover(itemName) ? AppColors.lightPrimaryVariant : AppColors.lightPrimary);
    }
  }
}
