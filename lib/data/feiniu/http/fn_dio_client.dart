import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/feiniu_constants.dart';
import '../auth/fn_auth_utils.dart';

/// Dio client with Authx signing for Feiniu media API.
class FnDioClient {
  FnDioClient({Dio? dio}) : _dio = dio ?? Dio(_baseOptions) {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest),
    );
  }

  static final _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json, text/plain, */*'},
  );

  final Dio _dio;
  String _baseUrl = '';
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  Dio get dio => _dio;

  void updateBaseUrl(String host) {
    var url = host.trim().replaceAll(RegExp(r'/+$'), '');
    final vIdx = url.indexOf('/v');
    if (vIdx != -1) {
      url = url.substring(0, vIdx);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    _baseUrl = url;
    _dio.options.baseUrl = '$_baseUrl/v/';
  }

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get authHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Cookie': FeiniuConstants.relayCookie,
    };
    if (_token != null) {
      headers['Authorization'] = _token!;
    }
    return headers;
  }

  Map<String, String> get imageHeaders {
    final headers = Map<String, String>.from(authHeaders);
    headers['Authx'] = FnAuthUtils.genAuthx('/v/api/v1/sys/img', null);
    return headers;
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    final urlPath = uri.path;
    String? bodyStr;
    if (options.data != null) {
      bodyStr = options.data is String
          ? options.data as String
          : jsonEncode(options.data);
    }
    options.headers['Authx'] = FnAuthUtils.genAuthx(urlPath, bodyStr);
    options.headers['Cookie'] = FeiniuConstants.relayCookie;
    if (_token != null) {
      options.headers['Authorization'] = _token;
    }
    if (options.extra['noContentType'] == true) {
      options.headers.remove('Content-Type');
    } else if (options.method != 'GET') {
      options.headers['Content-Type'] = 'application/json';
    }
    handler.next(options);
  }
}
