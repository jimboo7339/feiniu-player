import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/feiniu/feiniu_providers.dart';
import '../../data/feiniu/models/stream_models.dart';
import '../auth/auth_controller.dart';
import '../danmaku/danmu_settings.dart';
import '../danmaku/models/danmu_comment.dart';
import '../danmaku/widgets/danmu_overlay.dart';

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
  // ignore: unused_field
  int _selectedSubtitle = -1;
  // ignore: unused_field
  int _selectedAudio = 0;
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
      final seek = widget.initialSeekSeconds > 0
          ? widget.initialSeekSeconds
          : session.seekSeconds;

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
      });
      player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
      });

      await player.open(
        Media(session.playUrl, httpHeaders: headers),
        play: false,
      );
      if (seek > 0) {
        await player.seek(Duration(seconds: seek));
      }
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
          onSourceCached: (source) => cache?.save(playInfo.matchName, source),
        );

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _danmuComments = [];
        _danmuStatus = '未匹配到弹幕';
      });
      return;
    }
    setState(() {
      _danmuComments = result.comments;
      _danmuStatus = '${result.comments.length} 条弹幕';
    });
  }

  Future<void> _reloadDanmu() async {
    final playInfo = _playInfo;
    if (playInfo == null) return;
    setState(() => _danmuStatus = '加载中…');
    await _loadDanmu(playInfo);
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

  Future<void> _setSpeed(double speed) async {
    await _player?.setRate(speed);
    setState(() => _speed = speed);
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : target;
    await _player?.seek(clamped);
  }

  Future<void> _applySubtitle(int listIndex) async {
    final player = _player;
    if (player == null) return;
    if (listIndex < 0) {
      await player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await player.setSubtitleTrack(SubtitleTrack('${listIndex + 1}', null, null));
    }
    setState(() => _selectedSubtitle = listIndex);
  }

  Future<void> _applyAudio(int listIndex) async {
    final player = _player;
    if (player == null) return;
    await player.setAudioTrack(AudioTrack('${listIndex + 1}', null, null));
    setState(() => _selectedAudio = listIndex);
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onBack: () => Navigator.pop(context))
              : GestureDetector(
                  onTap: _toggleControls,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_videoController != null)
                        Center(
                          child: Video(
                            controller: _videoController!,
                            controls: (_) => const SizedBox.shrink(),
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
                          showOutline: danmuSettings.showOutline,
                          speed: danmuSettings.speed,
                          showScroll: danmuSettings.showScroll,
                          showTop: danmuSettings.showTop,
                          showBottom: danmuSettings.showBottom,
                        ),
                      if (_showControls) _buildControls(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildControls() {
    final session = _session!;
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / _duration.inMilliseconds;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                session.title,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: session.subtitle.isNotEmpty
                  ? Text(session.subtitle, style: const TextStyle(color: Colors.white70))
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _danmuVisible ? '隐藏弹幕' : '显示弹幕',
                    icon: Icon(
                      _danmuVisible ? Icons.subtitles : Icons.subtitles_off,
                      color: _danmuComments.isEmpty ? Colors.white38 : Colors.white,
                    ),
                    onPressed: _danmuComments.isEmpty
                        ? null
                        : () => setState(() => _danmuVisible = !_danmuVisible),
                    onLongPress: _reloadDanmu,
                  ),
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.speed, color: Colors.white),
                    onSelected: _setSpeed,
                    itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                        .map(
                          (s) => PopupMenuItem(
                            value: s,
                            child: Text('${s}x${s == _speed ? ' ✓' : ''}'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_format(_position), style: const TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: progress.clamp(0, 1),
                      onChanged: (v) async {
                        final ms = (_duration.inMilliseconds * v).round();
                        await _player?.seek(Duration(milliseconds: ms));
                      },
                    ),
                  ),
                  Text(_format(_duration), style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 32,
                  color: Colors.white,
                  onPressed: () => _seekRelative(-10),
                  icon: const Icon(Icons.replay_10),
                ),
                IconButton(
                  iconSize: 48,
                  color: Colors.white,
                  onPressed: () {
                    if (_isPlaying) {
                      _player?.pause();
                    } else {
                      _player?.play();
                    }
                  },
                  icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
                ),
                IconButton(
                  iconSize: 32,
                  color: Colors.white,
                  onPressed: () => _seekRelative(10),
                  icon: const Icon(Icons.forward_10),
                ),
                if (session.audios.length > 1)
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                    onSelected: _applyAudio,
                    itemBuilder: (_) => List.generate(session.audios.length, (i) {
                      final a = session.audios[i];
                      return PopupMenuItem(value: i, child: Text(a.displayName));
                    }),
                  ),
                if (session.subtitles.isNotEmpty)
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.subtitles, color: Colors.white),
                    onSelected: _applySubtitle,
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: -1, child: Text('关闭字幕')),
                      ...List.generate(session.subtitles.length, (i) {
                        final s = session.subtitles[i];
                        return PopupMenuItem(value: i, child: Text(s.displayName));
                      }),
                    ],
                  ),
              ],
            ),
            if (_danmuStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _danmuStatus,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            if (session.isStrm)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('STRM 直链播放', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('返回')),
          ],
        ),
      ),
    );
  }
}
