import 'package:dio/dio.dart';
import 'package:linkso/model/link_access_request.dart';
import 'package:linkso/model/link_create_request.dart';
import 'package:linkso/model/link_create_response.dart';
import 'package:linkso/model/login_request.dart';
import 'package:linkso/model/register_request.dart';
import 'package:retrofit/retrofit.dart';

part 'rest_client.g.dart';

@RestApi()
abstract class RestClient {
  factory RestClient(Dio dio, {String baseUrl}) = _RestClient;

  @POST("linkmanager/create")
  Future<LinkCreateResponse> createLink(@Body() LinkCreateRequest link);

  @DELETE("linkmanager/delete")
  Future deleteLink(@Body() String key);

  @POST("link/access")
  Future<String> checkAccess(@Body() LinkAccessRequest linkAccessRequest);

  @POST("user/register")
  Future<String> register(@Body() RegisterRequest registerRequest);

  @POST("user/login")
  Future<String> login(@Body() LoginRequest loginRequest);

  @GET("user/validateCredentials")
  Future validateToken(@Header("Authorization") String token);
}
