import 'package:json_annotation/json_annotation.dart';

part 'link_access_request.g.dart';

@JsonSerializable()
class LinkAccessRequest {
  String key;
  String password;

  LinkAccessRequest({
    required this.key,
    required this.password,
  });

  factory LinkAccessRequest.fromJson(Map<String, dynamic> json) => _$LinkAccessRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LinkAccessRequestToJson(this);

  @override
  String toString() {
    return 'LinkAccessRequest{key: $key, password: $password}';
  }
}
