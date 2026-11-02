enum SourceType { m3u, xtream }

class Source {
  const Source({
    required this.id,
    required this.nickname,
    required this.type,
    this.m3uUrl,
    this.xtreamHost,
    this.xtreamUsername,
    this.xtreamPassword,
    this.epgUrl,
    this.liveFormat = 'auto',
    this.lastRefreshed,
  });

  final String id;
  final String nickname;
  final SourceType type;
  final String? m3uUrl;
  final String? xtreamHost;
  final String? xtreamUsername;
  final String? xtreamPassword;
  final String? epgUrl;
  /// Xtream live stream format: 'auto' (follow what the provider allows,
  /// else TS), 'ts' or 'hls'. Ignored for M3U playlists.
  final String liveFormat;
  final DateTime? lastRefreshed;

  Source copyWith({
    String? id,
    String? nickname,
    SourceType? type,
    String? m3uUrl,
    String? xtreamHost,
    String? xtreamUsername,
    String? xtreamPassword,
    String? epgUrl,
    String? liveFormat,
    DateTime? lastRefreshed,
  }) {
    return Source(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      type: type ?? this.type,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      xtreamHost: xtreamHost ?? this.xtreamHost,
      xtreamUsername: xtreamUsername ?? this.xtreamUsername,
      xtreamPassword: xtreamPassword ?? this.xtreamPassword,
      epgUrl: epgUrl ?? this.epgUrl,
      liveFormat: liveFormat ?? this.liveFormat,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}
