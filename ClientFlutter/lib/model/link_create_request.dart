import 'package:json_annotation/json_annotation.dart';

part 'link_create_request.g.dart';

@JsonSerializable()
class LinkCreateRequest {
  String target;
  int linkType;
  String? password;

  LinkCreateRequest({
    required this.target,
    this.linkType = 0,
    this.password,
  });

  factory LinkCreateRequest.fromJson(Map<String, dynamic> json) => _$LinkCreateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LinkCreateRequestToJson(this);

  @override
  String toString() {
    return 'LinkCreateRequest{target: $target, linkType: $linkType, password: $password}';
  }
}
