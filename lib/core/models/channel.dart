class Channel {
  const Channel({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.streamUrl,
    required this.sortOrder,
    this.logoUrl,
    this.groupTitle,
    this.tvgId,
    this.tvgName,
    this.isFavorite = false,
    this.lastWatchedAt,
  });

  final String id;
  final String sourceId;
  final String name;
  final String? logoUrl;
  final String streamUrl;
  final String? groupTitle;
  final String? tvgId;
  final String? tvgName;
  final bool isFavorite;
  final int sortOrder;
  final DateTime? lastWatchedAt;

  Channel copyWith({
    String? id,
    String? sourceId,
    String? name,
    String? logoUrl,
    String? streamUrl,
    String? groupTitle,
    String? tvgId,
    String? tvgName,
    bool? isFavorite,
    int? sortOrder,
    DateTime? lastWatchedAt,
  }) {
    return Channel(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      groupTitle: groupTitle ?? this.groupTitle,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      isFavorite: isFavorite ?? this.isFavorite,
      sortOrder: sortOrder ?? this.sortOrder,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    );
  }
}
