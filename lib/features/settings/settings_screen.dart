import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../danmaku/danmu_settings.dart';

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
    final settings = ref.watch(danmuSettingsProvider);

    if (settings.loaded && _urlCtrl.text.isEmpty && settings.danmuUrl.isNotEmpty) {
      _urlCtrl.text = settings.danmuUrl;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settings.loaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('弹幕设置', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('启用弹幕'),
                  value: settings.enabled,
                  onChanged: (v) =>
                      ref.read(danmuSettingsProvider.notifier).setEnabled(v),
                ),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: '弹幕服务器地址',
                    hintText: 'http://192.168.x.x:9321',
                    border: OutlineInputBorder(),
                    helperText: '弹弹play 兼容 API，部署在 NAS 或局域网',
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (v) => ref
                      .read(danmuSettingsProvider.notifier)
                      .setDanmuUrl(v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => ref
                      .read(danmuSettingsProvider.notifier)
                      .setDanmuUrl(_urlCtrl.text),
                  child: const Text('保存弹幕地址'),
                ),
                const SizedBox(height: 24),
                Text('显示', style: Theme.of(context).textTheme.titleSmall),
                ListTile(
                  title: Text('透明度 ${(settings.opacity * 100).round()}%'),
                  subtitle: Slider(
                    value: settings.opacity,
                    min: 0.2,
                    max: 1,
                    onChanged: (v) => ref
                        .read(danmuSettingsProvider.notifier)
                        .setOpacity(v),
                  ),
                ),
                ListTile(
                  title: Text('字号 ${settings.fontSize.round()}'),
                  subtitle: Slider(
                    value: settings.fontSize,
                    min: 14,
                    max: 36,
                    divisions: 11,
                    onChanged: (v) => ref
                        .read(danmuSettingsProvider.notifier)
                        .setFontSize(v),
                  ),
                ),
                ListTile(
                  title: Text('显示区域 ${settings.areaPercent}%'),
                  subtitle: Slider(
                    value: settings.areaPercent.toDouble(),
                    min: 20,
                    max: 80,
                    divisions: 6,
                    onChanged: (v) => ref
                        .read(danmuSettingsProvider.notifier)
                        .setAreaPercent(v.round()),
                  ),
                ),
                ListTile(
                  title: Text('滚动速度 ${settings.speed.toStringAsFixed(1)}'),
                  subtitle: Slider(
                    value: settings.speed,
                    min: 0.2,
                    max: 1.5,
                    onChanged: (v) =>
                        ref.read(danmuSettingsProvider.notifier).setSpeed(v),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
