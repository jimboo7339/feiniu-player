class DanmuComment {
  const DanmuComment({
    required this.text,
    required this.time,
    this.color = 0xFFFFFFFF,
    this.type = 1,
  });

  final String text;
  final double time;
  final int color;
  /// 1=滚动, 4=底部, 5=顶部
  final int type;
}
