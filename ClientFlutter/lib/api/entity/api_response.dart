import 'package:linkso/model/error_validation.dart';

class ApiResponse<T> {
  ApiResponse({
    required this.successResponse,
    required this.data,
    this.error,
  });

  final bool successResponse;
  final ErrorValidation? error;
  final T? data;
}
