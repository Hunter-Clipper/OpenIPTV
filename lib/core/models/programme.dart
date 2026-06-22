class Programme {
  const Programme({
    required this.channelId,
    required this.start,
    required this.end,
    required this.title,
    this.description,
    this.category,
    this.episodeNum,
  });

  final String channelId;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? description;
  final String? category;
  final String? episodeNum;

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  Duration get duration => end.difference(start);

  double progressAt(DateTime time) {
    if (time.isBefore(start)) return 0;
    if (time.isAfter(end)) return 1;
    return time.difference(start).inSeconds / duration.inSeconds;
  }
}
