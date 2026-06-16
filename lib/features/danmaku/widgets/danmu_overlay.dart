import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/danmu_comment.dart';

/// 弹幕覆盖层，与播放进度/倍速同步。
class DanmuOverlay extends StatefulWidget {
  const DanmuOverlay({
    super.key,
    required this.comments,
    required this.getCurrentTime,
    this.positionListenable,
    this.isPlaying = true,
    this.playbackSpeed = 1.0,
    this.opacity = 0.85,
    this.fontSize = 22,
    this.areaPercent = 35,
    this.showOutline = true,
    this.speed = 0.6,
    this.topMargin = 0,
    this.topOffsetPercent = 0,
    this.mergeDuplicates = true,
    this.showScroll = true,
    this.showTop = true,
    this.showBottom = true,
  });

  final List<DanmuComment> comments;
  final Duration Function() getCurrentTime;
  final Listenable? positionListenable;
  final bool isPlaying;
  final double playbackSpeed;
  final double opacity;
  final double fontSize;
  final int areaPercent;
  final bool showOutline;
  final double speed;
  final double topMargin;
  final int topOffsetPercent;
  final bool mergeDuplicates;
  final bool showScroll;
  final bool showTop;
  final bool showBottom;

  @override
  State<DanmuOverlay> createState() => _DanmuOverlayState();
}

