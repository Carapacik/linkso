import 'package:flutter/material.dart';
import 'package:linkso/helpers/responsiveness.dart';
import 'package:linkso/resources/theme.dart';
import 'package:linkso/widgets/custom_card_container.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    Key? key,
    required this.title,
    required this.value,
  }) : super(key: key);

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveWidget.isSmallScreen(context)) {
      return CustomCardContainer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.m16,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.b24,
            ),
          ],
        ),
      );
    } else {
      return Expanded(
        child: CustomCardContainer(
          height: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "$title\n",
                      style: Theme.of(context).textTheme.m16,
                    ),
                    TextSpan(
                      text: value,
                      style: Theme.of(context).textTheme.b36,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
