import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format_utils.dart';
import '../../data/feiniu/feiniu_providers.dart';
import '../../data/feiniu/models/media_models.dart';
import '../player/player_screen.dart';

final detailProvider =
    FutureProvider.autoDispose.family<DetailData, String>((ref, guid) async {
  final api = ref.watch(feiniuApiProvider);
  final detailResp = await api.getItemDetail(guid);
  final detail = detailResp['data'] as Map<String, dynamic>? ?? {};
  final type = detail['type']?.toString() ?? '';

  List<MediaItem> seasons = [];
  List<MediaItem> episodes = [];
  String? selectedSeasonGuid;

  if (type == 'TV') {
    seasons = (await api.getSeasonList(guid)).map(MediaItem.fromJson).toList();
    if (seasons.isNotEmpty) {
      selectedSeasonGuid = seasons.first.guid;
      episodes = (await api.getEpisodeList(selectedSeasonGuid))
          .map(MediaItem.fromJson)
          .toList();
    }
  }

  return DetailData(
    detail: MediaItem.fromJson(detail),
    type: type,
    overview: detail['overview']?.toString() ?? '',
    seasons: seasons,
    episodes: episodes,
    selectedSeasonGuid: selectedSeasonGuid,
  );
});

class DetailData {
  const DetailData({
    required this.detail,
    required this.type,
    required this.overview,
    required this.seasons,
    required this.episodes,
    this.selectedSeasonGuid,
  });

  final MediaItem detail;
  final String type;
  final String overview;
  final List<MediaItem> seasons;
  final List<MediaItem> episodes;
  final String? selectedSeasonGuid;
}

class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({super.key, required this.itemGuid});

  final String itemGuid;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  String? _seasonGuid;
  List<MediaItem> _episodes = [];
  bool _loadingEpisodes = false;

  void _openPlayer(String itemGuid, {int seekSeconds = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          itemGuid: itemGuid,
          initialSeekSeconds: seekSeconds,
        ),
      ),
    );
  }

  Future<void> _loadEpisodes(String seasonGuid) async {
    setState(() {
      _seasonGuid = seasonGuid;
      _loadingEpisodes = true;
    });
    try {
      final list = await ref.read(feiniuApiProvider).getEpisodeList(seasonGuid);
      if (!mounted) return;
      setState(() {
        _episodes = list.map(MediaItem.fromJson).toList();
        _loadingEpisodes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEpisodes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(detailProvider(widget.itemGuid));
    final api = ref.watch(feiniuApiProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (data) {
          final item = data.detail;
          final posterUrl = api.imageUrl(item.poster, width: 800);
          final activeSeason = _seasonGuid ?? data.selectedSeasonGuid;
          final episodes = _seasonGuid == null ? data.episodes : _episodes;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: posterUrl.isEmpty
                      ? ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        )
                      : Image.network(
                          posterUrl,
                          headers: api.client.imageHeaders,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Colors.black26,
                            child: Icon(Icons.movie, size: 64),
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.releaseDate != null &&
                          item.releaseDate!.isNotEmpty)
                        Text('上映: ${item.releaseDate}'),
                      if (item.voteAverage != null && item.voteAverage != '0')
                        Text('评分: ${item.voteAverage}'),
                      const SizedBox(height: 12),
                      if (data.overview.isNotEmpty) Text(data.overview),
                      const SizedBox(height: 16),
                      if (data.type == 'Movie' ||
                          data.type == 'Video' ||
                          data.type == 'Episode')
                        FilledButton.icon(
                          onPressed: () => _openPlayer(
                            widget.itemGuid,
                            seekSeconds: item.watchedTs,
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(item.watchedTs > 0 ? '继续播放' : '播放'),
                        ),
                      if (data.type == 'TV') ...[
                        Text('选季',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: data.seasons.map((season) {
                            final selected = season.guid == activeSeason;
                            return ChoiceChip(
                              label: Text(season.title),
                              selected: selected,
                              onSelected: (_) => _loadEpisodes(season.guid),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text('选集',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_loadingEpisodes)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          )
                        else if (episodes.isEmpty)
                          const Text('暂无剧集')
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: episodes.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final ep = episodes[index];
                              final progress = ep.watchProgress;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: progress > 0
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(40)
                                      : null,
                                  child: progress > 0
                                      ? Icon(
                                          Icons.play_arrow,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        )
                                      : Text('${index + 1}'),
                                ),
                                title: Text(ep.title),
                                subtitle: ep.watchedTs > 0
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ep.durationSeconds > 0
                                                ? '已观看 ${formatDuration(ep.watchedTs)} / ${formatDuration(ep.durationSeconds)}'
                                                : '已观看 ${formatDuration(ep.watchedTs)}',
                                          ),
                                          if (progress > 0) ...[
                                            const SizedBox(height: 4),
                                            LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 2,
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                            ),
                                          ],
                                        ],
                                      )
                                    : null,
                                onTap: () => _openPlayer(
                                  ep.guid,
                                  seekSeconds: ep.watchedTs,
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
