import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:linkso/pages/all_links/all_links_page.dart';
import 'package:linkso/pages/clients/clients_page.dart';
import 'package:linkso/pages/main/main_page.dart';
import 'package:linkso/pages/overview/overview_page.dart';
import 'package:linkso/pages/settings/settings_page.dart';
import 'package:universal_html/html.dart' as html;

import '../controller_instances.dart';
import 'routes.dart';

Navigator statNavigator() {
  String initialRoute = overviewRoute;
  String route = "";
  final uriBase = Uri.base;
  if (uriBase.pathSegments.length > 1) {
    route = Uri.base.pathSegments[1];
  }
  route = "/$route";
  switch (route) {
    case shortRoute:
      initialRoute = shortRoute;
      break;
    case clientsRoute:
      initialRoute = clientsRoute;
      break;
    case linksRoute:
      initialRoute = linksRoute;
      break;
    case settingsRoute:
      initialRoute = settingsRoute;
      break;
    case overviewRoute:
    default:
      initialRoute = overviewRoute;
      break;
  }
  return Navigator(
    key: navigationController.navigatorKey,
    initialRoute: initialRoute,
    onGenerateRoute: _onGenerateRoute,
  );
}

Route _onGenerateRoute(RouteSettings settings) {
  if (kIsWeb) {
    html.window.history.pushState(null, 'Stat', '/stat${settings.name}');
  }
  switch (settings.name) {
    case shortRoute:
      return _getPageRoute(const MainPageContent());
    case clientsRoute:
      return _getPageRoute(const ClientsPage());
    case linksRoute:
      return _getPageRoute(const AllLinksPage());
    case settingsRoute:
      return _getPageRoute(const SettingsPage());
    case overviewRoute:
    default:
      return _getPageRoute(const OverviewPage());
  }
}

PageRoute _getPageRoute(Widget child) {
  return MaterialPageRoute(builder: (context) => child);
}
