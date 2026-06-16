import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feiniu/feiniu_providers.dart';
import '../../data/feiniu/models/media_models.dart';
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
                  style: Theme.of(context).textTheme.labelSmall,
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
                  Text('继续观看', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.continueWatching.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = data.continueWatching[index];
                        return _PosterCard(
                          title: item.title,
                          subtitle: item.type,
                          imageUrl: ref
                              .read(feiniuApiProvider)
                              .imageUrl(item.poster, width: 200),
                          headers: ref.read(feiniuApiProvider).client.imageHeaders,
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
                  const SizedBox(height: 24),
                ],
                ...data.libraries.entries.map((entry) {
                  final library = entry.key;
                  final items = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          library.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          Text(
                            '暂无内容',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _PosterCard(
                                  title: item.title,
                                  subtitle: item.type,
                                  imageUrl: ref
                                      .read(feiniuApiProvider)
                                      .imageUrl(item.poster, width: 240),
                                  headers: ref
                                      .read(feiniuApiProvider)
                                      .client
                                      .imageHeaders,
                                  width: 120,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetailScreen(itemGuid: item.guid),
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

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.headers,
    this.width = 100,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final Map<String, String> headers;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isEmpty
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.movie_outlined, size: 36),
                    )
                  : Image.network(
                      imageUrl,
                      headers: headers,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
        ),
      ),
    );
  }
}
