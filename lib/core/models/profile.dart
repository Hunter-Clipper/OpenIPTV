class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.createdAt,
    required this.updatedAt,
    this.pinHash,
    this.sourceIds = const [],
    this.favoriteChannelIds = const [],
    this.favoriteMovieIds = const [],
    this.favoriteSeriesIds = const [],
    this.defaultCategory = 'All',
    this.channelSortOrder = 'provider',
    this.defaultSubtitleLang = '',
    this.defaultAudioLang = '',
    this.customChannelOrder = const {},
    this.epgOverrides = const {},
    this.hiddenCategories = const [],
    this.isKidsProfile = false,
    this.isAdmin = false,
    this.accentColor = '0A84FF',
    });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarEmoji: json['avatarEmoji'] as String,
        pinHash: json['pinHash'] as String?,
        sourceIds: (json['sourceIds'] as List?)?.cast<String>() ?? const [],
        favoriteChannelIds:
            (json['favoriteChannelIds'] as List?)?.cast<String>() ?? const [],
        favoriteMovieIds:
            (json['favoriteMovieIds'] as List?)?.cast<String>() ?? const [],
        favoriteSeriesIds:
            (json['favoriteSeriesIds'] as List?)?.cast<String>() ?? const [],
        defaultCategory: json['defaultCategory'] as String? ?? 'All',
        channelSortOrder: json['channelSortOrder'] as String? ?? 'provider',
        defaultSubtitleLang: json['defaultSubtitleLang'] as String? ?? '',
        defaultAudioLang: json['defaultAudioLang'] as String? ?? '',
        customChannelOrder: (json['customChannelOrder'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            const {},
        epgOverrides: (json['epgOverrides'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as String),
            ) ??
            const {},
        hiddenCategories:
            (json['hiddenCategories'] as List?)?.cast<String>() ?? const [],
        isKidsProfile: json['isKidsProfile'] as bool? ?? false,
        isAdmin: json['isAdmin'] as bool? ?? false,
        accentColor: json['accentColor'] as String? ?? '0A84FF',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  final String id;
  final String name;
  final String avatarEmoji;
  final String? pinHash;
  final List<String> sourceIds;
  final List<String> favoriteChannelIds;
  final List<String> favoriteMovieIds;
  final List<String> favoriteSeriesIds;
  final String defaultCategory;
  final String channelSortOrder;
  final String defaultSubtitleLang;
  final String defaultAudioLang;
  final Map<String, int> customChannelOrder;
  final Map<String, String> epgOverrides;
  final List<String> hiddenCategories;
  final bool isKidsProfile;
  final bool isAdmin;
  final String accentColor;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPin => pinHash != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarEmoji': avatarEmoji,
        'pinHash': pinHash,
        'sourceIds': sourceIds,
        'favoriteChannelIds': favoriteChannelIds,
        'favoriteMovieIds': favoriteMovieIds,
        'favoriteSeriesIds': favoriteSeriesIds,
        'defaultCategory': defaultCategory,
        'channelSortOrder': channelSortOrder,
        'defaultSubtitleLang': defaultSubtitleLang,
        'defaultAudioLang': defaultAudioLang,
        'customChannelOrder': customChannelOrder,
        'epgOverrides': epgOverrides,
        'hiddenCategories': hiddenCategories,
        'isKidsProfile': isKidsProfile,
        'isAdmin': isAdmin,
        'accentColor': accentColor,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static const List<String> avatarOptions = [
    '👨', '👩', '🧒', '👦', '👧', '🧑', '👴', '👵',
    '🎭', '🌟', '🎮', '🎬', '📺', '🎵', '🏠', '⚽',
    '🎸', '🐱', '🐶', '🦄',
  ];

  Profile copyWith({
    String? id,
    String? name,
    String? avatarEmoji,
    String? pinHash,
    List<String>? sourceIds,
    List<String>? favoriteChannelIds,
    List<String>? favoriteMovieIds,
    List<String>? favoriteSeriesIds,
    String? defaultCategory,
    String? channelSortOrder,
    String? defaultSubtitleLang,
    String? defaultAudioLang,
    Map<String, int>? customChannelOrder,
    Map<String, String>? epgOverrides,
    List<String>? hiddenCategories,
    bool? isKidsProfile,
    bool? isAdmin,
    String? accentColor,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearPin = false,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      sourceIds: sourceIds ?? this.sourceIds,
      favoriteChannelIds: favoriteChannelIds ?? this.favoriteChannelIds,
      favoriteMovieIds: favoriteMovieIds ?? this.favoriteMovieIds,
      favoriteSeriesIds: favoriteSeriesIds ?? this.favoriteSeriesIds,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      channelSortOrder: channelSortOrder ?? this.channelSortOrder,
      defaultSubtitleLang: defaultSubtitleLang ?? this.defaultSubtitleLang,
      defaultAudioLang: defaultAudioLang ?? this.defaultAudioLang,
      customChannelOrder: customChannelOrder ?? this.customChannelOrder,
      epgOverrides: epgOverrides ?? this.epgOverrides,
      hiddenCategories: hiddenCategories ?? this.hiddenCategories,
      isKidsProfile: isKidsProfile ?? this.isKidsProfile,
      isAdmin: isAdmin ?? this.isAdmin,
      accentColor: accentColor ?? this.accentColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
