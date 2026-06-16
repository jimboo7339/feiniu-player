import 'package:flutter/material.dart';

import '../../core/format_utils.dart';

/// 媒体海报卡片，支持观看进度条与续播标记。
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.headers,
    this.width = 120,
    this.watchedSeconds = 0,
    this.durationSeconds = 0,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final Map<String, String> headers;
  final double width;
  final int watchedSeconds;
  final int durationSeconds;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = watchProgress(watchedSeconds, durationSeconds);
    final hasProgress = watchedSeconds > 0;
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(context),
                      if (hasProgress)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                Text(
                                  formatDuration(watchedSeconds),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (hasProgress)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasProgress && durationSeconds > 0
                    ? '${formatDuration(watchedSeconds)} / ${formatDuration(durationSeconds)}'
                    : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: hasProgress
                      ? theme.colorScheme.primary
                      : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (imageUrl.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie_outlined, size: 36),
      );
    }
    return Image.network(
      imageUrl,
      headers: headers,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
