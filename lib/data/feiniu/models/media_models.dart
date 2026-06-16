class MediaItem {
  const MediaItem({
    required this.guid,
    required this.title,
    required this.type,
    this.poster,
    this.watchedTs = 0,
    this.releaseDate,
    this.voteAverage,
    this.ancestorName,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      guid: json['guid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      poster: json['poster']?.toString(),
      watchedTs: (json['watched_ts'] as num?)?.toInt() ??
          (json['ts'] as num?)?.toInt() ??
          0,
      releaseDate: json['release_date']?.toString(),
      voteAverage: json['vote_average']?.toString(),
      ancestorName: json['ancestor_name']?.toString(),
    );
  }

  final String guid;
  final String title;
  final String type;
  final String? poster;
  final int watchedTs;
  final String? releaseDate;
  final String? voteAverage;
  final String? ancestorName;
}

class MediaLibrary {
  const MediaLibrary({
    required this.guid,
    required this.title,
    required this.category,
  });

  factory MediaLibrary.fromJson(Map<String, dynamic> json) {
    return MediaLibrary(
      guid: json['guid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
    );
  }

  final String guid;
  final String title;
  final String category;
}

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.host,
    required this.username,
    this.token = '',
    this.label,
  });

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      label: json['label']?.toString(),
    );
  }

  String get displayLabel => label ?? '$username@${_shortHost(host)}';

  static String _shortHost(String host) {
    var h = host.replaceAll(RegExp(r'^https?://'), '');
    h = h.replaceAll(RegExp(r':\d+$'), '');
    return h;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'host': host,
        'username': username,
        'label': label,
      };

  final String id;
  final String host;
  final String username;
  final String token;
  final String? label;
}
