const defaultApiBaseUrl = 'http://localhost:8080';
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultApiBaseUrl);

Uri createApiBaseUri({String value = apiBaseUrl}) {
  final Uri uri = Uri.parse(value);
  if (!uri.hasAuthority || !const {'http', 'https'}.contains(uri.scheme) || uri.hasQuery || uri.hasFragment) {
    throw const FormatException('API_BASE_URL must be an HTTP(S) origin without query or fragment');
  }

  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}
