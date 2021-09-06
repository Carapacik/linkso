import 'package:flutter/material.dart';
import 'package:linkso/resources/theme.dart';

class RevenueInfo extends StatelessWidget {
  const RevenueInfo({
    Key? key,
    required this.title,
    required this.amount,
  }) : super(key: key);

  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: "$title\n",
              style: Theme.of(context).textTheme.m16,
            ),
            TextSpan(
              text: amount,
              style: Theme.of(context).textTheme.b24.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
