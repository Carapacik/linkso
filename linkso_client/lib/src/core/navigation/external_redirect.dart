import 'package:url_launcher/url_launcher.dart';

typedef ExternalRedirect = Future<void> Function(Uri uri);

Future<void> redirectToExternalUri(Uri uri) async {
  final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_self');
  if (!launched) {
    throw StateError('The external URL could not be opened');
  }
}
