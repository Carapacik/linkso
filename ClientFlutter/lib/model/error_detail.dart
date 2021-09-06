import 'package:json_annotation/json_annotation.dart';
import 'package:linkso/model/error_validation.dart';

part 'error_detail.g.dart';

@JsonSerializable()
class ErrorDetail extends ErrorValidation {
  @override
  final String message;

  ErrorDetail({
    required this.message,
  }) : super(message: message, invalidFields: null);

  factory ErrorDetail.fromJson(Map<String, dynamic> json) => _$ErrorDetailFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ErrorDetailToJson(this);

  @override
  String toString() {
    return 'ErrorDetail{message: $message}';
  }
}
