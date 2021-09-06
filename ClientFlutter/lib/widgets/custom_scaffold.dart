import 'package:flutter/material.dart';
import 'package:linkso/helpers/responsiveness.dart';

import 'animated_gradient_background.dart';
import 'appbar.dart';
import 'drawer.dart';

class CustomScaffold extends StatelessWidget {
  CustomScaffold({
    Key? key,
    this.drawerEnabled = false,
    this.appBarEnabled = false,
    required this.largeScreen,
    this.mediumScreen,
    this.smallScreen,
  }) : super(key: key);

  final bool appBarEnabled;
  final bool drawerEnabled;
  final Widget largeScreen;
  final Widget? mediumScreen;
  final Widget? smallScreen;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: appBarEnabled ? appBar(context, _scaffoldKey) : null,
      drawer: drawerEnabled ? Drawer(child: drawer(context)) : null,
      body: AnimatedGradientBackground(
        child: ResponsiveWidget(
          largeScreen: largeScreen,
          mediumScreen: mediumScreen,
          smallScreen: smallScreen,
        ),
      ),
    );
  }
}
