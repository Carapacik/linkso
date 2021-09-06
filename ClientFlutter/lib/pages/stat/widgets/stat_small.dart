import 'package:flutter/material.dart';
import 'package:linkso/helpers/stat_navigator.dart';

class StatPageSmall extends StatelessWidget {
  const StatPageSmall({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 15, left: 15, bottom: 15),
      child: statNavigator(),
    );
  }
}
