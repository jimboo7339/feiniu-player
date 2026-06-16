import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubtitleSettingsState {
  const SubtitleSettingsState({
    this.loaded = false,
    this.fontSize = 28,
    this.bottomOffset = 48,
    this.backgroundOpacity = 0.65,
    this.textColor = 0xFFFFFFFF,
    this.bold = false,
    this.position = SubtitlePosition.bottom,
  });

  final bool loaded;
  final double fontSize;
  final double bottomOffset;
  final double backgroundOpacity;
  final int textColor;
  final bool bold;
  final SubtitlePosition position;

  SubtitleSettingsState copyWith({
    bool? loaded,
    double? fontSize,
    double? bottomOffset,
    double? backgroundOpacity,
    int? textColor,
    bool? bold,
    SubtitlePosition? position,
  }) {
    return SubtitleSettingsState(
      loaded: loaded ?? this.loaded,
      fontSize: fontSize ?? this.fontSize,
      bottomOffset: bottomOffset ?? this.bottomOffset,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      textColor: textColor ?? this.textColor,
      bold: bold ?? this.bold,
      position: position ?? this.position,
    );
  }

  SubtitleViewStyle toViewStyle() {
    final color = Color(textColor);
    return SubtitleViewStyle(
      fontSize: fontSize,
      bottomOffset: bottomOffset,
      backgroundOpacity: backgroundOpacity,
      color: color,
      bold: bold,
      position: position,
    );
  }
}

enum SubtitlePosition { bottom, lowerThird, center }

class SubtitleViewStyle {
  const SubtitleViewStyle({
    required this.fontSize,
    required this.bottomOffset,
    required this.backgroundOpacity,
    required this.color,
    required this.bold,
    required this.position,
  });

  final double fontSize;
  final double bottomOffset;
  final double backgroundOpacity;
  final Color color;
  final bool bold;
  final SubtitlePosition position;
}

final subtitleSettingsProvider =
    NotifierProvider<SubtitleSettingsNotifier, SubtitleSettingsState>(
  SubtitleSettingsNotifier.new,
);

class SubtitleSettingsNotifier extends Notifier<SubtitleSettingsState> {
  SharedPreferences? _prefs;

  @override
  SubtitleSettingsState build() {
    Future.microtask(_load);
    return const SubtitleSettingsState();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final posIndex = _prefs!.getInt('sub_position') ?? 0;
    state = SubtitleSettingsState(
      loaded: true,
      fontSize: _prefs!.getDouble('sub_fontsize') ?? 28,
      bottomOffset: _prefs!.getDouble('sub_bottom_offset') ?? 48,
      backgroundOpacity: _prefs!.getDouble('sub_bg_opacity') ?? 0.65,
      textColor: _prefs!.getInt('sub_text_color') ?? 0xFFFFFFFF,
      bold: _prefs!.getBool('sub_bold') ?? false,
      position: SubtitlePosition.values[posIndex.clamp(0, 2)],
    );
  }

  Future<void> setFontSize(double v) async {
    await _prefs?.setDouble('sub_fontsize', v);
    state = state.copyWith(fontSize: v);
  }

  Future<void> setBottomOffset(double v) async {
    await _prefs?.setDouble('sub_bottom_offset', v);
    state = state.copyWith(bottomOffset: v);
  }

  Future<void> setBackgroundOpacity(double v) async {
    await _prefs?.setDouble('sub_bg_opacity', v);
    state = state.copyWith(backgroundOpacity: v);
  }

  Future<void> setBold(bool v) async {
    await _prefs?.setBool('sub_bold', v);
    state = state.copyWith(bold: v);
  }

  Future<void> setPosition(SubtitlePosition v) async {
    await _prefs?.setInt('sub_position', v.index);
    state = state.copyWith(position: v);
  }
}
