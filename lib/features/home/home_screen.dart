import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feiniu/feiniu_providers.dart';
import '../../data/feiniu/models/media_models.dart';
import '../../widgets/poster_card.dart';
import '../auth/auth_controller.dart';
import '../detail/detail_screen.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isLoggedIn) {
    throw StateError('未登录');
  }
  final api = ref.watch(feiniuApiProvider);
  final libraries = await api.getMediaDbList();
  final continueList = await api.getPlayList();

  final libraryItems = <MediaLibrary, List<MediaItem>>{};
  for (final lib in libraries) {
    final library = MediaLibrary.fromJson(lib);
    if (library.guid.isEmpty) continue;
    final resp = await api.getItemList(
      ancestorGuid: library.guid,
      pageSize: 12,
    );
    final list = (resp['data']?['list'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromJson)
        .toList();
    libraryItems[library] = list;
  }

  return HomeData(
    libraries: libraryItems,
    continueWatching: continueList.map(MediaItem.fromJson).toList(),
    serverVersion: auth.serverVersion,
  );
});

class HomeData {
  const HomeData({
    required this.libraries,
    required this.continueWatching,
    required this.serverVersion,
  });

  final Map<MediaLibrary, List<MediaItem>> libraries;
  final List<MediaItem> continueWatching;
  final String serverVersion;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final homeAsync = ref.watch(homeDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feiniu Player'),
        actions: [
          if (auth.serverVersion.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  auth.serverVersion,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: '退出',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(homeDataProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(homeDataProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (data.continueWatching.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.history, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('继续观看', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.continueWatching.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = data.continueWatching[index];
                        final api = ref.read(feiniuApiProvider);
                        return PosterCard(
                          title: item.title,
                          subtitle: item.ancestorName ?? item.type,
                          imageUrl: api.imageUrl(item.poster, width: 240),
                          headers: api.client.imageHeaders,
                          width: 130,
                          watchedSeconds: item.watchedTs,
                          durationSeconds: item.durationSeconds,
                          onTap: () {
                            if (item.type == 'Episode') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    itemGuid: item.guid,
                                    initialSeekSeconds: item.watchedTs,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailScreen(itemGuid: item.guid),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                ...data.libraries.entries.map((entry) {
                  final library = entry.key;
                  final items = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          library.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (items.isEmpty)
                          Text(
                            '暂无内容',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white54,
                            ),
                          )
                        else
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final api = ref.read(feiniuApiProvider);
                                return PosterCard(
                                  title: item.title,
                                  subtitle: item.type,
                                  imageUrl:
                                      api.imageUrl(item.poster, width: 240),
                                  headers: api.client.imageHeaders,
                                  width: 130,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailScreen(
                                          itemGuid: item.guid,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
