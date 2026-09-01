import 'package:linkso_client/src/core/auth/session_token_store_base.dart';
import 'package:linkso_client/src/core/auth/session_token_store_web.dart'
    if (dart.library.io) 'package:linkso_client/src/core/auth/session_token_store_native.dart'
    as implementation;

export 'package:linkso_client/src/core/auth/session_token_store_base.dart';

SessionTokenStore createSessionTokenStore() => implementation.createPlatformSessionTokenStore();
