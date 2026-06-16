import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/danmu_comment.dart';

class DanmuLoadResult {
  const DanmuLoadResult({required this.comments, required this.source});

  final List<DanmuComment> comments;
  final Map<String, dynamic> source;
}

/// 对接弹弹play 兼容 API（/api/v2/search/anime 等）。
class DanmuService {
  DanmuService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<DanmuLoadResult?> loadAuto({
    required String danmuBaseUrl,
    required String matchName,
    required int episodeNumber,
    Map<String, dynamic>? cachedSource,
    void Function(Map<String, dynamic> source)? onSourceCached,
  }) async {
    if (danmuBaseUrl.isEmpty) return null;

    if (cachedSource != null &&
        cachedSource['episodeNumber'] == episodeNumber &&
        cachedSource['episodeId'] != null) {
      final episodeId = cachedSource['episodeId'] as int;
      final comments = await _fetchComments(danmuBaseUrl, episodeId);
      if (comments == null) return null;
      return DanmuLoadResult(comments: comments, source: cachedSource);
    }

    return _searchAndLoad(
      danmuBaseUrl,
      matchName,
      episodeNumber,
      onSourceCached,
    );
  }

  Future<DanmuLoadResult?> loadFromSource({
    required String danmuBaseUrl,
    required Map<String, dynamic> source,
  }) async {
    if (danmuBaseUrl.isEmpty) return null;
    final episodeId = source['episodeId'] as int? ?? 0;
    if (episodeId == 0) return null;
    final comments = await _fetchComments(danmuBaseUrl, episodeId);
    if (comments == null) return null;
    return DanmuLoadResult(comments: comments, source: source);
  }

