import 'package:linkso_client/src/core/navigation/app_url_strategy_stub.dart'
    if (dart.library.js_interop) 'package:linkso_client/src/core/navigation/app_url_strategy_web.dart'
    as implementation;

void configureAppUrlStrategy() => implementation.configurePlatformUrlStrategy();
