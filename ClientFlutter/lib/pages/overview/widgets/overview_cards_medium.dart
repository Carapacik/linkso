import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'info_card.dart';

class OverviewCardsMedium extends StatelessWidget {
  const OverviewCardsMedium({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double _width = MediaQuery.of(context).size.width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            InfoCard(
              title: AppLocalizations.of(context)!.totalLinks,
              value: "7",
            ),
            SizedBox(width: _width / 64),
            InfoCard(
              title: AppLocalizations.of(context)!.totalClicks,
              value: "70",
            ),
          ],
        ),
        SizedBox(height: _width / 64),
        Row(
          children: [
            InfoCard(
              title: AppLocalizations.of(context)!.stat1,
              value: "1",
            ),
            SizedBox(width: _width / 64),
            InfoCard(
              title: AppLocalizations.of(context)!.stat1,
              value: "1",
            ),
          ],
        )
      ],
    );
  }
}
