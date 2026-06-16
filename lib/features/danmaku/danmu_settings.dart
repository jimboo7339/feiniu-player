import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/danmu_service.dart';

final danmuServiceProvider = Provider<DanmuService>((ref) => DanmuService());

class DanmuSettingsState {
  const DanmuSettingsState({
    this.loaded = false,
    this.danmuUrl = '',
    this.enabled = true,
    this.opacity = 0.85,
    this.fontSize = 22,
    this.areaPercent = 35,
    this.speed = 0.6,
    this.showScroll = true,
    this.showTop = true,
    this.showBottom = true,
    this.showOutline = true,
  });

  final bool loaded;
  final String danmuUrl;
  final bool enabled;
  final double opacity;
  final double fontSize;
  final int areaPercent;
  final double speed;
  final bool showScroll;
  final bool showTop;
  final bool showBottom;
  final bool showOutline;

  DanmuSettingsState copyWith({
    bool? loaded,
    String? danmuUrl,
    bool? enabled,
    double? opacity,
    double? fontSize,
    int? areaPercent,
    double? speed,
    bool? showScroll,
    bool? showTop,
    bool? showBottom,
    bool? showOutline,
  }) {
    return DanmuSettingsState(
      loaded: loaded ?? this.loaded,
      danmuUrl: danmuUrl ?? this.danmuUrl,
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      areaPercent: areaPercent ?? this.areaPercent,
      speed: speed ?? this.speed,
      showScroll: showScroll ?? this.showScroll,
      showTop: showTop ?? this.showTop,
      showBottom: showBottom ?? this.showBottom,
      showOutline: showOutline ?? this.showOutline,
    );
  }
}

final danmuSettingsProvider =
    NotifierProvider<DanmuSettingsNotifier, DanmuSettingsState>(
  DanmuSettingsNotifier.new,
);

class DanmuSettingsNotifier extends Notifier<DanmuSettingsState> {
  SharedPreferences? _prefs;
  DanmuSourceCache? _cache;

  @override
  DanmuSettingsState build() {
    Future.microtask(_load);
    return const DanmuSettingsState();
  }

  DanmuSourceCache? get sourceCache {
    if (_prefs == null) return null;
    _cache ??= DanmuSourceCache(_prefs!);
    return _cache;
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _cache = DanmuSourceCache(_prefs!);
    state = DanmuSettingsState(
      loaded: true,
      danmuUrl: _prefs!.getString('danmu_url') ?? '',
      enabled: _prefs!.getBool('danmu_on') ?? true,
      opacity: _prefs!.getDouble('danmu_opacity') ?? 0.85,
      fontSize: _prefs!.getDouble('danmu_fontsize') ?? 22,
      areaPercent: _prefs!.getInt('danmu_area') ?? 35,
      speed: _prefs!.getDouble('danmu_speed') ?? 0.6,
      showScroll: _prefs!.getBool('danmu_scroll') ?? true,
      showTop: _prefs!.getBool('danmu_top') ?? true,
      showBottom: _prefs!.getBool('danmu_bottom') ?? true,
      showOutline: _prefs!.getBool('danmu_outline') ?? true,
    );
  }

  Future<void> setDanmuUrl(String url) async {
    await _prefs?.setString('danmu_url', url.trim());
    state = state.copyWith(danmuUrl: url.trim());
  }

  Future<void> setEnabled(bool v) async {
    await _prefs?.setBool('danmu_on', v);
    state = state.copyWith(enabled: v);
  }

  Future<void> setOpacity(double v) async {
    await _prefs?.setDouble('danmu_opacity', v);
    state = state.copyWith(opacity: v);
  }

  Future<void> setFontSize(double v) async {
    await _prefs?.setDouble('danmu_fontsize', v);
    state = state.copyWith(fontSize: v);
  }

  Future<void> setAreaPercent(int v) async {
    await _prefs?.setInt('danmu_area', v);
    state = state.copyWith(areaPercent: v);
  }

  Future<void> setSpeed(double v) async {
    await _prefs?.setDouble('danmu_speed', v);
    state = state.copyWith(speed: v);
  }
}
