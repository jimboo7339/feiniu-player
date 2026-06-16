class StreamQuality {
  const StreamQuality({this.resolution, this.url});

  factory StreamQuality.fromJson(Map<String, dynamic> json) {
    return StreamQuality(
      resolution: json['resolution']?.toString(),
      url: json['url']?.toString().replaceAll(r'\u0026', '&'),
    );
  }

  final String? resolution;
  final String? url;
}

class StreamSubtitle {
  const StreamSubtitle({
    this.guid,
    this.codecName,
    this.language,
    this.index = 0,
    this.title,
  });

  factory StreamSubtitle.fromJson(Map<String, dynamic> json) {
    return StreamSubtitle(
      guid: json['guid']?.toString(),
      codecName: json['codec_name']?.toString(),
      language: json['language']?.toString(),
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
    );
  }

  final String? guid;
  final String? codecName;
  final String? language;
  final int index;
  final String? title;

  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    if (language != null && language!.isNotEmpty && language != 'und') {
      return language!;
    }
    return '字幕 ${index + 1}';
  }
}

class StreamAudio {
  const StreamAudio({
    this.codecName,
    this.language,
    this.index = 0,
    this.title,
    this.channels,
  });

  factory StreamAudio.fromJson(Map<String, dynamic> json) {
    return StreamAudio(
      codecName: json['codec_name']?.toString(),
      language: json['language']?.toString(),
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
      channels: (json['channels'] as num?)?.toInt(),
    );
  }

  final String? codecName;
  final String? language;
  final int index;
  final String? title;
  final int? channels;

  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    if (language != null && language!.isNotEmpty && language != 'und') {
      return language!;
    }
    return '音轨 ${index + 1}';
  }
}

class PlaybackSession {
  const PlaybackSession({
    required this.itemGuid,
    required this.mediaGuid,
    required this.playUrl,
    this.videoGuid,
    this.audioGuid,
    this.subtitleGuid,
    this.isStrm = false,
    this.seekSeconds = 0,
    this.durationSeconds = 0,
    this.title = '',
    this.subtitle = '',
    this.qualities = const [],
    this.subtitles = const [],
    this.audios = const [],
  });

  final String itemGuid;
  final String mediaGuid;
  final String? videoGuid;
  final String? audioGuid;
  final String? subtitleGuid;
  final String playUrl;
  final bool isStrm;
  final int seekSeconds;
  final int durationSeconds;
  final String title;
  final String subtitle;
  final List<StreamQuality> qualities;
  final List<StreamSubtitle> subtitles;
  final List<StreamAudio> audios;
}

class PlayInfoData {
  const PlayInfoData({
    required this.itemGuid,
    required this.mediaGuid,
    this.videoGuid,
    this.audioGuid,
    this.subtitleGuid,
    this.seekSeconds = 0,
    this.title = '',
    this.subtitle = '',
    this.type = '',
    this.parentGuid,
    this.episodeNumber = 0,
  });

  factory PlayInfoData.fromJson(String itemGuid, Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>? ?? {};
    final tvTitle = item['tv_title']?.toString() ?? '';
    return PlayInfoData(
      itemGuid: itemGuid,
      mediaGuid: json['media_guid']?.toString() ?? '',
      videoGuid: json['video_guid']?.toString(),
      audioGuid: json['audio_guid']?.toString(),
      subtitleGuid: json['subtitle_guid']?.toString(),
      seekSeconds: (json['ts'] as num?)?.toInt() ?? 0,
      title: item['title']?.toString() ?? '',
      subtitle: tvTitle.isNotEmpty
          ? tvTitle
          : item['parent_title']?.toString() ?? '',
      type: json['type']?.toString() ?? item['type']?.toString() ?? '',
      parentGuid: json['parent_guid']?.toString(),
      episodeNumber: (item['episode_number'] as num?)?.toInt() ??
          (json['episode_number'] as num?)?.toInt() ??
          0,
    );
  }

  /// 弹幕搜索用的剧名：优先 tv_title，否则 title。
  String get matchName {
    if (subtitle.isNotEmpty && type == 'Episode') return subtitle;
    return title;
  }

  final String itemGuid;
  final String mediaGuid;
  final String? videoGuid;
  final String? audioGuid;
  final String? subtitleGuid;
  final int seekSeconds;
  final String title;
  final String subtitle;
  final String type;
  final String? parentGuid;
  final int episodeNumber;
}
