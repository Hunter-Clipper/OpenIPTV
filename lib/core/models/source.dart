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
    this.lastRefreshed,
  });

  factory Source.fromJson(Map<String, dynamic> json) => Source(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        type: SourceType.values.byName(json['type'] as String),
        m3uUrl: json['m3uUrl'] as String?,
        xtreamHost: json['xtreamHost'] as String?,
        xtreamUsername: json['xtreamUsername'] as String?,
        xtreamPassword: json['xtreamPassword'] as String?,
        epgUrl: json['epgUrl'] as String?,
        lastRefreshed: json['lastRefreshed'] == null
            ? null
            : DateTime.parse(json['lastRefreshed'] as String),
      );

  final String id;
  final String nickname;
  final SourceType type;
  final String? m3uUrl;
  final String? xtreamHost;
  final String? xtreamUsername;
  final String? xtreamPassword;
  final String? epgUrl;
  final DateTime? lastRefreshed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'type': type.name,
        'm3uUrl': m3uUrl,
        'xtreamHost': xtreamHost,
        'xtreamUsername': xtreamUsername,
        'xtreamPassword': xtreamPassword,
        'epgUrl': epgUrl,
        'lastRefreshed': lastRefreshed?.toIso8601String(),
      };

  Source copyWith({
    String? id,
    String? nickname,
    SourceType? type,
    String? m3uUrl,
    String? xtreamHost,
    String? xtreamUsername,
    String? xtreamPassword,
    String? epgUrl,
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
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}
