// / routes
const mainRoute = "/main";
const authRoute = "/auth";
const signInRoute = "/signin";
const passwordLinkRoute = "/p";
const notFoundRoute = "/not-found";
const statRoute = "/stat";

// /stat routes
const shortRoute = "/short";
const shortRouteName = "Short";

const overviewRoute = "/overview";
const overviewRouteName = "Overview";

const clientsRoute = "/clients";
const clientsRouteName = "Clients";

const linksRoute = "/links";
const linksRouteName = "Links";

const settingsRoute = "/settings";
const settingsRouteName = "Settings";

class MenuItem {
  final String route;
  final String routeName;

  MenuItem(this.route, this.routeName);
}

List<MenuItem> sideMenuItems = [
  MenuItem(overviewRoute, overviewRouteName),
  MenuItem(shortRoute, shortRouteName),
  MenuItem(clientsRoute, clientsRouteName),
  MenuItem(linksRoute, linksRouteName),
  MenuItem(settingsRoute, settingsRouteName),
];
