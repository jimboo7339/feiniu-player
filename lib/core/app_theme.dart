import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF1DB954);
  static const _surface = Color(0xFF0D0D0D);
  static const _card = Color(0xFF1A1A1A);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: _surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _surface,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: _card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _seed,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: _seed,
        inactiveTrackColor: Colors.white24,
        thumbColor: _seed,
      ),
      chipTheme: ChipThemeData(
        selectedColor: _seed.withAlpha(60),
        checkmarkColor: _seed,
        side: BorderSide(color: Colors.white.withAlpha(40)),
        labelStyle: const TextStyle(color: Colors.white),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withAlpha(20)),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
    );
  }
}
