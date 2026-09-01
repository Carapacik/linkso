import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:material_ui/material_ui.dart';

class const LinkKindSelector({
  required final LinkKind selected,
  required final ValueChanged<Set<LinkKind>>? onSelectionChanged,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final LinkKind kind in LinkKind.values)
        ChoiceChip(
          selected: kind == selected,
          showCheckmark: false,
          avatar: Icon(switch (kind) {
            LinkKind.direct => Icons.fast_forward_rounded,
            LinkKind.password => Icons.password_rounded,
            LinkKind.advertising => Icons.campaign_rounded,
          }),
          label: Text(switch (kind) {
            LinkKind.direct => context.localizations.directModeTitle,
            LinkKind.password => context.localizations.passwordModeTitle,
            LinkKind.advertising => context.localizations.advertisingModeTitle,
          }),
          onSelected: onSelectionChanged == null ? null : (_) => onSelectionChanged!({kind}),
        ),
    ],
  );
}
