import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NavigationController extends GetxController {
  static NavigationController instance = Get.find();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  Future navigateTo(String routeName) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false, // Pop all previous
    );
  }

  void goBack() => navigatorKey.currentState!.pop();
}
