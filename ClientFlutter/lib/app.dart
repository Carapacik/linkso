import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';

import 'controller_instances.dart';
import 'helpers/routes.dart';
import 'pages/error/not_found_page.dart';
import 'pages/main/main_page.dart';
import 'pages/password_link/password_link_page.dart';
import 'pages/signin/signin_page.dart';
import 'pages/stat/stat_page.dart';

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: mainRoute,
      unknownRoute: GetPage(name: notFoundRoute, page: () => const NotFoundPage()),
      getPages: [
        GetPage(name: notFoundRoute, page: () => const NotFoundPage()),
        GetPage(name: mainRoute, page: () => const MainPage()),
        GetPage(name: signInRoute, page: () => const SignInPage()),
        GetPage(name: passwordLinkRoute, page: () => const PasswordLinkPage()),
        GetPage(name: statRoute, page: () => const StatPage()),
      ],
      theme: themeController.savedThemeData(),
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ru', 'RU'),
      ],
    );
  }
}
