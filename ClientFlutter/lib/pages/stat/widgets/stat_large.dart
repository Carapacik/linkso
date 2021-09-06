import 'package:flutter/material.dart';
import 'package:linkso/helpers/stat_navigator.dart';
import 'package:linkso/widgets/drawer.dart';

class StatPageLarge extends StatelessWidget {
  const StatPageLarge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: drawer(context)),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(top: 20, right: 15, left: 15, bottom: 15),
            child: statNavigator(),
          ),
        ),
      ],
    );
  }
}
