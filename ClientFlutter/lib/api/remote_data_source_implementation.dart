import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:linkso/model/error_detail.dart';
import 'package:linkso/model/error_validation.dart';
import 'package:linkso/model/link_access_request.dart';
import 'package:linkso/model/link_create_request.dart';
import 'package:linkso/model/link_create_response.dart';
import 'package:linkso/model/login_request.dart';
import 'package:linkso/model/register_request.dart';

import 'entity/api_response.dart';
import 'remote_data_source.dart';
import 'rest_client.dart';

class RemoteDataSourceImplementation implements RemoteDataSource {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10).inMilliseconds,
      receiveTimeout: const Duration(minutes: 1).inMilliseconds,
    ),
  )..interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  late RestClient _restClient;

  RemoteDataSourceImplementation() {
    _restClient = RestClient(_dio, baseUrl: "http://localhost:8080/api/");

    // // для отключение SSL сертификата
    // (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
    //   client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    //   return client;
    // };
  }

  @override
  Future<ApiResponse> validateToken(String token) async {
    ErrorValidation? _error;
    try {
      await _restClient.validateToken("Bearer $token");
    } catch (e) {
      _error = _catchErrorDetail(e);
    }

    final bool _successResponse = _error == null;
    return ApiResponse(
      successResponse: _successResponse,
      error: _error,
      data: null,
    );
  }

  @override
  Future<ApiResponse<String>> checkAccess(LinkAccessRequest linkAccessRequest) async {
    ErrorValidation? _error;
    String? _successData;
    try {
      _successData = jsonDecode(await _restClient.checkAccess(linkAccessRequest)) as String;
    } catch (e) {
      _error = _catchErrorValidation(e);
    }

    final bool _successResponse = _error == null;
    return ApiResponse<String>(
      successResponse: _successResponse,
      error: _error,
      data: _successResponse ? _successData : null,
    );
  }

  @override
  Future<ApiResponse<LinkCreateResponse>> createLink(LinkCreateRequest link) async {
    ErrorValidation? _error;
    LinkCreateResponse? _successData;
    try {
      _successData = await _restClient.createLink(link);
    } catch (e) {
      _error = _catchErrorDetail(e);
    }

    final bool _successResponse = _error == null;
    return ApiResponse<LinkCreateResponse>(
      successResponse: _successResponse,
      error: _error,
      data: _successResponse ? _successData : null,
    );
  }

  @override
  Future<ApiResponse> deleteLink(String key) async {
    ErrorValidation? _error;
    dynamic _successData;
    try {
      _successData = await _restClient.deleteLink(key);
    } catch (e) {
      _error = _catchErrorDetail(e);
    }

    final bool _successResponse = _error == null;
    return ApiResponse(
      successResponse: _successResponse,
      error: _error,
      data: _successResponse ? _successData : null,
    );
  }

  @override
  Future<ApiResponse<String>> login(LoginRequest loginRequest) async {
    ErrorValidation? _error;
    String? _successData;
    try {
      _successData = jsonDecode(await _restClient.login(loginRequest)) as String;
    } catch (e) {
      _error = _catchErrorValidation(e);
    }

    final bool _successResponse = _error == null;
    return ApiResponse<String>(
      successResponse: _successResponse,
      error: _error,
      data: _successResponse ? _successData : null,
    );
  }

  @override
  Future<ApiResponse<String>> register(RegisterRequest registerRequest) async {
    ErrorValidation? _error;
    String? _successData;
    try {
      _successData = jsonDecode(await _restClient.register(registerRequest)) as String;
    } catch (e) {
      _error = _catchErrorValidation(e);
    }

    final bool _successResponse = _error == null;
    return ApiResponse<String>(
      successResponse: _successResponse,
      error: _error,
      data: _successResponse ? _successData : null,
    );
  }

  ErrorValidation? _catchErrorValidation(Object object) {
    if (object is DioError) {
      final _response = object.response;
      switch (_response?.statusCode) {
        case 400:
          return ErrorValidation.fromJson(jsonDecode(_response?.data as String) as Map<String, dynamic>);
        case 403:
        default:
          return ErrorDetail.fromJson(jsonDecode(_response?.data as String) as Map<String, dynamic>);
      }
    } else {
      print(object);
      return null;
    }
  }

  ErrorDetail? _catchErrorDetail(Object object) {
    if (object is DioError) {
      final _response = object.response;
      return ErrorDetail.fromJson(_response?.data as Map<String, dynamic>);
    } else {
      print(object);
      return null;
    }
  }
}
