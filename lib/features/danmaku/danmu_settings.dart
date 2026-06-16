import 'package:flutter/material.dart';
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
    this.topOffsetPercent = 0,
    this.speed = 0.6,
    this.showScroll = true,
    this.showTop = true,
    this.showBottom = true,
    this.showOutline = true,
    this.mergeDuplicates = true,
    this.withRelated = true,
  });

  final bool loaded;
  final String danmuUrl;
  final bool enabled;
  final double opacity;
  final double fontSize;
  final int areaPercent;
  final int topOffsetPercent;
  final double speed;
  final bool showScroll;
  final bool showTop;
  final bool showBottom;
  final bool showOutline;
  final bool mergeDuplicates;
  final bool withRelated;

  DanmuSettingsState copyWith({
    bool? loaded,
    String? danmuUrl,
    bool? enabled,
    double? opacity,
    double? fontSize,
    int? areaPercent,
    int? topOffsetPercent,
    double? speed,
    bool? showScroll,
    bool? showTop,
    bool? showBottom,
    bool? showOutline,
    bool? mergeDuplicates,
    bool? withRelated,
  }) {
    return DanmuSettingsState(
      loaded: loaded ?? this.loaded,
      danmuUrl: danmuUrl ?? this.danmuUrl,
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      areaPercent: areaPercent ?? this.areaPercent,
      topOffsetPercent: topOffsetPercent ?? this.topOffsetPercent,
      speed: speed ?? this.speed,
      showScroll: showScroll ?? this.showScroll,
      showTop: showTop ?? this.showTop,
      showBottom: showBottom ?? this.showBottom,
      showOutline: showOutline ?? this.showOutline,
      mergeDuplicates: mergeDuplicates ?? this.mergeDuplicates,
      withRelated: withRelated ?? this.withRelated,
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
      danmuUrl: _prefs!.getString('danmu_url') ??
          'http://192.168.100.10:9321/87654321',
      enabled: _prefs!.getBool('danmu_on') ?? true,
      opacity: _prefs!.getDouble('danmu_opacity') ?? 0.85,
      fontSize: _prefs!.getDouble('danmu_fontsize') ?? 22,
      areaPercent: _prefs!.getInt('danmu_area') ?? 35,
      topOffsetPercent: _prefs!.getInt('danmu_top_offset') ?? 0,
      speed: _prefs!.getDouble('danmu_speed') ?? 0.6,
      showScroll: _prefs!.getBool('danmu_scroll') ?? true,
      showTop: _prefs!.getBool('danmu_top') ?? true,
      showBottom: _prefs!.getBool('danmu_bottom') ?? true,
      showOutline: _prefs!.getBool('danmu_outline') ?? true,
      mergeDuplicates: _prefs!.getBool('danmu_merge') ?? true,
      withRelated: _prefs!.getBool('danmu_related') ?? true,
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

  Future<void> setTopOffsetPercent(int v) async {
    await _prefs?.setInt('danmu_top_offset', v);
    state = state.copyWith(topOffsetPercent: v);
  }

  Future<void> setSpeed(double v) async {
    await _prefs?.setDouble('danmu_speed', v);
    state = state.copyWith(speed: v);
  }

  Future<void> setShowScroll(bool v) async {
    await _prefs?.setBool('danmu_scroll', v);
    state = state.copyWith(showScroll: v);
  }

  Future<void> setShowTop(bool v) async {
    await _prefs?.setBool('danmu_top', v);
    state = state.copyWith(showTop: v);
  }

  Future<void> setShowBottom(bool v) async {
    await _prefs?.setBool('danmu_bottom', v);
    state = state.copyWith(showBottom: v);
  }

  Future<void> setShowOutline(bool v) async {
    await _prefs?.setBool('danmu_outline', v);
    state = state.copyWith(showOutline: v);
  }

  Future<void> setMergeDuplicates(bool v) async {
    await _prefs?.setBool('danmu_merge', v);
    state = state.copyWith(mergeDuplicates: v);
  }

  Future<void> setWithRelated(bool v) async {
    await _prefs?.setBool('danmu_related', v);
    state = state.copyWith(withRelated: v);
  }
}

/// 通用设置区块标题
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
        ],
      ),
    );
  }
}

/// 带标签的滑块设置项
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(displayValue ?? label),
      subtitle: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}
