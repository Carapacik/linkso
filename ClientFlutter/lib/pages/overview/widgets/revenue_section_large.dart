import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/resources/theme.dart';
import 'package:linkso/widgets/custom_card_container.dart';

import '../../../controller_instances.dart';
import 'clicks_chart.dart';
import 'revenue_info.dart';

class RevenueLarge extends StatelessWidget {
  const RevenueLarge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomCardContainer(
      margin: const EdgeInsets.only(top: 30),
      borderRadius: 40,
      padding: const EdgeInsets.all(25),
      // boxShadow: [
      //   BoxShadow(
      //     offset: const Offset(0, 6),
      //     color: AppColors.lightGrey.withOpacity(0.1),
      //     blurRadius: 12,
      //   )
      // ],
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  AppLocalizations.of(context)!.clicks,
                  style: Theme.of(context).textTheme.b20,
                ),
                SizedBox(
                  height: 200,
                  child: ClicksChart.withRequestData(overviewPageController.listForChart),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 150,
            color: Theme.of(context).colorScheme.background,
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: const [
                    RevenueInfo(title: "Today", amount: "2"),
                    RevenueInfo(title: "Last 7 days", amount: "150"),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    RevenueInfo(title: "Last 30 days", amount: "1500"),
                    RevenueInfo(title: "Last 12 months", amount: "30 202"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
