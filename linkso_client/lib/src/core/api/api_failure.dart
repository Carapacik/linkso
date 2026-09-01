import 'dart:convert';

final class const ApiFailure({
  required final int? statusCode,
  required final String code,
  required final String message,
  final String? field,
  final String? requestId,
  final int? retryAfterSeconds,
}) implements Exception {
  @override
  String toString() => 'ApiFailure($code, status: $statusCode)';
}

const networkApiFailure = ApiFailure(statusCode: null, code: 'network_error', message: 'The server is unreachable');
const requestTimeoutApiFailure = ApiFailure(
  statusCode: null,
  code: 'request_timeout',
  message: 'The request timed out; check the operation result before retrying',
);
const invalidResponseApiFailure = ApiFailure(
  statusCode: null,
  code: 'invalid_response',
  message: 'The server returned an invalid response',
);

ApiFailure parseApiFailureResponse({required int statusCode, required String responseBody}) {
  try {
    final Object? decoded = jsonDecode(responseBody);
    if (decoded case {'error': final Map<String, Object?> error}) {
      return ApiFailure(
        statusCode: statusCode,
        code: error['code'] as String? ?? 'unexpected_error',
        message: error['message'] as String? ?? 'An unexpected server error occurred',
        field: error['field'] as String?,
        requestId: error['request_id'] as String?,
        retryAfterSeconds: error['retry_after_seconds'] as int?,
      );
    }
  } on FormatException {
    // The fallback below intentionally hides malformed server response details.
  }

  return ApiFailure(statusCode: statusCode, code: 'unexpected_error', message: 'An unexpected server error occurred');
}
