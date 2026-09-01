import 'package:flutter/widgets.dart';
import 'package:linkso_client/src/l10n/generated/app_localizations.dart';

extension BuildContextLocalizations on BuildContext {
  AppLocalizations get localizations => AppLocalizations.of(this);
}
