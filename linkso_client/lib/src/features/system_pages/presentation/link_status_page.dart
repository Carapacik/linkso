import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:material_ui/material_ui.dart';

enum LinkStatusPageKind() {
  notFound,
  expired,
  disabled,
  blocked,
}

class const LinkStatusPage({required final LinkStatusPageKind kind, super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ({IconData icon, String message, String title}) content = switch (kind) {
      LinkStatusPageKind.notFound => (
        icon: Icons.search_off_rounded,
        title: context.localizations.notFoundTitle,
        message: context.localizations.notFoundMessage,
      ),
      LinkStatusPageKind.expired => (
        icon: Icons.schedule_rounded,
        title: context.localizations.expiredTitle,
        message: context.localizations.expiredMessage,
      ),
      LinkStatusPageKind.disabled => (
        icon: Icons.link_off_rounded,
        title: context.localizations.disabledTitle,
        message: context.localizations.disabledMessage,
      ),
      LinkStatusPageKind.blocked => (
        icon: Icons.block_rounded,
        title: context.localizations.blockedTitle,
        message: context.localizations.blockedMessage,
      ),
    };

    return Semantics(
      key: ValueKey<String>('${kind.name}-page'),
      header: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(content.icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(content.title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(content.message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
