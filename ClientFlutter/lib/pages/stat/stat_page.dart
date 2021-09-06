import 'package:flutter/material.dart';
import 'package:linkso/widgets/custom_scaffold.dart';

import 'widgets/stat_large.dart';
import 'widgets/stat_small.dart';

class StatPage extends StatelessWidget {
  const StatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBarEnabled: true,
      drawerEnabled: true,
      largeScreen: const StatPageLarge(),
      smallScreen: const StatPageSmall(),
    );
  }
}
