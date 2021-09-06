import 'package:json_annotation/json_annotation.dart';

part 'register_request.g.dart';

@JsonSerializable()
class RegisterRequest {
  String login;
  String password;
  String email;

  RegisterRequest({
    required this.login,
    required this.password,
    required this.email,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);

  @override
  String toString() {
    return 'RegisterRequest{login: $login, password: $password, email: $email}';
  }
}
