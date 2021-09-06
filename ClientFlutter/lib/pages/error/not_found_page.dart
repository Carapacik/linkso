import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/resources/theme.dart';
import 'package:linkso/widgets/custom_scaffold.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      largeScreen: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.code404,
              style: Theme.of(context).textTheme.b48.copyWith(color: Theme.of(context).colorScheme.onError),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.notFound,
              style: Theme.of(context).textTheme.b24.copyWith(color: Theme.of(context).colorScheme.onError),
            ),
          ],
        ),
      ),
    );
  }
}
