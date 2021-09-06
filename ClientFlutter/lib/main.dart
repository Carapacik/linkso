import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_strategy/url_strategy.dart';

import 'api/entity/account.dart';
import 'api/remote_data_source.dart';
import 'api/remote_data_source_implementation.dart';
import 'app.dart';
import 'controllers/account_controller.dart';
import 'controllers/main_page_controller.dart';
import 'controllers/menu_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/overview_page_controller.dart';
import 'controllers/password_link_page_controller.dart';
import 'controllers/signin_page_controller.dart';
import 'controllers/theme_controller.dart';

void main() async {
  setPathUrlStrategy();
  await GetStorage.init();

  final getIt = GetIt.instance;
  getIt.registerSingleton<RemoteDataSource>(RemoteDataSourceImplementation());
  getIt.registerLazySingleton<UserAccount>(() => UserAccount());

  Get.put(AccountController());
  Get.put(MenuController());
  Get.put(NavigationController());
  Get.put(ThemeController());

  Get.put(MainPageController());
  Get.put(PasswordLinkPageController());
  Get.put(OverviewPageController());
  Get.put(SignInPageController());

  runApp(const App());
}
