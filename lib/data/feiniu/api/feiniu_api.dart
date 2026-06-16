import 'package:dio/dio.dart';

import '../auth/fn_auth_utils.dart';
import '../http/fn_dio_client.dart';
import '../../../core/feiniu_constants.dart';

class FeiniuApiException implements Exception {
  FeiniuApiException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => 'FeiniuApiException($code): $message';
}

/// HTTP API wrapper for Feiniu media (v0.9.x).
class FeiniuApi {
  FeiniuApi({FnDioClient? client}) : _client = client ?? FnDioClient();

  final FnDioClient _client;

  FnDioClient get client => _client;

  void configure({required String host, String? token}) {
    _client.updateBaseUrl(host);
    if (token != null) {
      _client.setToken(token);
    }
  }

  Future<String> login(String username, String password) async {
    try {
      return await _loginV1(username, password);
    } on FeiniuApiException {
      return _loginV2(username, password);
    }
  }

  Future<String> _loginV1(String username, String password) async {
    final body = {
      'app_name': FeiniuConstants.appName,
      'username': username,
      'password': password,
      'nonce': FnAuthUtils.generateNonce(),
    };
    final data = await _post('api/v1/login', body);
    return _extractToken(data);
  }

  Future<String> _loginV2(String username, String password) async {
    final body = {
      'username': username,
      'password': FnAuthUtils.sha256Hex(password),
      'app_name': FeiniuConstants.appName,
    };
    final data = await _post('api/v2/user/loginByPassword', body);
    return _extractToken(data);
  }

  String _extractToken(Map<String, dynamic> data) {
    final code = data['code'] as int? ?? -1;
    if (code != 0) {
      throw FeiniuApiException(
        data['msg']?.toString() ?? '登录失败',
        code: code,
      );
    }
    final token = data['data']?['token']?.toString();
    if (token == null || token.isEmpty) {
      throw FeiniuApiException('登录响应缺少 token');
    }
    _client.setToken(token);
    return token;
  }

  Future<Map<String, dynamic>> getSysVersion() async {
    return _get('api/v1/sys/version');
  }

  Future<Map<String, dynamic>> getUserInfo() async {
    return _get('api/v1/user/info');
  }

  Future<List<Map<String, dynamic>>> getMediaDbList() async {
    final data = await _get('api/v1/mediadb/list');
    final list = data['data'];
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getItemList({
    required String ancestorGuid,
    int page = 1,
    int pageSize = 30,
    Map<String, dynamic>? tags,
    String sortColumn = 'release_date',
    String sortType = 'DESC',
  }) async {
    return _post('api/v1/item/list', {
      'ancestor_guid': ancestorGuid,
      'tags': tags ??
          {
            'type': ['Movie', 'TV', 'Directory', 'Video'],
          },
      'exclude_grouped_video': 1,
      'sort_type': sortType,
      'sort_column': sortColumn,
      'page': page,
      'page_size': pageSize,
    });
  }

  Future<Map<String, dynamic>> getItemDetail(String guid) async {
    return _get('api/v1/item/$guid');
  }

  Future<List<Map<String, dynamic>>> getSeasonList(String tvGuid) async {
    final data = await _get('api/v1/season/list/$tvGuid');
    return _asList(data['data']);
  }

  Future<List<Map<String, dynamic>>> getEpisodeList(String seasonGuid) async {
    final data = await _get('api/v1/episode/list/$seasonGuid');
    return _asList(data['data']);
  }

  Future<Map<String, dynamic>> getPlayInfo(String itemGuid) async {
    return _post('api/v1/play/info', {'item_guid': itemGuid});
  }

  Future<Map<String, dynamic>> getStream({
    required String mediaGuid,
    required String username,
    int level = 1,
  }) async {
    return _post('api/v1/stream', {
      'media_guid': mediaGuid,
      'ip': FnAuthUtils.accountMd5(username),
      'level': level,
      'header': {
        'User-Agent': [
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ],
      },
      'nonce': FnAuthUtils.generateNonce(),
    });
  }

  Future<List<Map<String, dynamic>>> getPlayList() async {
    final data = await _get('api/v1/play/list');
    return _asList(data['data']);
  }

  Future<void> recordPlayStatus(Map<String, dynamic> body) async {
    await _post('api/v1/play/record', body);
  }

  Future<Map<String, dynamic>> getTagList({String? ancestorGuid}) async {
    return _get(
      'api/v1/tag/list',
      queryParameters:
          ancestorGuid == null ? null : {'ancestor_guid': ancestorGuid},
    );
  }

  String mediaRangeUrl(String mediaGuid, {int? qualityIndex}) {
    final base = '${_client.baseUrl}/v/api/v1/media/range/$mediaGuid';
    if (qualityIndex != null) {
      return '$base?direct_link_quality_index=$qualityIndex';
    }
    return base;
  }

  String imageUrl(String? path, {int width = 400}) {
    if (path == null || path.isEmpty) return '';
    final p = path.startsWith('/') ? path : '/$path';
    return '${_client.baseUrl}/v/api/v1/sys/img$p?w=$width';
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final resp = await _client.dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return _unwrap(resp);
    } on DioException catch (e) {
      throw FeiniuApiException(e.message ?? '网络请求失败');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await _client.dio.post<Map<String, dynamic>>(path, data: body);
      return _unwrap(resp);
    } on DioException catch (e) {
      throw FeiniuApiException(e.message ?? '网络请求失败');
    }
  }

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> resp) {
    final data = resp.data;
    if (data == null) {
      throw FeiniuApiException('空响应');
    }
    final code = data['code'] as int? ?? -1;
    if (code != 0) {
      throw FeiniuApiException(
        data['msg']?.toString() ?? '请求失败',
        code: code,
      );
    }
    return data;
  }
}
