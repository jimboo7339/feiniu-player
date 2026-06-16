import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../danmaku/danmu_settings.dart';
import '../../danmaku/services/danmu_service.dart';

/// 弹幕源选择底部弹窗
class DanmuSourceSheet extends ConsumerStatefulWidget {
  const DanmuSourceSheet({
    super.key,
    required this.defaultKeyword,
    required this.episodeNumber,
    required this.onSelected,
  });

  final String defaultKeyword;
  final int episodeNumber;
  final Future<void> Function(DanmuLoadResult result) onSelected;

  static Future<void> show(
    BuildContext context, {
    required String defaultKeyword,
    required int episodeNumber,
    required Future<void> Function(DanmuLoadResult result) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DanmuSourceSheet(
        defaultKeyword: defaultKeyword,
        episodeNumber: episodeNumber,
        onSelected: onSelected,
      ),
    );
  }

  @override
  ConsumerState<DanmuSourceSheet> createState() => _DanmuSourceSheetState();
}

class _DanmuSourceSheetState extends ConsumerState<DanmuSourceSheet> {
  late final TextEditingController _keywordCtrl;
  List<DanmuAnimeResult> _results = [];
  bool _loading = false;
  String? _error;
  int? _loadingId;

  @override
  void initState() {
    super.initState();
    _keywordCtrl = TextEditingController(text: widget.defaultKeyword);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final settings = ref.read(danmuSettingsProvider);
    if (settings.danmuUrl.isEmpty) {
      setState(() => _error = '请先在设置中配置弹幕服务器');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    final list = await ref.read(danmuServiceProvider).searchAnime(
          danmuBaseUrl: settings.danmuUrl,
          keyword: _keywordCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = list;
      if (list.isEmpty) _error = '未找到匹配结果';
    });
  }

  Future<void> _pick(DanmuAnimeResult anime) async {
    final settings = ref.read(danmuSettingsProvider);
    setState(() => _loadingId = anime.animeId);
    final result = await ref.read(danmuServiceProvider).loadFromAnime(
          danmuBaseUrl: settings.danmuUrl,
          animeId: anime.animeId,
          animeName: anime.animeName,
          episodeNumber: widget.episodeNumber,
          withRelated: settings.withRelated,
        );
    if (!mounted) return;
    setState(() => _loadingId = null);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载弹幕失败')),
      );
      return;
    }
    Navigator.pop(context);
    await widget.onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keywordCtrl,
                        decoration: const InputDecoration(
                          hintText: '搜索番剧名',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading ? null : _search,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('搜索'),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.white54)),
                ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    final loading = _loadingId == item.animeId;
                    return ListTile(
                      title: Text(item.animeName),
                      subtitle: Text(
                        [
                          if (item.typeDescription.isNotEmpty)
                            item.typeDescription,
                          if (item.episodeCount > 0)
                            '${item.episodeCount} 集',
                        ].join(' · '),
                      ),
                      trailing: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: loading ? null : () => _pick(item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