  Future<DanmuLoadResult?> _searchAndLoad(
    String danmuBaseUrl,
    String matchName,
    int episodeNumber,
    void Function(Map<String, dynamic> source)? onSourceCached,
  ) async {
    try {
      final searchResp = await _dio.get<Map<String, dynamic>>(
        '$danmuBaseUrl/api/v2/search/anime',
        queryParameters: {'keyword': matchName},
      );
      if (searchResp.statusCode != 200 || searchResp.data == null) return null;

      final results = _extractList(
        searchResp.data,
        const ['animes', 'data', 'bangumi'],
      );
      if (results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final animeId =
          first['animeId'] ?? first['id'] ?? first['bangumiId'] ?? 0;
      final animeName = first['animeName'] ?? first['name'] ?? matchName;
      if (animeId == 0) return null;

      final bangumiResp = await _dio.get<Map<String, dynamic>>(
        '$danmuBaseUrl/api/v2/bangumi/$animeId',
      );
      if (bangumiResp.statusCode != 200 || bangumiResp.data == null) {
        return null;
      }

      final episodes = _extractEpisodes(bangumiResp.data!);
      if (episodes.isEmpty) return null;

      var episodeId = 0;
      var commentCount = 0;
      if (episodeNumber > 0) {
        for (final ep in episodes) {
          if (ep is! Map) continue;
          if (_parseEpisodeNum(ep) == episodeNumber) {
            episodeId = ep['episodeId'] ?? ep['id'] ?? 0;
            commentCount = ep['commentCount'] ?? 0;
            break;
          }
        }
      }
      if (episodeId == 0) {
        final firstEp = episodes.first as Map<String, dynamic>;
        episodeId = firstEp['episodeId'] ?? firstEp['id'] ?? 0;
        commentCount = firstEp['commentCount'] ?? 0;
      }
      if (episodeId == 0) return null;

      final comments = await _fetchComments(danmuBaseUrl, episodeId);
      if (comments == null) return null;

      final sourceData = {
        'animeId': animeId,
        'animeName': animeName,
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'commentCount':
            commentCount > 0 ? commentCount : comments.length,
      };
      onSourceCached?.call(sourceData);

      return DanmuLoadResult(comments: comments, source: sourceData);
    } catch (e) {
      debugPrint('Danmu search error: $e');
      return null;
    }
  }

  Future<List<DanmuComment>?> _fetchComments(
    String danmuBaseUrl,
    int episodeId,
  ) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$danmuBaseUrl/api/v2/comment/$episodeId',
        queryParameters: {'withRelated': 'true'},
      );
      if (resp.statusCode != 200 || resp.data == null) return null;
      final rawList = _extractList(resp.data, const ['comments', 'data']);
      return _parseComments(rawList);
    } catch (e) {
      debugPrint('Danmu fetch error: $e');
      return null;
    }
  }

  List<DanmuComment> _parseComments(List<dynamic> comments) {
    final danmuList = <DanmuComment>[];
    for (final c in comments) {
      if (c is! Map) continue;
      final parsed = _parseOneComment(Map<String, dynamic>.from(c));
      if (parsed != null) danmuList.add(parsed);
    }
    danmuList.sort((a, b) => a.time.compareTo(b.time));
    return danmuList;
  }

  DanmuComment? _parseOneComment(Map<String, dynamic> c) {
    final text = c['m']?.toString() ??
        c['text']?.toString() ??
        c['content']?.toString() ??
        '';
    if (text.isEmpty) return null;

    var time = 0.0;
    var type = 1;
    var color = 0xFFFFFFFF;

    final p = c['p'];
    if (p is String && p.contains(',')) {
      final parts = p.split(',');
      if (parts.isNotEmpty) time = double.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) type = int.tryParse(parts[1]) ?? 1;
      if (parts.length > 2) color = int.tryParse(parts[2]) ?? 0xFFFFFFFF;
    } else if (p is num) {
      time = p.toDouble();
      if (c['c'] != null) color = _parseColor(c['c']);
    } else {
      time = (c['time'] ?? c['time_point'] ?? 0).toDouble();
      type = (c['type'] as num?)?.toInt() ?? 1;
      if (c['color'] != null) color = _parseColor(c['color']);
    }

    if (color <= 0xFFFFFF) color |= 0xFF000000;
    return DanmuComment(text: text, time: time, color: color, type: type);
  }

  int _parseColor(dynamic cv) {
    if (cv is int) return cv;
    if (cv is String) {
      final s = cv.replaceAll('#', '');
      if (s.length == 6) return int.parse('FF$s', radix: 16);
      if (s.length == 8) return int.parse(s, radix: 16);
      return int.tryParse(cv.replaceAll('#', '0x')) ?? 0xFFFFFFFF;
    }
    return 0xFFFFFFFF;
  }

  List<dynamic> _extractList(dynamic raw, List<String> keys) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final k in keys) {
        if (raw[k] is List) return raw[k] as List;
      }
    }
    return [];
  }

  List<dynamic> _extractEpisodes(Map<String, dynamic> bData) {
    if (bData['bangumi'] is Map) {
      final eps = (bData['bangumi'] as Map)['episodes'];
      if (eps is List) return eps;
    }
    if (bData['episodes'] is List) return bData['episodes'] as List;
    if (bData['data'] is Map) {
      final eps = (bData['data'] as Map)['episodes'];
      if (eps is List) return eps;
    }
    return [];
  }

  int _parseEpisodeNum(Map<dynamic, dynamic> ep) {
    final rawNum = ep['episodeNumber'] ?? ep['episodeIndex'] ?? ep['ep'];
    if (rawNum is int) return rawNum;
    if (rawNum is String) return int.tryParse(rawNum) ?? 0;
    return 0;
  }
}

class DanmuSourceCache {
  DanmuSourceCache(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'danmu_source_cache';

  Map<String, Map<String, dynamic>> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String showName, Map<String, dynamic> data) async {
    final cache = load();
    cache[showName] = data;
    await _prefs.setString(_key, jsonEncode(cache));
  }

  Map<String, dynamic>? get(String showName) => load()[showName];
}
