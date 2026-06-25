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
  });

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
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPin => pinHash != null;

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
