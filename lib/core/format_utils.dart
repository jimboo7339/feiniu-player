String formatDuration(int seconds, {bool showHours = false}) {
  if (seconds <= 0) return '0:00';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0 || showHours) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatDurationFromDuration(Duration d) =>
    formatDuration(d.inSeconds, showHours: d.inHours > 0);

double watchProgress(int watchedSeconds, int durationSeconds) {
  if (watchedSeconds <= 0 || durationSeconds <= 0) return 0;
  return (watchedSeconds / durationSeconds).clamp(0.0, 1.0);
}
