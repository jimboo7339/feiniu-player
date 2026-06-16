import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/format_utils.dart';
import '../../data/feiniu/feiniu_providers.dart';
import '../../data/feiniu/models/stream_models.dart';
import '../auth/auth_controller.dart';
import '../danmaku/danmu_settings.dart';
import '../danmaku/models/danmu_comment.dart';
import '../danmaku/services/danmu_service.dart';
import '../danmaku/widgets/danmu_overlay.dart';
import 'subtitle_settings.dart';
import 'widgets/danmu_source_sheet.dart';
import 'widgets/player_settings_panel.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.itemGuid,
    this.initialSeekSeconds = 0,
  });

  final String itemGuid;
  final int initialSeekSeconds;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  PlaybackSession? _session;
  PlayInfoData? _playInfo;
  List<DanmuComment> _danmuComments = [];
  String _danmuStatus = '';
  bool _danmuVisible = true;
  final ValueNotifier<int> _positionTick = ValueNotifier(0);
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  bool _isPlaying = true;
  double _speed = 1.0;
  int _selectedSubtitle = -1;
  int _selectedAudio = 0;
  int _pendingSeekSeconds = 0;
  bool _seekApplied = false;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final auth = ref.read(authStateProvider);
      final repo = ref.read(playbackRepositoryProvider);
      final api = ref.read(feiniuApiProvider);
      final playInfo = await repo.loadPlayInfo(widget.itemGuid);
      final session = await repo.preparePlayback(
        playInfo: playInfo,
        username: auth.username,
      );
      await _loadDanmu(playInfo);

      final seek = [
        widget.initialSeekSeconds,
        session.seekSeconds,
        playInfo.seekSeconds,
      ].reduce(max);
      _pendingSeekSeconds = seek;

      final headers = session.playUrl.contains('/v/api/v1/media/range')
          ? api.client.authHeaders
          : <String, String>{};

      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 128 * 1024 * 1024,
        ),
      );
      final controller = VideoController(player);

      player.stream.position.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        _positionTick.value = pos.inMilliseconds;
      });
      player.stream.duration.listen((dur) {
        if (!mounted) return;
        setState(() => _duration = dur);
        _tryApplyPendingSeek();
      });
      player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
      });

      await player.open(
        Media(session.playUrl, httpHeaders: headers),
        play: false,
      );
      await _tryApplyPendingSeek(player: player);
      await _applyInitialTracks(player, session);
      await player.play();

      if (!mounted) return;
      setState(() {
        _player = player;
        _videoController = controller;
        _session = session;
        _playInfo = playInfo;
        _loading = false;
        _danmuVisible = ref.read(danmuSettingsProvider).enabled;
      });
      _startProgressTimer();
      _resetHideTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _tryApplyPendingSeek({Player? player}) async {
    final p = player ?? _player;
    if (p == null || _seekApplied || _pendingSeekSeconds <= 0) return;
    await p.seek(Duration(seconds: _pendingSeekSeconds));
    _seekApplied = true;
  }

  Future<void> _applyInitialTracks(Player player, PlaybackSession session) async {
    if (session.subtitles.isNotEmpty) {
      final idx = session.subtitles.indexWhere(
        (s) => s.guid != null && s.guid == session.subtitleGuid,
      );
      if (idx >= 0) await _applySubtitle(idx, player: player);
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Future<void> _loadDanmu(PlayInfoData playInfo) async {
    final settings = ref.read(danmuSettingsProvider);
    if (!settings.enabled || settings.danmuUrl.isEmpty) {
      _danmuStatus = settings.danmuUrl.isEmpty ? '未配置弹幕服务器' : '';
      return;
    }

    final cache = ref.read(danmuSettingsProvider.notifier).sourceCache;
    final cached = cache?.get(playInfo.matchName);
    final result = await ref.read(danmuServiceProvider).loadAuto(
          danmuBaseUrl: settings.danmuUrl,
          matchName: playInfo.matchName,
          episodeNumber: playInfo.episodeNumber,
          cachedSource: cached,
          withRelated: settings.withRelated,
          onSourceCached: (source) => cache?.save(playInfo.matchName, source),
        );

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _danmuComments = [];
        _danmuStatus = '未匹配到弹幕 · 长按可切换源';
      });
      return;
    }
    setState(() {
      _danmuComments = result.comments;
      _danmuStatus =
          '${result.source['animeName'] ?? ''} · ${result.comments.length} 条';
    });
  }

  Future<void> _applyDanmuResult(DanmuLoadResult result) async {
    final playInfo = _playInfo;
    if (playInfo != null) {
      await ref
          .read(danmuSettingsProvider.notifier)
          .sourceCache
          ?.save(playInfo.matchName, result.source);
    }
    if (!mounted) return;
    setState(() {
      _danmuComments = result.comments;
      _danmuStatus =
          '${result.source['animeName'] ?? ''} · ${result.comments.length} 条';
      _danmuVisible = true;
    });
  }

  Future<void> _reloadDanmu() async {
    final playInfo = _playInfo;
    if (playInfo == null) return;
    setState(() => _danmuStatus = '加载中…');
    await _loadDanmu(playInfo);
  }

  Future<void> _pickDanmuSource() async {
    final playInfo = _playInfo;
    if (playInfo == null) return;
    await DanmuSourceSheet.show(
      context,
      defaultKeyword: playInfo.matchName,
      episodeNumber: playInfo.episodeNumber,
      onSelected: _applyDanmuResult,
    );
  }

  Future<void> _saveProgress() async {
    final session = _session;
    if (session == null) return;
    final pos = _position.inSeconds;
    final dur = _duration.inSeconds;
    if (pos <= 0) return;
    try {
      await ref.read(playbackRepositoryProvider).reportProgress(
            session: session,
            positionSeconds: pos,
            durationSeconds: dur,
          );
    } catch (_) {}
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _resetHideTimer();
  }

  Future<void> _setSpeed(double speed) async {
    await _player?.setRate(speed);
    setState(() => _speed = speed);
    _onUserInteraction();
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : target;
    await _player?.seek(clamped);
    _onUserInteraction();
  }

  Future<void> _applySubtitle(int listIndex, {Player? player}) async {
    final p = player ?? _player;
    if (p == null) return;
    if (listIndex < 0) {
      await p.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await p.setSubtitleTrack(SubtitleTrack('${listIndex + 1}', null, null));
    }
    setState(() => _selectedSubtitle = listIndex);
    _onUserInteraction();
  }

  Future<void> _applyAudio(int listIndex) async {
    final player = _player;
    if (player == null) return;
    await player.setAudioTrack(AudioTrack('${listIndex + 1}', null, null));
    setState(() => _selectedAudio = listIndex);
    _onUserInteraction();
  }

  SubtitleViewConfiguration _subtitleConfig(SubtitleSettingsState sub) {
    final style = sub.toViewStyle();
    final screenH = MediaQuery.sizeOf(context).height;
    var bottom = style.bottomOffset;
    switch (style.position) {
      case SubtitlePosition.lowerThird:
        bottom += screenH * 0.12;
      case SubtitlePosition.center:
        bottom = screenH * 0.42;
      case SubtitlePosition.bottom:
        break;
    }
    return SubtitleViewConfiguration(
      visible: _selectedSubtitle >= 0,
      style: TextStyle(
        height: 1.35,
        fontSize: style.fontSize,
        color: style.color,
        fontWeight: style.bold ? FontWeight.w600 : FontWeight.normal,
        backgroundColor: Colors.black.withAlpha(
          (style.backgroundOpacity * 255).round().clamp(0, 255),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottom),
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _positionTick.dispose();
    _player?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danmuSettings = ref.watch(danmuSettingsProvider);
    final subtitleSettings = ref.watch(subtitleSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onBack: () => Navigator.pop(context))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_videoController != null)
                        Center(
                          child: Video(
                            controller: _videoController!,
                            controls: (_) => const SizedBox.shrink(),
                            subtitleViewConfiguration:
                                _subtitleConfig(subtitleSettings),
                          ),
                        ),
                      if (_danmuVisible &&
                          _danmuComments.isNotEmpty &&
                          danmuSettings.enabled)
                        DanmuOverlay(
                          comments: _danmuComments,
                          getCurrentTime: () => _position,
                          positionListenable: _positionTick,
                          isPlaying: _isPlaying,
                          playbackSpeed: _speed,
                          opacity: danmuSettings.opacity,
                          fontSize: danmuSettings.fontSize,
                          areaPercent: danmuSettings.areaPercent,
                          topOffsetPercent: danmuSettings.topOffsetPercent,
                          mergeDuplicates: danmuSettings.mergeDuplicates,
                          showOutline: danmuSettings.showOutline,
                          speed: danmuSettings.speed,
                          showScroll: danmuSettings.showScroll,
                          showTop: danmuSettings.showTop,
                          showBottom: danmuSettings.showBottom,
                        ),
                      if (_showControls) _buildControlsOverlay(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildControlsOverlay() {
    final session = _session!;
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / _duration.inMilliseconds;

    return Stack(
      children: [
        // 顶部栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(200),
                  Colors.black.withAlpha(0),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            session.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (session.subtitle.isNotEmpty)
                            Text(
                              session.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (_pendingSeekSeconds > 0 && _seekApplied)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '续播 ${formatDuration(_pendingSeekSeconds)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 底部控制区
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withAlpha(230),
                  Colors.black.withAlpha(120),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 播放按钮行
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _ControlBtn(
                          icon: Icons.replay_10,
                          onTap: () => _seekRelative(-10),
                        ),
                        _ControlBtn(
                          icon: _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 36,
                          onTap: () {
                            if (_isPlaying) {
                              _player?.pause();
                            } else {
                              _player?.play();
                            }
                            _onUserInteraction();
                          },
                        ),
                        _ControlBtn(
                          icon: Icons.forward_10,
                          onTap: () => _seekRelative(10),
                        ),
                        const Spacer(),
                        _ControlBtn(
                          icon: _danmuVisible
                              ? Icons.closed_caption
                              : Icons.closed_caption_off,
                          color: _danmuComments.isEmpty
                              ? Colors.white38
                              : Colors.white,
                          onTap: _danmuComments.isEmpty
                              ? null
                              : () {
                                  setState(
                                      () => _danmuVisible = !_danmuVisible);
                                  _onUserInteraction();
                                },
                          onLongPress: _pickDanmuSource,
                        ),
                        _SpeedButton(speed: _speed, onSelected: _setSpeed),
                        if (session.audios.length > 1)
                          _TrackMenuButton(
                            icon: Icons.audiotrack_outlined,
                            label: '音轨',
                            items: session.audios
                                .asMap()
                                .entries
                                .map((e) => (
                                      e.key,
                                      e.value.displayName,
                                      e.key == _selectedAudio,
                                    ))
                                .toList(),
                            onSelected: _applyAudio,
                          ),
                        if (session.subtitles.isNotEmpty)
                          _TrackMenuButton(
                            icon: Icons.subtitles_outlined,
                            label: '字幕',
                            items: [
                              (-1, '关闭', _selectedSubtitle < 0),
                              ...session.subtitles.asMap().entries.map(
                                    (e) => (
                                      e.key,
                                      e.value.displayName,
                                      e.key == _selectedSubtitle,
                                    ),
                                  ),
                            ],
                            onSelected: _applySubtitle,
                          ),
                        _ControlBtn(
                          icon: Icons.tune,
                          onTap: () {
                            PlayerSettingsPanel.show(
                              context,
                              onDanmuSourceTap: _pickDanmuSource,
                              onDanmuReload: _reloadDanmu,
                            );
                            _onUserInteraction();
                          },
                        ),
                      ],
                    ),
                  ),
                  // 进度条 — 贴底
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          _format(_position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: (v) async {
                                final ms =
                                    (_duration.inMilliseconds * v).round();
                                await _player?.seek(
                                  Duration(milliseconds: ms),
                                );
                                _onUserInteraction();
                              },
                            ),
                          ),
                        ),
                        Text(
                          _format(_duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_danmuStatus.isNotEmpty || session.isStrm)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        [
                          if (_danmuStatus.isNotEmpty) _danmuStatus,
                          if (session.isStrm) 'STRM',
                        ].join(' · '),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _format(Duration d) => formatDurationFromDuration(d);
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.onTap,
    this.size = 28,
    this.color = Colors.white,
    this.onLongPress,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: size,
      color: color,
      onPressed: onTap,
      onLongPress: onLongPress,
      icon: Icon(icon),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onSelected});

  final double speed;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: '倍速',
      onSelected: onSelected,
      itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
          .map(
            (s) => PopupMenuItem(
              value: s,
              child: Text('${s}x${s == speed ? ' ✓' : ''}'),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '${speed}x',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

class _TrackMenuButton extends StatelessWidget {
  const _TrackMenuButton({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<(int index, String name, bool selected)> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      icon: Icon(icon, color: Colors.white),
      onSelected: onSelected,
      itemBuilder: (_) => items
          .map(
            (item) => PopupMenuItem(
              value: item.$1,
              child: Text('${item.$2}${item.$3 ? ' ✓' : ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('返回')),
          ],
        ),
      ),
    );
  }
}