class _DanmuOverlayState extends State<DanmuOverlay>
    with SingleTickerProviderStateMixin {
  static const _maxActiveScroll = 120;

  late AnimationController _animCtrl;
  final List<_DanmuItem> _activeScroll = [];
  final List<_DanmuItem> _activeStatic = [];
  final Set<int> _firedKeys = {};
  final Map<String, _DanmuParagraphs> _paragraphCache = {};

  Size _size = Size.zero;
  int _lastCommentCount = 0;
  int _spawnIdx = 0;
  int _nextRow = 0;
  double _lastCurSec = 0;
  double _lastFrameSec = 0;
  double _anchorVideoSec = 0;
  double _anchorWallSec = 0;

  @override
  void initState() {
    super.initState();
    _syncAnchor();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )
      ..addListener(_onFrame)
      ..repeat();
    widget.positionListenable?.addListener(_onPositionTick);
  }

  void _onPositionTick() => _syncAnchor();

  void _syncAnchor() {
    final actual = widget.getCurrentTime().inMilliseconds / 1000.0;
    final wallNow = DateTime.now().millisecondsSinceEpoch / 1000.0;

    if (!widget.isPlaying) {
      _anchorVideoSec = actual;
      _anchorWallSec = wallNow;
      return;
    }

    final rate = widget.playbackSpeed.clamp(0.1, 4.0);
    final extrapolated = _anchorVideoSec + (wallNow - _anchorWallSec) * rate;

    if (actual < extrapolated - 0.5) {
      _anchorVideoSec = actual;
      _anchorWallSec = wallNow;
      return;
    }

    if (actual >= extrapolated - 0.12) {
      _anchorVideoSec = actual;
      _anchorWallSec = wallNow;
    }
  }

  double _interpolatedVideoSec() {
    if (!widget.isPlaying) {
      return widget.getCurrentTime().inMilliseconds / 1000.0;
    }
    final wallNow = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final rate = widget.playbackSpeed.clamp(0.1, 4.0);
    return _anchorVideoSec + (wallNow - _anchorWallSec) * rate;
  }

  void _onFrame() {
    if (_size.width <= 0 || widget.comments.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final staticDt =
        _lastFrameSec > 0 ? (now - _lastFrameSec).clamp(0.001, 0.05) : 0.016;
    _lastFrameSec = now;
    _updateDanmu(_interpolatedVideoSec(), staticDt);
  }

  void _resetDanmuState() {
    _activeScroll.clear();
    _activeStatic.clear();
    _firedKeys.clear();
    _spawnIdx = 0;
    _nextRow = 0;
    _lastCurSec = 0;
    _paragraphCache.clear();
  }

  @override
  void dispose() {
    widget.positionListenable?.removeListener(_onPositionTick);
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DanmuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positionListenable != oldWidget.positionListenable) {
      oldWidget.positionListenable?.removeListener(_onPositionTick);
      widget.positionListenable?.addListener(_onPositionTick);
    }
    if (widget.comments.length != oldWidget.comments.length) {
      _resetDanmuState();
      _lastCommentCount = widget.comments.length;
    }
    if (!widget.isPlaying && oldWidget.isPlaying) _syncAnchor();
  }

  void _updateDanmu(double curSec, double staticDt) {
    final comments = widget.comments;
    final lnH = widget.fontSize * 1.5;
    final topOffset = _size.height * widget.topOffsetPercent / 100;
    final areaH = _size.height * widget.areaPercent / 100;
    final maxRow = max(1, (areaH / lnH).floor());
    const densityWindow = 0.35;
    final pxPerSec = _DanmuPainter.pixelsPerVideoSecond(_size.width, widget.speed);
    final windowStart = curSec - densityWindow;

    if (curSec < _lastCurSec - 0.8) {
      _activeScroll.clear();
      _activeStatic.clear();
      _firedKeys.clear();
      _spawnIdx = _lowerBound(comments, windowStart - 0.5);
    }
    _lastCurSec = curSec;

    _activeScroll.removeWhere((a) {
      final elapsed = curSec - a.time;
      if (elapsed < 0) return true;
      return _size.width - elapsed * pxPerSec + a.tw < -80;
    });

    _activeStatic.removeWhere((a) {
      a.ttl -= staticDt;
      return a.ttl <= 0;
    });

    while (_spawnIdx < comments.length &&
        comments[_spawnIdx].time < windowStart - 0.5) {
      _spawnIdx++;
    }

    if (_activeScroll.length >= _maxActiveScroll) return;

    for (var i = _spawnIdx; i < comments.length; i++) {
      final c = comments[i];
      if (!_typeVisible(c.type)) continue;

      final diff = curSec - c.time;
      if (diff < -0.05) break;
      if (diff > densityWindow || diff < 0) continue;

      final key = (c.time * 1000).round();
      if (_firedKeys.contains(key)) continue;

      if (widget.mergeDuplicates && c.type == 1) {
        final dup = _activeScroll.any(
          (a) => a.text == c.text && (curSec - a.time).abs() < 2.0,
        );
        if (dup) continue;
      }

      _firedKeys.add(key);

      if (c.type == 4 || c.type == 5) {
        final item = _DanmuItem(
          text: c.text,
          time: c.time,
          color: c.color,
          type: c.type,
        );
        item.tw = _measureText(c.text);
        item.x = (_size.width - item.tw) / 2;
        if (c.type == 5) {
          final topCount = _activeStatic.where((a) => a.type == 5).length;
          item.y = widget.topMargin + topOffset + lnH + topCount * lnH;
        } else {
          final bottomCount = _activeStatic.where((a) => a.type == 4).length;
          item.y = _size.height - lnH * 0.2 - bottomCount * lnH;
        }
        _activeStatic.add(item);
      } else {
        if (_activeScroll.length >= _maxActiveScroll) break;
        final item = _DanmuItem(
          text: c.text,
          time: c.time,
          color: c.color,
          type: c.type,
        );
        item.tw = _measureText(c.text);
        final row = _nextRow;
        _nextRow = (_nextRow + 1) % maxRow;
        item.y = widget.topMargin + topOffset + lnH + row * lnH;
        _activeScroll.add(item);
      }
    }
  }

  bool _typeVisible(int type) {
    if (type == 4) return widget.showBottom;
    if (type == 5) return widget.showTop;
    return widget.showScroll;
  }

  double _measureText(String text) =>
      _getParagraphs(text, 0xFFFFFFFF).width;

  _DanmuParagraphs _getParagraphs(String text, int colorValue) {
    final key =
        '${widget.fontSize}_${widget.showOutline}_${widget.opacity}_${colorValue}_$text';
    final cached = _paragraphCache[key];
    if (cached != null) return cached;

    ui.Paragraph? outlineP;
    if (widget.showOutline) {
      final outlineBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
        ),
      )
        ..pushStyle(ui.TextStyle(
          fontSize: widget.fontSize,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black
                .withAlpha((widget.opacity * 255).toInt().clamp(0, 255)),
        ))
        ..addText(text);
      outlineP = outlineBuilder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
    }

    final c = Color(colorValue);
    final alpha = (c.alpha * widget.opacity).toInt().clamp(0, 255);
    final fillBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.bold,
      ),
    )
      ..pushStyle(
        ui.TextStyle(color: c.withAlpha(alpha), fontSize: widget.fontSize),
      )
      ..addText(text);
    final fillP = fillBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final result = _DanmuParagraphs(
      fill: fillP,
      outline: outlineP,
      width: fillP.longestLine + 10,
    );
    _paragraphCache[key] = result;
    return result;
  }

  static int _lowerBound(List<DanmuComment> comments, double target) {
    var lo = 0;
    var hi = comments.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (comments[mid].time < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return max(0, lo - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comments.length != _lastCommentCount) {
      _resetDanmuState();
      _lastCommentCount = widget.comments.length;
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = Size(constraints.maxWidth, constraints.maxHeight);
          return CustomPaint(
            painter: _DanmuPainter(
              getCurrentSec: _interpolatedVideoSec,
              speed: widget.speed,
              getParagraphs: _getParagraphs,
              activeScroll: _activeScroll,
              activeStatic: _activeStatic,
              repaint: _animCtrl,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _DanmuParagraphs {
  _DanmuParagraphs({required this.fill, this.outline, required this.width});

  final ui.Paragraph fill;
  final ui.Paragraph? outline;
  final double width;
}

class _DanmuItem {
  _DanmuItem({
    required this.text,
    required this.time,
    this.color = 0xFFFFFFFF,
    this.type = 1,
  });

  final String text;
  final double time;
  final int color;
  final int type;
  double x = 0;
  double y = 0;
  double tw = 0;
  double ttl = 6;
}

class _DanmuPainter extends CustomPainter {
  _DanmuPainter({
    required this.getCurrentSec,
    required this.speed,
    required this.getParagraphs,
    required this.activeScroll,
    required this.activeStatic,
    super.repaint,
  });

  static const _crossBaseSeconds = 14.0;

  final double Function() getCurrentSec;
  final double speed;
  final _DanmuParagraphs Function(String text, int colorValue) getParagraphs;
  final List<_DanmuItem> activeScroll;
  final List<_DanmuItem> activeStatic;

  static double pixelsPerVideoSecond(double screenWidth, double speed) {
    final rate = speed.clamp(0.08, 3.0);
    return (screenWidth / _crossBaseSeconds) * rate;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final curSec = getCurrentSec();
    final pxPerSec = pixelsPerVideoSecond(size.width, speed);

    for (final a in activeScroll) {
      final elapsed = curSec - a.time;
      if (elapsed < 0) continue;
      final x = size.width - elapsed * pxPerSec;
      if (x < -a.tw - 80 || x > size.width + 80) continue;
      _drawDanmu(canvas, a, x);
    }

    for (final a in activeStatic) {
      _drawDanmu(canvas, a, a.x);
    }
  }

  void _drawDanmu(Canvas canvas, _DanmuItem a, double x) {
    final paras = getParagraphs(a.text, a.color);
    if (paras.outline != null) {
      canvas.drawParagraph(paras.outline!, Offset(x, a.y));
    }
    canvas.drawParagraph(paras.fill, Offset(x, a.y));
  }

  @override
  bool shouldRepaint(covariant _DanmuPainter oldDelegate) => false;
}
