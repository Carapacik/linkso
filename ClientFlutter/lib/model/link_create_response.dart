import 'package:json_annotation/json_annotation.dart';

part 'link_create_response.g.dart';

@JsonSerializable()
class LinkCreateResponse {
  final String key;
  final String target;
  final int linkType;

  LinkCreateResponse({
    required this.key,
    required this.target,
    this.linkType = 0,
  });

  factory LinkCreateResponse.fromJson(Map<String, dynamic> json) => _$LinkCreateResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LinkCreateResponseToJson(this);

  @override
  String toString() {
    return 'LinkCreateResponse{key: $key, target: $target, linkType: $linkType}';
  }
}
