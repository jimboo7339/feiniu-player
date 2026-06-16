import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../danmaku/danmu_settings.dart';
import '../subtitle_settings.dart';

/// 播放器内字幕 / 弹幕设置面板
class PlayerSettingsPanel extends ConsumerWidget {
  const PlayerSettingsPanel({
    super.key,
    this.initialTab = 0,
    this.onDanmuSourceTap,
    this.onDanmuReload,
  });

  final int initialTab;
  final VoidCallback? onDanmuSourceTap;
  final VoidCallback? onDanmuReload;

  static Future<void> show(
    BuildContext context, {
    int initialTab = 0,
    VoidCallback? onDanmuSourceTap,
    VoidCallback? onDanmuReload,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return DefaultTabController(
            initialIndex: initialTab,
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: '字幕'),
                    Tab(text: '弹幕'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SubtitleTab(scrollController: scrollController),
                      _DanmuTab(
                        scrollController: scrollController,
                        onDanmuSourceTap: onDanmuSourceTap,
                        onDanmuReload: onDanmuReload,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

class _SubtitleTab extends ConsumerWidget {
  const _SubtitleTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subtitleSettingsProvider);
    final notifier = ref.read(subtitleSettingsProvider.notifier);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSliderTile(
          label: '字号',
          displayValue: '字号 ${sub.fontSize.round()}',
          value: sub.fontSize,
          min: 16,
          max: 48,
          divisions: 16,
          onChanged: notifier.setFontSize,
        ),
        SettingsSliderTile(
          label: '底部边距',
          displayValue: '底部边距 ${sub.bottomOffset.round()}',
          value: sub.bottomOffset,
          min: 16,
          max: 160,
          divisions: 14,
          onChanged: notifier.setBottomOffset,
        ),
        SettingsSliderTile(
          label: '背景透明度',
          displayValue: '背景 ${(sub.backgroundOpacity * 100).round()}%',
          value: sub.backgroundOpacity,
          min: 0,
          max: 1,
          onChanged: notifier.setBackgroundOpacity,
        ),
        SwitchListTile(
          title: const Text('粗体'),
          value: sub.bold,
          onChanged: notifier.setBold,
        ),
        ListTile(
          title: const Text('位置'),
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
            onSelectionChanged: (s) => notifier.setPosition(s.first),
          ),
        ),
      ],
    );
  }
}

class _DanmuTab extends ConsumerWidget {
  const _DanmuTab({
    required this.scrollController,
    this.onDanmuSourceTap,
    this.onDanmuReload,
  });

  final ScrollController scrollController;
  final VoidCallback? onDanmuSourceTap;
  final VoidCallback? onDanmuReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final danmu = ref.watch(danmuSettingsProvider);
    final notifier = ref.read(danmuSettingsProvider.notifier);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (onDanmuReload != null)
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('重新自动匹配'),
            onTap: () {
              Navigator.pop(context);
              onDanmuReload!();
            },
          ),
        if (onDanmuSourceTap != null)
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('切换弹幕源'),
            subtitle: const Text('搜索并选择其他番剧的弹幕'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              onDanmuSourceTap!();
            },
          ),
        SwitchListTile(
          title: const Text('显示弹幕'),
          value: danmu.enabled,
          onChanged: notifier.setEnabled,
        ),
        SettingsSliderTile(
          label: '字号',
          displayValue: '字号 ${danmu.fontSize.round()}',
          value: danmu.fontSize,
          min: 14,
          max: 36,
          divisions: 11,
          onChanged: notifier.setFontSize,
        ),
        SettingsSliderTile(
          label: '透明度',
          displayValue: '透明度 ${(danmu.opacity * 100).round()}%',
          value: danmu.opacity,
          min: 0.2,
          max: 1,
          onChanged: notifier.setOpacity,
        ),
        SettingsSliderTile(
          label: '滚动速度',
          displayValue: '速度 ${danmu.speed.toStringAsFixed(1)}',
          value: danmu.speed,
          min: 0.2,
          max: 1.5,
          onChanged: notifier.setSpeed,
        ),
        SettingsSliderTile(
          label: '显示区域',
          displayValue: '区域 ${danmu.areaPercent}%',
          value: danmu.areaPercent.toDouble(),
          min: 20,
          max: 80,
          divisions: 6,
          onChanged: (v) => notifier.setAreaPercent(v.round()),
        ),
        SettingsSliderTile(
          label: '顶部偏移',
          displayValue: '顶部偏移 ${danmu.topOffsetPercent}%',
          value: danmu.topOffsetPercent.toDouble(),
          min: 0,
          max: 40,
          divisions: 8,
          onChanged: (v) => notifier.setTopOffsetPercent(v.round()),
        ),
        SwitchListTile(
          title: const Text('滚动弹幕'),
          value: danmu.showScroll,
          onChanged: notifier.setShowScroll,
        ),
        SwitchListTile(
          title: const Text('顶部弹幕'),
          value: danmu.showTop,
          onChanged: notifier.setShowTop,
        ),
        SwitchListTile(
          title: const Text('底部弹幕'),
          value: danmu.showBottom,
          onChanged: notifier.setShowBottom,
        ),
        SwitchListTile(
          title: const Text('描边'),
          value: danmu.showOutline,
          onChanged: notifier.setShowOutline,
        ),
        SwitchListTile(
          title: const Text('合并重复'),
          subtitle: const Text('相同文字短时间内只显示一条'),
          value: danmu.mergeDuplicates,
          onChanged: notifier.setMergeDuplicates,
        ),
        SwitchListTile(
          title: const Text('关联弹幕'),
          subtitle: const Text('加载其他集/平台的关联弹幕'),
          value: danmu.withRelated,
          onChanged: notifier.setWithRelated,
        ),
      ],
    );
  }
}
