import 'package:json_annotation/json_annotation.dart';

part 'error_validation.g.dart';

@JsonSerializable()
class ErrorValidation {
  final String message;

  final List<String>? invalidFields;

  ErrorValidation({
    required this.message,
    required this.invalidFields,
  });

  factory ErrorValidation.fromJson(Map<String, dynamic> json) => _$ErrorValidationFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorValidationToJson(this);

  @override
  String toString() {
    return 'ErrorValidation{message: $message, invalidFields: $invalidFields}';
  }
}
