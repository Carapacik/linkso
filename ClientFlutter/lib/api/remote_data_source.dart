import 'package:linkso/model/link_access_request.dart';
import 'package:linkso/model/link_create_request.dart';
import 'package:linkso/model/link_create_response.dart';
import 'package:linkso/model/login_request.dart';
import 'package:linkso/model/register_request.dart';

import 'entity/api_response.dart';

abstract class RemoteDataSource {
  Future<ApiResponse<LinkCreateResponse>> createLink(LinkCreateRequest link);

  Future<ApiResponse> deleteLink(String key);

  Future<ApiResponse<String>> checkAccess(LinkAccessRequest linkAccessRequest);

  Future<ApiResponse<String>> register(RegisterRequest registerRequest);

  Future<ApiResponse<String>> login(LoginRequest loginRequest);

  Future<ApiResponse> validateToken(String token);
}
