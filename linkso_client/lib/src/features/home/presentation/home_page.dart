import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/core/widgets/linkso_logo.dart';
import 'package:material_ui/material_ui.dart';

class const HomePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('home-page'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LinkSoLogo(size: 80),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final (TextStyle? style, double maxScaleFactor) = switch (constraints.maxWidth) {
                      < 300 => (theme.textTheme.headlineSmall, 1.25),
                      < 400 => (theme.textTheme.headlineMedium, 1.25),
                      _ => (theme.textTheme.displaySmall, 1.5),
                    };
                    return MediaQuery.withClampedTextScaling(
                      maxScaleFactor: maxScaleFactor,
                      child: Text(
                        context.localizations.homeTitle,
                        key: const ValueKey<String>('home-title'),
                        textAlign: TextAlign.center,
                        style: style?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  context.localizations.homeDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(context.localizations.directModeTitle)),
                    Chip(label: Text(context.localizations.passwordModeTitle)),
                    Chip(label: Text(context.localizations.advertisingModeTitle)),
                  ],
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  key: const ValueKey<String>('home-create-link-button'),
                  onPressed: () => context.go(shortenPath),
                  icon: const Icon(Icons.add_link_rounded),
                  label: Text(context.localizations.createLinkAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
