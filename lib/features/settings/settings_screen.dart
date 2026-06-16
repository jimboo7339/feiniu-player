import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../danmaku/danmu_settings.dart';
import '../player/subtitle_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danmu = ref.watch(danmuSettingsProvider);
    final sub = ref.watch(subtitleSettingsProvider);

    if (danmu.loaded && _urlCtrl.text.isEmpty && danmu.danmuUrl.isNotEmpty) {
      _urlCtrl.text = danmu.danmuUrl;
    }

    final loaded = danmu.loaded && sub.loaded;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: loaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SettingsSection(
                  title: '弹幕服务器',
                  subtitle: '弹弹play 兼容 API',
                ),
                SwitchListTile(
                  title: const Text('启用弹幕'),
                  value: danmu.enabled,
                  onChanged: ref.read(danmuSettingsProvider.notifier).setEnabled,
                ),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: '弹幕服务器地址',
                    hintText: 'http://192.168.100.10:9321/87654321',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => ref
                      .read(danmuSettingsProvider.notifier)
                      .setDanmuUrl(_urlCtrl.text),
                  child: const Text('保存弹幕地址'),
                ),
                const SettingsSection(title: '弹幕显示'),
                SettingsSliderTile(
                  label: '透明度',
                  displayValue: '透明度 ${(danmu.opacity * 100).round()}%',
                  value: danmu.opacity,
                  min: 0.2,
                  max: 1,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setOpacity,
                ),
                SettingsSliderTile(
                  label: '字号',
                  displayValue: '字号 ${danmu.fontSize.round()}',
                  value: danmu.fontSize,
                  min: 14,
                  max: 36,
                  divisions: 11,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setFontSize,
                ),
                SettingsSliderTile(
                  label: '显示区域',
                  displayValue: '显示区域 ${danmu.areaPercent}%',
                  value: danmu.areaPercent.toDouble(),
                  min: 20,
                  max: 80,
                  divisions: 6,
                  onChanged: (v) => ref
                      .read(danmuSettingsProvider.notifier)
                      .setAreaPercent(v.round()),
                ),
                SettingsSliderTile(
                  label: '顶部偏移',
                  displayValue: '顶部偏移 ${danmu.topOffsetPercent}%',
                  value: danmu.topOffsetPercent.toDouble(),
                  min: 0,
                  max: 40,
                  divisions: 8,
                  onChanged: (v) => ref
                      .read(danmuSettingsProvider.notifier)
                      .setTopOffsetPercent(v.round()),
                ),
                SettingsSliderTile(
                  label: '滚动速度',
                  displayValue: '速度 ${danmu.speed.toStringAsFixed(1)}',
                  value: danmu.speed,
                  min: 0.2,
                  max: 1.5,
                  onChanged: ref.read(danmuSettingsProvider.notifier).setSpeed,
                ),
                SwitchListTile(
                  title: const Text('滚动弹幕'),
                  value: danmu.showScroll,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setShowScroll,
                ),
                SwitchListTile(
                  title: const Text('顶部弹幕'),
                  value: danmu.showTop,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setShowTop,
                ),
                SwitchListTile(
                  title: const Text('底部弹幕'),
                  value: danmu.showBottom,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setShowBottom,
                ),
                SwitchListTile(
                  title: const Text('描边'),
                  value: danmu.showOutline,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setShowOutline,
                ),
                SwitchListTile(
                  title: const Text('合并重复弹幕'),
                  value: danmu.mergeDuplicates,
                  onChanged: ref
                      .read(danmuSettingsProvider.notifier)
                      .setMergeDuplicates,
                ),
                SwitchListTile(
                  title: const Text('关联弹幕'),
                  subtitle: const Text('包含其他集/平台的关联弹幕'),
                  value: danmu.withRelated,
                  onChanged:
                      ref.read(danmuSettingsProvider.notifier).setWithRelated,
                ),
                const SettingsSection(title: '字幕样式'),
                SettingsSliderTile(
                  label: '字号',
                  displayValue: '字号 ${sub.fontSize.round()}',
                  value: sub.fontSize,
                  min: 16,
                  max: 48,
                  divisions: 16,
                  onChanged:
                      ref.read(subtitleSettingsProvider.notifier).setFontSize,
                ),
                SettingsSliderTile(
                  label: '底部边距',
                  displayValue: '底部边距 ${sub.bottomOffset.round()}',
                  value: sub.bottomOffset,
                  min: 16,
                  max: 160,
                  divisions: 14,
                  onChanged: ref
                      .read(subtitleSettingsProvider.notifier)
                      .setBottomOffset,
                ),
                SettingsSliderTile(
                  label: '背景透明度',
                  displayValue: '背景 ${(sub.backgroundOpacity * 100).round()}%',
                  value: sub.backgroundOpacity,
                  min: 0,
                  max: 1,
                  onChanged: ref
                      .read(subtitleSettingsProvider.notifier)
                      .setBackgroundOpacity,
                ),
                SwitchListTile(
                  title: const Text('粗体字幕'),
                  value: sub.bold,
                  onChanged:
                      ref.read(subtitleSettingsProvider.notifier).setBold,
                ),
                ListTile(
                  title: const Text('字幕位置'),
                  subtitle: SegmentedButton<SubtitlePosition>(
                    segments: const [
                      ButtonSegment(
                        value: SubtitlePosition.bottom,
                        label: Text('底部'),
                      ),
                      ButtonSegment(
                        value: SubtitlePosition.lowerThird,
                        label: Text('中下'),
                      ),
                      ButtonSegment(
                        value: SubtitlePosition.center,
                        label: Text('居中'),
                      ),
                    ],
                    selected: {sub.position},
                    onSelectionChanged: (s) => ref
                        .read(subtitleSettingsProvider.notifier)
                        .setPosition(s.first),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
