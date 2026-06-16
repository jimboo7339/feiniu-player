import '../api/feiniu_api.dart';
import '../models/stream_models.dart';

class PlaybackRepository {
  PlaybackRepository(this._api);

  final FeiniuApi _api;

  Future<PlayInfoData> loadPlayInfo(String itemGuid) async {
    final resp = await _api.getPlayInfo(itemGuid);
    return PlayInfoData.fromJson(itemGuid, resp['data'] as Map<String, dynamic>);
  }

  Future<PlaybackSession> preparePlayback({
    required PlayInfoData playInfo,
    required String username,
    int qualityIndex = 0,
  }) async {
    final streamResp = await _api.getStream(
      mediaGuid: playInfo.mediaGuid,
      username: username,
    );
    final data = streamResp['data'] as Map<String, dynamic>? ?? {};

    final fileStream = data['file_stream'] as Map<String, dynamic>? ?? {};
    final path = fileStream['path']?.toString() ?? '';
    final fileName = fileStream['file_name']?.toString() ?? '';
    final isStrm = path.toLowerCase().endsWith('.strm') ||
        fileName.toLowerCase().endsWith('.strm');

    final qualities = ((data['direct_link_qualities'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StreamQuality.fromJson)
        .where((q) => q.url != null && q.url!.isNotEmpty)
        .toList();

    final subtitles = ((data['subtitle_streams'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StreamSubtitle.fromJson)
        .toList();

    final audios = ((data['audio_streams'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StreamAudio.fromJson)
        .toList();

    String playUrl;
    if (qualities.isNotEmpty) {
      final idx = qualityIndex.clamp(0, qualities.length - 1);
      playUrl = qualities[idx].url!;
    } else {
      playUrl = _api.mediaRangeUrl(
        playInfo.mediaGuid,
        qualityIndex: qualityIndex > 0 ? qualityIndex : null,
      );
    }

    final duration = (fileStream['duration'] as num?)?.toInt() ??
        ((data['video_stream'] as Map<String, dynamic>?)?['duration'] as num?)
            ?.toInt() ??
        0;

    return PlaybackSession(
      itemGuid: playInfo.itemGuid,
      mediaGuid: playInfo.mediaGuid,
      videoGuid: playInfo.videoGuid,
      audioGuid: playInfo.audioGuid,
      subtitleGuid: playInfo.subtitleGuid,
      playUrl: playUrl,
      isStrm: isStrm,
      seekSeconds: playInfo.seekSeconds,
      durationSeconds: duration,
      title: playInfo.title,
      subtitle: playInfo.subtitle,
      qualities: qualities,
      subtitles: subtitles,
      audios: audios,
    );
  }

  Future<void> reportProgress({
    required PlaybackSession session,
    required int positionSeconds,
    required int durationSeconds,
    String resolution = '原画',
  }) async {
    if (session.itemGuid.isEmpty || session.mediaGuid.isEmpty) return;
    await _api.recordPlayStatus({
      'item_guid': session.itemGuid,
      'media_guid': session.mediaGuid,
      if (session.videoGuid != null) 'video_guid': session.videoGuid,
      if (session.audioGuid != null) 'audio_guid': session.audioGuid,
      if (session.subtitleGuid != null) 'subtitle_guid': session.subtitleGuid,
      'resolution': resolution,
      'bitrate': 0,
      'ts': positionSeconds,
      'duration': durationSeconds > 0 ? durationSeconds : session.durationSeconds,
    });
  }
}
