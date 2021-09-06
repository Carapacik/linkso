class ApiException implements Exception {
  final String message;

  ApiException({required this.message});
}

class ServerConnectionException extends ApiException {
  ServerConnectionException() : super(message: 'Server connection error');
}
