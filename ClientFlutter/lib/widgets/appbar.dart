import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:linkso/helpers/responsiveness.dart';
import 'package:linkso/resources/theme.dart';
import 'package:url_launcher/link.dart';

import '../controller_instances.dart';

AppBar appBar(BuildContext context, GlobalKey<ScaffoldState> key) {
  // final locale = Localizations.localeOf(context);
  //
  // Locale _getLocale(Locale l) {
  //   switch (l.languageCode) {
  //     case 'en':
  //       return const Locale('ru', 'RU');
  //     case 'ru':
  //     default:
  //       return const Locale('en', '');
  //   }
  // }

  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: accountController.isAuth.value
        ? ResponsiveWidget.isSmallScreen(context)
            ? IconButton(
                onPressed: () {
                  key.currentState?.openDrawer();
                },
                splashRadius: 25,
                icon: const Icon(
                  Icons.menu,
                  size: 22,
                ),
              )
            : const SizedBox()
        : const SizedBox(),
    actions: [
      Obx(
        () => IconButton(
          onPressed: () {
            themeController.switchTheme(context);
          },
          splashRadius: 25,
          icon: themeController.isDarkMode.value
              ? const Icon(
                  Icons.light_mode,
                  size: 22,
                )
              : const Icon(
                  Icons.dark_mode,
                  size: 22,
                ),
        ),
      ),
      // PopupMenuNew(),
      signIn(context),
    ],
  );
}

//
// class PopupMenuNew extends StatefulWidget {
//   const PopupMenuNew({Key? key}) : super(key: key);
//
//   @override
//   _PopupMenuNewState createState() => _PopupMenuNewState();
// }
//
// class _PopupMenuNewState extends State<PopupMenuNew> {
//   @override
//   // Item _selection = Item.i1;
//
//   Widget build(BuildContext context) {
//     return PopupMenuButton(
//       itemBuilder: (BuildContext context) => [
//         PopupMenuItem(
//           child: PopupMenuButton(
//             child: Text('Language'),
//             onSelected: (Item result) {
//               Navigator.pop(context);
//               setState(() {
//                 result = Item.i1;
//               });
//             },
//             itemBuilder: (BuildContext context) => <PopupMenuEntry<Item>>[
//               const PopupMenuItem<Item>(
//                 value: Item.i1,
//                 child: Text('Ru'),
//               ),
//               const PopupMenuItem<Item>(
//                 value: Item.i2,
//                 child: Text('En'),
//               ),
//               const PopupMenuItem<Item>(
//                 value: Item.i2,
//                 child: Text('GG'),
//               ),
//             ],
//           ),
//         ),
//         PopupMenuItem(
//           child: PopupMenuButton(
//             child: Text('Theme'),
//             onSelected: (Item result) {
//               // setState(() {
//               //   _selection = result;
//               // });
//               Navigator.pop(context);
//             },
//             itemBuilder: (BuildContext context) => <PopupMenuEntry<Item>>[
//               PopupMenuItem<Item>(
//                 value: Item.i3,
//                 child: Text('Dark'),
//                 onTap: () => print("Dark"),
//               ),
//               PopupMenuItem<Item>(
//                 value: Item.i4,
//                 child: Text('Light'),
//                 onTap: () => print("Light"),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

Widget signIn(BuildContext context) {
  if (accountController.isAuth.value) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: accountController.logout,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              AppLocalizations.of(context)!.logout,
              style: Theme.of(context).textTheme.b18,
            ),
          ),
        ),
      ),
    );
  } else {
    return Link(
      uri: Uri.parse("/signin"),
      builder: (context, followLink) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: followLink,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  AppLocalizations.of(context)!.login,
                  style: Theme.of(context).textTheme.b18,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
