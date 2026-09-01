import 'package:flutter_web_plugins/url_strategy.dart';

// Keep email-link tokens in fragments without switching to hash-based routing.
void configurePlatformUrlStrategy() => setUrlStrategy(PathUrlStrategy(BrowserPlatformLocation(), true));
