// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SourcesTable extends Sources with TableInfo<$SourcesTable, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nicknameMeta =
      const VerificationMeta('nickname');
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
      'nickname', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _m3uUrlMeta = const VerificationMeta('m3uUrl');
  @override
  late final GeneratedColumn<String> m3uUrl = GeneratedColumn<String>(
      'm3u_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _xtreamHostMeta =
      const VerificationMeta('xtreamHost');
  @override
  late final GeneratedColumn<String> xtreamHost = GeneratedColumn<String>(
      'xtream_host', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _xtreamUsernameMeta =
      const VerificationMeta('xtreamUsername');
  @override
  late final GeneratedColumn<String> xtreamUsername = GeneratedColumn<String>(
      'xtream_username', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _xtreamPasswordMeta =
      const VerificationMeta('xtreamPassword');
  @override
  late final GeneratedColumn<String> xtreamPassword = GeneratedColumn<String>(
      'xtream_password', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _epgUrlMeta = const VerificationMeta('epgUrl');
  @override
  late final GeneratedColumn<String> epgUrl = GeneratedColumn<String>(
      'epg_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastRefreshedMeta =
      const VerificationMeta('lastRefreshed');
  @override
  late final GeneratedColumn<DateTime> lastRefreshed =
      GeneratedColumn<DateTime>('last_refreshed', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        nickname,
        type,
        m3uUrl,
        xtreamHost,
        xtreamUsername,
        xtreamPassword,
        epgUrl,
        lastRefreshed
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(Insertable<SourceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(_nicknameMeta,
          nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta));
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('m3u_url')) {
      context.handle(_m3uUrlMeta,
          m3uUrl.isAcceptableOrUnknown(data['m3u_url']!, _m3uUrlMeta));
    }
    if (data.containsKey('xtream_host')) {
      context.handle(
          _xtreamHostMeta,
          xtreamHost.isAcceptableOrUnknown(
              data['xtream_host']!, _xtreamHostMeta));
    }
    if (data.containsKey('xtream_username')) {
      context.handle(
          _xtreamUsernameMeta,
          xtreamUsername.isAcceptableOrUnknown(
              data['xtream_username']!, _xtreamUsernameMeta));
    }
    if (data.containsKey('xtream_password')) {
      context.handle(
          _xtreamPasswordMeta,
          xtreamPassword.isAcceptableOrUnknown(
              data['xtream_password']!, _xtreamPasswordMeta));
    }
    if (data.containsKey('epg_url')) {
      context.handle(_epgUrlMeta,
          epgUrl.isAcceptableOrUnknown(data['epg_url']!, _epgUrlMeta));
    }
    if (data.containsKey('last_refreshed')) {
      context.handle(
          _lastRefreshedMeta,
          lastRefreshed.isAcceptableOrUnknown(
              data['last_refreshed']!, _lastRefreshedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      nickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nickname'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      m3uUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}m3u_url']),
      xtreamHost: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xtream_host']),
      xtreamUsername: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xtream_username']),
      xtreamPassword: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xtream_password']),
      epgUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}epg_url']),
      lastRefreshed: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_refreshed']),
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final String id;
  final String nickname;
  final String type;
  final String? m3uUrl;
  final String? xtreamHost;
  final String? xtreamUsername;
  final String? xtreamPassword;
  final String? epgUrl;
  final DateTime? lastRefreshed;
  const SourceRow(
      {required this.id,
      required this.nickname,
      required this.type,
      this.m3uUrl,
      this.xtreamHost,
      this.xtreamUsername,
      this.xtreamPassword,
      this.epgUrl,
      this.lastRefreshed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nickname'] = Variable<String>(nickname);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || m3uUrl != null) {
      map['m3u_url'] = Variable<String>(m3uUrl);
    }
    if (!nullToAbsent || xtreamHost != null) {
      map['xtream_host'] = Variable<String>(xtreamHost);
    }
    if (!nullToAbsent || xtreamUsername != null) {
      map['xtream_username'] = Variable<String>(xtreamUsername);
    }
    if (!nullToAbsent || xtreamPassword != null) {
      map['xtream_password'] = Variable<String>(xtreamPassword);
    }
    if (!nullToAbsent || epgUrl != null) {
      map['epg_url'] = Variable<String>(epgUrl);
    }
    if (!nullToAbsent || lastRefreshed != null) {
      map['last_refreshed'] = Variable<DateTime>(lastRefreshed);
    }
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      nickname: Value(nickname),
      type: Value(type),
      m3uUrl:
          m3uUrl == null && nullToAbsent ? const Value.absent() : Value(m3uUrl),
      xtreamHost: xtreamHost == null && nullToAbsent
          ? const Value.absent()
          : Value(xtreamHost),
      xtreamUsername: xtreamUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(xtreamUsername),
      xtreamPassword: xtreamPassword == null && nullToAbsent
          ? const Value.absent()
          : Value(xtreamPassword),
      epgUrl:
          epgUrl == null && nullToAbsent ? const Value.absent() : Value(epgUrl),
      lastRefreshed: lastRefreshed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRefreshed),
    );
  }

  factory SourceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<String>(json['id']),
      nickname: serializer.fromJson<String>(json['nickname']),
      type: serializer.fromJson<String>(json['type']),
      m3uUrl: serializer.fromJson<String?>(json['m3uUrl']),
      xtreamHost: serializer.fromJson<String?>(json['xtreamHost']),
      xtreamUsername: serializer.fromJson<String?>(json['xtreamUsername']),
      xtreamPassword: serializer.fromJson<String?>(json['xtreamPassword']),
      epgUrl: serializer.fromJson<String?>(json['epgUrl']),
      lastRefreshed: serializer.fromJson<DateTime?>(json['lastRefreshed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nickname': serializer.toJson<String>(nickname),
      'type': serializer.toJson<String>(type),
      'm3uUrl': serializer.toJson<String?>(m3uUrl),
      'xtreamHost': serializer.toJson<String?>(xtreamHost),
      'xtreamUsername': serializer.toJson<String?>(xtreamUsername),
      'xtreamPassword': serializer.toJson<String?>(xtreamPassword),
      'epgUrl': serializer.toJson<String?>(epgUrl),
      'lastRefreshed': serializer.toJson<DateTime?>(lastRefreshed),
    };
  }

  SourceRow copyWith(
          {String? id,
          String? nickname,
          String? type,
          Value<String?> m3uUrl = const Value.absent(),
          Value<String?> xtreamHost = const Value.absent(),
          Value<String?> xtreamUsername = const Value.absent(),
          Value<String?> xtreamPassword = const Value.absent(),
          Value<String?> epgUrl = const Value.absent(),
          Value<DateTime?> lastRefreshed = const Value.absent()}) =>
      SourceRow(
        id: id ?? this.id,
        nickname: nickname ?? this.nickname,
        type: type ?? this.type,
        m3uUrl: m3uUrl.present ? m3uUrl.value : this.m3uUrl,
        xtreamHost: xtreamHost.present ? xtreamHost.value : this.xtreamHost,
        xtreamUsername:
            xtreamUsername.present ? xtreamUsername.value : this.xtreamUsername,
        xtreamPassword:
            xtreamPassword.present ? xtreamPassword.value : this.xtreamPassword,
        epgUrl: epgUrl.present ? epgUrl.value : this.epgUrl,
        lastRefreshed:
            lastRefreshed.present ? lastRefreshed.value : this.lastRefreshed,
      );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      type: data.type.present ? data.type.value : this.type,
      m3uUrl: data.m3uUrl.present ? data.m3uUrl.value : this.m3uUrl,
      xtreamHost:
          data.xtreamHost.present ? data.xtreamHost.value : this.xtreamHost,
      xtreamUsername: data.xtreamUsername.present
          ? data.xtreamUsername.value
          : this.xtreamUsername,
      xtreamPassword: data.xtreamPassword.present
          ? data.xtreamPassword.value
          : this.xtreamPassword,
      epgUrl: data.epgUrl.present ? data.epgUrl.value : this.epgUrl,
      lastRefreshed: data.lastRefreshed.present
          ? data.lastRefreshed.value
          : this.lastRefreshed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('type: $type, ')
          ..write('m3uUrl: $m3uUrl, ')
          ..write('xtreamHost: $xtreamHost, ')
          ..write('xtreamUsername: $xtreamUsername, ')
          ..write('xtreamPassword: $xtreamPassword, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('lastRefreshed: $lastRefreshed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nickname, type, m3uUrl, xtreamHost,
      xtreamUsername, xtreamPassword, epgUrl, lastRefreshed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.nickname == this.nickname &&
          other.type == this.type &&
          other.m3uUrl == this.m3uUrl &&
          other.xtreamHost == this.xtreamHost &&
          other.xtreamUsername == this.xtreamUsername &&
          other.xtreamPassword == this.xtreamPassword &&
          other.epgUrl == this.epgUrl &&
          other.lastRefreshed == this.lastRefreshed);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<String> nickname;
  final Value<String> type;
  final Value<String?> m3uUrl;
  final Value<String?> xtreamHost;
  final Value<String?> xtreamUsername;
  final Value<String?> xtreamPassword;
  final Value<String?> epgUrl;
  final Value<DateTime?> lastRefreshed;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.nickname = const Value.absent(),
    this.type = const Value.absent(),
    this.m3uUrl = const Value.absent(),
    this.xtreamHost = const Value.absent(),
    this.xtreamUsername = const Value.absent(),
    this.xtreamPassword = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.lastRefreshed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String nickname,
    required String type,
    this.m3uUrl = const Value.absent(),
    this.xtreamHost = const Value.absent(),
    this.xtreamUsername = const Value.absent(),
    this.xtreamPassword = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.lastRefreshed = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        nickname = Value(nickname),
        type = Value(type);
  static Insertable<SourceRow> custom({
    Expression<String>? id,
    Expression<String>? nickname,
    Expression<String>? type,
    Expression<String>? m3uUrl,
    Expression<String>? xtreamHost,
    Expression<String>? xtreamUsername,
    Expression<String>? xtreamPassword,
    Expression<String>? epgUrl,
    Expression<DateTime>? lastRefreshed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nickname != null) 'nickname': nickname,
      if (type != null) 'type': type,
      if (m3uUrl != null) 'm3u_url': m3uUrl,
      if (xtreamHost != null) 'xtream_host': xtreamHost,
      if (xtreamUsername != null) 'xtream_username': xtreamUsername,
      if (xtreamPassword != null) 'xtream_password': xtreamPassword,
      if (epgUrl != null) 'epg_url': epgUrl,
      if (lastRefreshed != null) 'last_refreshed': lastRefreshed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith(
      {Value<String>? id,
      Value<String>? nickname,
      Value<String>? type,
      Value<String?>? m3uUrl,
      Value<String?>? xtreamHost,
      Value<String?>? xtreamUsername,
      Value<String?>? xtreamPassword,
      Value<String?>? epgUrl,
      Value<DateTime?>? lastRefreshed,
      Value<int>? rowid}) {
    return SourcesCompanion(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      type: type ?? this.type,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      xtreamHost: xtreamHost ?? this.xtreamHost,
      xtreamUsername: xtreamUsername ?? this.xtreamUsername,
      xtreamPassword: xtreamPassword ?? this.xtreamPassword,
      epgUrl: epgUrl ?? this.epgUrl,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (m3uUrl.present) {
      map['m3u_url'] = Variable<String>(m3uUrl.value);
    }
    if (xtreamHost.present) {
      map['xtream_host'] = Variable<String>(xtreamHost.value);
    }
    if (xtreamUsername.present) {
      map['xtream_username'] = Variable<String>(xtreamUsername.value);
    }
    if (xtreamPassword.present) {
      map['xtream_password'] = Variable<String>(xtreamPassword.value);
    }
    if (epgUrl.present) {
      map['epg_url'] = Variable<String>(epgUrl.value);
    }
    if (lastRefreshed.present) {
      map['last_refreshed'] = Variable<DateTime>(lastRefreshed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('type: $type, ')
          ..write('m3uUrl: $m3uUrl, ')
          ..write('xtreamHost: $xtreamHost, ')
          ..write('xtreamUsername: $xtreamUsername, ')
          ..write('xtreamPassword: $xtreamPassword, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('lastRefreshed: $lastRefreshed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels
    with TableInfo<$ChannelsTable, ChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sources (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _logoUrlMeta =
      const VerificationMeta('logoUrl');
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
      'logo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _streamUrlMeta =
      const VerificationMeta('streamUrl');
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
      'stream_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupTitleMeta =
      const VerificationMeta('groupTitle');
  @override
  late final GeneratedColumn<String> groupTitle = GeneratedColumn<String>(
      'group_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tvgIdMeta = const VerificationMeta('tvgId');
  @override
  late final GeneratedColumn<String> tvgId = GeneratedColumn<String>(
      'tvg_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tvgNameMeta =
      const VerificationMeta('tvgName');
  @override
  late final GeneratedColumn<String> tvgName = GeneratedColumn<String>(
      'tvg_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        name,
        logoUrl,
        streamUrl,
        groupTitle,
        tvgId,
        tvgName,
        isFavorite,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(Insertable<ChannelRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('logo_url')) {
      context.handle(_logoUrlMeta,
          logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta));
    }
    if (data.containsKey('stream_url')) {
      context.handle(_streamUrlMeta,
          streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta));
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('group_title')) {
      context.handle(
          _groupTitleMeta,
          groupTitle.isAcceptableOrUnknown(
              data['group_title']!, _groupTitleMeta));
    }
    if (data.containsKey('tvg_id')) {
      context.handle(
          _tvgIdMeta, tvgId.isAcceptableOrUnknown(data['tvg_id']!, _tvgIdMeta));
    }
    if (data.containsKey('tvg_name')) {
      context.handle(_tvgNameMeta,
          tvgName.isAcceptableOrUnknown(data['tvg_name']!, _tvgNameMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      logoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logo_url']),
      streamUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stream_url'])!,
      groupTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_title']),
      tvgId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tvg_id']),
      tvgName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tvg_name']),
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class ChannelRow extends DataClass implements Insertable<ChannelRow> {
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
  const ChannelRow(
      {required this.id,
      required this.sourceId,
      required this.name,
      this.logoUrl,
      required this.streamUrl,
      this.groupTitle,
      this.tvgId,
      this.tvgName,
      required this.isFavorite,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    map['stream_url'] = Variable<String>(streamUrl);
    if (!nullToAbsent || groupTitle != null) {
      map['group_title'] = Variable<String>(groupTitle);
    }
    if (!nullToAbsent || tvgId != null) {
      map['tvg_id'] = Variable<String>(tvgId);
    }
    if (!nullToAbsent || tvgName != null) {
      map['tvg_name'] = Variable<String>(tvgName);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      name: Value(name),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      streamUrl: Value(streamUrl),
      groupTitle: groupTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(groupTitle),
      tvgId:
          tvgId == null && nullToAbsent ? const Value.absent() : Value(tvgId),
      tvgName: tvgName == null && nullToAbsent
          ? const Value.absent()
          : Value(tvgName),
      isFavorite: Value(isFavorite),
      sortOrder: Value(sortOrder),
    );
  }

  factory ChannelRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      name: serializer.fromJson<String>(json['name']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      groupTitle: serializer.fromJson<String?>(json['groupTitle']),
      tvgId: serializer.fromJson<String?>(json['tvgId']),
      tvgName: serializer.fromJson<String?>(json['tvgName']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'name': serializer.toJson<String>(name),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'groupTitle': serializer.toJson<String?>(groupTitle),
      'tvgId': serializer.toJson<String?>(tvgId),
      'tvgName': serializer.toJson<String?>(tvgName),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ChannelRow copyWith(
          {String? id,
          String? sourceId,
          String? name,
          Value<String?> logoUrl = const Value.absent(),
          String? streamUrl,
          Value<String?> groupTitle = const Value.absent(),
          Value<String?> tvgId = const Value.absent(),
          Value<String?> tvgName = const Value.absent(),
          bool? isFavorite,
          int? sortOrder}) =>
      ChannelRow(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        name: name ?? this.name,
        logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
        streamUrl: streamUrl ?? this.streamUrl,
        groupTitle: groupTitle.present ? groupTitle.value : this.groupTitle,
        tvgId: tvgId.present ? tvgId.value : this.tvgId,
        tvgName: tvgName.present ? tvgName.value : this.tvgName,
        isFavorite: isFavorite ?? this.isFavorite,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  ChannelRow copyWithCompanion(ChannelsCompanion data) {
    return ChannelRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      name: data.name.present ? data.name.value : this.name,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      groupTitle:
          data.groupTitle.present ? data.groupTitle.value : this.groupTitle,
      tvgId: data.tvgId.present ? data.tvgId.value : this.tvgId,
      tvgName: data.tvgName.present ? data.tvgName.value : this.tvgName,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('tvgId: $tvgId, ')
          ..write('tvgName: $tvgName, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, name, logoUrl, streamUrl,
      groupTitle, tvgId, tvgName, isFavorite, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.name == this.name &&
          other.logoUrl == this.logoUrl &&
          other.streamUrl == this.streamUrl &&
          other.groupTitle == this.groupTitle &&
          other.tvgId == this.tvgId &&
          other.tvgName == this.tvgName &&
          other.isFavorite == this.isFavorite &&
          other.sortOrder == this.sortOrder);
}

class ChannelsCompanion extends UpdateCompanion<ChannelRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> name;
  final Value<String?> logoUrl;
  final Value<String> streamUrl;
  final Value<String?> groupTitle;
  final Value<String?> tvgId;
  final Value<String?> tvgName;
  final Value<bool> isFavorite;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ChannelsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.groupTitle = const Value.absent(),
    this.tvgId = const Value.absent(),
    this.tvgName = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required String id,
    required String sourceId,
    required String name,
    this.logoUrl = const Value.absent(),
    required String streamUrl,
    this.groupTitle = const Value.absent(),
    this.tvgId = const Value.absent(),
    this.tvgName = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sourceId = Value(sourceId),
        name = Value(name),
        streamUrl = Value(streamUrl);
  static Insertable<ChannelRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? name,
    Expression<String>? logoUrl,
    Expression<String>? streamUrl,
    Expression<String>? groupTitle,
    Expression<String>? tvgId,
    Expression<String>? tvgName,
    Expression<bool>? isFavorite,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (name != null) 'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (groupTitle != null) 'group_title': groupTitle,
      if (tvgId != null) 'tvg_id': tvgId,
      if (tvgName != null) 'tvg_name': tvgName,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sourceId,
      Value<String>? name,
      Value<String?>? logoUrl,
      Value<String>? streamUrl,
      Value<String?>? groupTitle,
      Value<String?>? tvgId,
      Value<String?>? tvgName,
      Value<bool>? isFavorite,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return ChannelsCompanion(
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (groupTitle.present) {
      map['group_title'] = Variable<String>(groupTitle.value);
    }
    if (tvgId.present) {
      map['tvg_id'] = Variable<String>(tvgId.value);
    }
    if (tvgName.present) {
      map['tvg_name'] = Variable<String>(tvgName.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('tvgId: $tvgId, ')
          ..write('tvgName: $tvgName, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgrammesTable extends Programmes
    with TableInfo<$ProgrammesTable, ProgrammeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgrammesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _channelIdMeta =
      const VerificationMeta('channelId');
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
      'channel_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
      'start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<DateTime> end = GeneratedColumn<DateTime>(
      'end', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _episodeNumMeta =
      const VerificationMeta('episodeNum');
  @override
  late final GeneratedColumn<String> episodeNum = GeneratedColumn<String>(
      'episode_num', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, channelId, start, end, title, description, category, episodeNum];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programmes';
  @override
  VerificationContext validateIntegrity(Insertable<ProgrammeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('channel_id')) {
      context.handle(_channelIdMeta,
          channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta));
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
          _startMeta, start.isAcceptableOrUnknown(data['start']!, _startMeta));
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
          _endMeta, end.isAcceptableOrUnknown(data['end']!, _endMeta));
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('episode_num')) {
      context.handle(
          _episodeNumMeta,
          episodeNum.isAcceptableOrUnknown(
              data['episode_num']!, _episodeNumMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgrammeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgrammeRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      channelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel_id'])!,
      start: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start'])!,
      end: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      episodeNum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}episode_num']),
    );
  }

  @override
  $ProgrammesTable createAlias(String alias) {
    return $ProgrammesTable(attachedDatabase, alias);
  }
}

class ProgrammeRow extends DataClass implements Insertable<ProgrammeRow> {
  final int id;
  final String channelId;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? description;
  final String? category;
  final String? episodeNum;
  const ProgrammeRow(
      {required this.id,
      required this.channelId,
      required this.start,
      required this.end,
      required this.title,
      this.description,
      this.category,
      this.episodeNum});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['channel_id'] = Variable<String>(channelId);
    map['start'] = Variable<DateTime>(start);
    map['end'] = Variable<DateTime>(end);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || episodeNum != null) {
      map['episode_num'] = Variable<String>(episodeNum);
    }
    return map;
  }

  ProgrammesCompanion toCompanion(bool nullToAbsent) {
    return ProgrammesCompanion(
      id: Value(id),
      channelId: Value(channelId),
      start: Value(start),
      end: Value(end),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      episodeNum: episodeNum == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNum),
    );
  }

  factory ProgrammeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgrammeRow(
      id: serializer.fromJson<int>(json['id']),
      channelId: serializer.fromJson<String>(json['channelId']),
      start: serializer.fromJson<DateTime>(json['start']),
      end: serializer.fromJson<DateTime>(json['end']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String?>(json['category']),
      episodeNum: serializer.fromJson<String?>(json['episodeNum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'channelId': serializer.toJson<String>(channelId),
      'start': serializer.toJson<DateTime>(start),
      'end': serializer.toJson<DateTime>(end),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String?>(category),
      'episodeNum': serializer.toJson<String?>(episodeNum),
    };
  }

  ProgrammeRow copyWith(
          {int? id,
          String? channelId,
          DateTime? start,
          DateTime? end,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> category = const Value.absent(),
          Value<String?> episodeNum = const Value.absent()}) =>
      ProgrammeRow(
        id: id ?? this.id,
        channelId: channelId ?? this.channelId,
        start: start ?? this.start,
        end: end ?? this.end,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        category: category.present ? category.value : this.category,
        episodeNum: episodeNum.present ? episodeNum.value : this.episodeNum,
      );
  ProgrammeRow copyWithCompanion(ProgrammesCompanion data) {
    return ProgrammeRow(
      id: data.id.present ? data.id.value : this.id,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      category: data.category.present ? data.category.value : this.category,
      episodeNum:
          data.episodeNum.present ? data.episodeNum.value : this.episodeNum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammeRow(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('episodeNum: $episodeNum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, channelId, start, end, title, description, category, episodeNum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgrammeRow &&
          other.id == this.id &&
          other.channelId == this.channelId &&
          other.start == this.start &&
          other.end == this.end &&
          other.title == this.title &&
          other.description == this.description &&
          other.category == this.category &&
          other.episodeNum == this.episodeNum);
}

class ProgrammesCompanion extends UpdateCompanion<ProgrammeRow> {
  final Value<int> id;
  final Value<String> channelId;
  final Value<DateTime> start;
  final Value<DateTime> end;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> category;
  final Value<String?> episodeNum;
  const ProgrammesCompanion({
    this.id = const Value.absent(),
    this.channelId = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.episodeNum = const Value.absent(),
  });
  ProgrammesCompanion.insert({
    this.id = const Value.absent(),
    required String channelId,
    required DateTime start,
    required DateTime end,
    required String title,
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.episodeNum = const Value.absent(),
  })  : channelId = Value(channelId),
        start = Value(start),
        end = Value(end),
        title = Value(title);
  static Insertable<ProgrammeRow> custom({
    Expression<int>? id,
    Expression<String>? channelId,
    Expression<DateTime>? start,
    Expression<DateTime>? end,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? episodeNum,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (channelId != null) 'channel_id': channelId,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (episodeNum != null) 'episode_num': episodeNum,
    });
  }

  ProgrammesCompanion copyWith(
      {Value<int>? id,
      Value<String>? channelId,
      Value<DateTime>? start,
      Value<DateTime>? end,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? category,
      Value<String?>? episodeNum}) {
    return ProgrammesCompanion(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      start: start ?? this.start,
      end: end ?? this.end,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      episodeNum: episodeNum ?? this.episodeNum,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<DateTime>(end.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (episodeNum.present) {
      map['episode_num'] = Variable<String>(episodeNum.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammesCompanion(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('episodeNum: $episodeNum')
          ..write(')'))
        .toString();
  }
}

class $MoviesTable extends Movies with TableInfo<$MoviesTable, MovieRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoviesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sources (id)'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterUrlMeta =
      const VerificationMeta('posterUrl');
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
      'poster_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _streamUrlMeta =
      const VerificationMeta('streamUrl');
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
      'stream_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
      'year', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
      'rating', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _watchedDurationSecondsMeta =
      const VerificationMeta('watchedDurationSeconds');
  @override
  late final GeneratedColumn<int> watchedDurationSeconds = GeneratedColumn<int>(
      'watched_duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _totalDurationSecondsMeta =
      const VerificationMeta('totalDurationSeconds');
  @override
  late final GeneratedColumn<int> totalDurationSeconds = GeneratedColumn<int>(
      'total_duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastWatchedAtMeta =
      const VerificationMeta('lastWatchedAt');
  @override
  late final GeneratedColumn<DateTime> lastWatchedAt =
      GeneratedColumn<DateTime>('last_watched_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        title,
        posterUrl,
        streamUrl,
        genre,
        year,
        rating,
        description,
        watchedDurationSeconds,
        totalDurationSeconds,
        lastWatchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies';
  @override
  VerificationContext validateIntegrity(Insertable<MovieRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(_posterUrlMeta,
          posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta));
    }
    if (data.containsKey('stream_url')) {
      context.handle(_streamUrlMeta,
          streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta));
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('watched_duration_seconds')) {
      context.handle(
          _watchedDurationSecondsMeta,
          watchedDurationSeconds.isAcceptableOrUnknown(
              data['watched_duration_seconds']!, _watchedDurationSecondsMeta));
    }
    if (data.containsKey('total_duration_seconds')) {
      context.handle(
          _totalDurationSecondsMeta,
          totalDurationSeconds.isAcceptableOrUnknown(
              data['total_duration_seconds']!, _totalDurationSecondsMeta));
    }
    if (data.containsKey('last_watched_at')) {
      context.handle(
          _lastWatchedAtMeta,
          lastWatchedAt.isAcceptableOrUnknown(
              data['last_watched_at']!, _lastWatchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MovieRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovieRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_url']),
      streamUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stream_url'])!,
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}year']),
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rating']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      watchedDurationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}watched_duration_seconds']),
      totalDurationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_duration_seconds']),
      lastWatchedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_watched_at']),
    );
  }

  @override
  $MoviesTable createAlias(String alias) {
    return $MoviesTable(attachedDatabase, alias);
  }
}

class MovieRow extends DataClass implements Insertable<MovieRow> {
  final String id;
  final String sourceId;
  final String title;
  final String? posterUrl;
  final String streamUrl;
  final String? genre;
  final String? year;
  final String? rating;
  final String? description;
  final int? watchedDurationSeconds;
  final int? totalDurationSeconds;
  final DateTime? lastWatchedAt;
  const MovieRow(
      {required this.id,
      required this.sourceId,
      required this.title,
      this.posterUrl,
      required this.streamUrl,
      this.genre,
      this.year,
      this.rating,
      this.description,
      this.watchedDurationSeconds,
      this.totalDurationSeconds,
      this.lastWatchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    map['stream_url'] = Variable<String>(streamUrl);
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<String>(rating);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || watchedDurationSeconds != null) {
      map['watched_duration_seconds'] = Variable<int>(watchedDurationSeconds);
    }
    if (!nullToAbsent || totalDurationSeconds != null) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds);
    }
    if (!nullToAbsent || lastWatchedAt != null) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt);
    }
    return map;
  }

  MoviesCompanion toCompanion(bool nullToAbsent) {
    return MoviesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      title: Value(title),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      streamUrl: Value(streamUrl),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      rating:
          rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      watchedDurationSeconds: watchedDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(watchedDurationSeconds),
      totalDurationSeconds: totalDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDurationSeconds),
      lastWatchedAt: lastWatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastWatchedAt),
    );
  }

  factory MovieRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovieRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<String?>(json['year']),
      rating: serializer.fromJson<String?>(json['rating']),
      description: serializer.fromJson<String?>(json['description']),
      watchedDurationSeconds:
          serializer.fromJson<int?>(json['watchedDurationSeconds']),
      totalDurationSeconds:
          serializer.fromJson<int?>(json['totalDurationSeconds']),
      lastWatchedAt: serializer.fromJson<DateTime?>(json['lastWatchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<String?>(year),
      'rating': serializer.toJson<String?>(rating),
      'description': serializer.toJson<String?>(description),
      'watchedDurationSeconds': serializer.toJson<int?>(watchedDurationSeconds),
      'totalDurationSeconds': serializer.toJson<int?>(totalDurationSeconds),
      'lastWatchedAt': serializer.toJson<DateTime?>(lastWatchedAt),
    };
  }

  MovieRow copyWith(
          {String? id,
          String? sourceId,
          String? title,
          Value<String?> posterUrl = const Value.absent(),
          String? streamUrl,
          Value<String?> genre = const Value.absent(),
          Value<String?> year = const Value.absent(),
          Value<String?> rating = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<int?> watchedDurationSeconds = const Value.absent(),
          Value<int?> totalDurationSeconds = const Value.absent(),
          Value<DateTime?> lastWatchedAt = const Value.absent()}) =>
      MovieRow(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        title: title ?? this.title,
        posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
        streamUrl: streamUrl ?? this.streamUrl,
        genre: genre.present ? genre.value : this.genre,
        year: year.present ? year.value : this.year,
        rating: rating.present ? rating.value : this.rating,
        description: description.present ? description.value : this.description,
        watchedDurationSeconds: watchedDurationSeconds.present
            ? watchedDurationSeconds.value
            : this.watchedDurationSeconds,
        totalDurationSeconds: totalDurationSeconds.present
            ? totalDurationSeconds.value
            : this.totalDurationSeconds,
        lastWatchedAt:
            lastWatchedAt.present ? lastWatchedAt.value : this.lastWatchedAt,
      );
  MovieRow copyWithCompanion(MoviesCompanion data) {
    return MovieRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      rating: data.rating.present ? data.rating.value : this.rating,
      description:
          data.description.present ? data.description.value : this.description,
      watchedDurationSeconds: data.watchedDurationSeconds.present
          ? data.watchedDurationSeconds.value
          : this.watchedDurationSeconds,
      totalDurationSeconds: data.totalDurationSeconds.present
          ? data.totalDurationSeconds.value
          : this.totalDurationSeconds,
      lastWatchedAt: data.lastWatchedAt.present
          ? data.lastWatchedAt.value
          : this.lastWatchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovieRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('rating: $rating, ')
          ..write('description: $description, ')
          ..write('watchedDurationSeconds: $watchedDurationSeconds, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('lastWatchedAt: $lastWatchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sourceId,
      title,
      posterUrl,
      streamUrl,
      genre,
      year,
      rating,
      description,
      watchedDurationSeconds,
      totalDurationSeconds,
      lastWatchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.posterUrl == this.posterUrl &&
          other.streamUrl == this.streamUrl &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.rating == this.rating &&
          other.description == this.description &&
          other.watchedDurationSeconds == this.watchedDurationSeconds &&
          other.totalDurationSeconds == this.totalDurationSeconds &&
          other.lastWatchedAt == this.lastWatchedAt);
}

class MoviesCompanion extends UpdateCompanion<MovieRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String?> posterUrl;
  final Value<String> streamUrl;
  final Value<String?> genre;
  final Value<String?> year;
  final Value<String?> rating;
  final Value<String?> description;
  final Value<int?> watchedDurationSeconds;
  final Value<int?> totalDurationSeconds;
  final Value<DateTime?> lastWatchedAt;
  final Value<int> rowid;
  const MoviesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.rating = const Value.absent(),
    this.description = const Value.absent(),
    this.watchedDurationSeconds = const Value.absent(),
    this.totalDurationSeconds = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoviesCompanion.insert({
    required String id,
    required String sourceId,
    required String title,
    this.posterUrl = const Value.absent(),
    required String streamUrl,
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.rating = const Value.absent(),
    this.description = const Value.absent(),
    this.watchedDurationSeconds = const Value.absent(),
    this.totalDurationSeconds = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sourceId = Value(sourceId),
        title = Value(title),
        streamUrl = Value(streamUrl);
  static Insertable<MovieRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? posterUrl,
    Expression<String>? streamUrl,
    Expression<String>? genre,
    Expression<String>? year,
    Expression<String>? rating,
    Expression<String>? description,
    Expression<int>? watchedDurationSeconds,
    Expression<int>? totalDurationSeconds,
    Expression<DateTime>? lastWatchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (rating != null) 'rating': rating,
      if (description != null) 'description': description,
      if (watchedDurationSeconds != null)
        'watched_duration_seconds': watchedDurationSeconds,
      if (totalDurationSeconds != null)
        'total_duration_seconds': totalDurationSeconds,
      if (lastWatchedAt != null) 'last_watched_at': lastWatchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoviesCompanion copyWith(
      {Value<String>? id,
      Value<String>? sourceId,
      Value<String>? title,
      Value<String?>? posterUrl,
      Value<String>? streamUrl,
      Value<String?>? genre,
      Value<String?>? year,
      Value<String?>? rating,
      Value<String?>? description,
      Value<int?>? watchedDurationSeconds,
      Value<int?>? totalDurationSeconds,
      Value<DateTime?>? lastWatchedAt,
      Value<int>? rowid}) {
    return MoviesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      watchedDurationSeconds:
          watchedDurationSeconds ?? this.watchedDurationSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (watchedDurationSeconds.present) {
      map['watched_duration_seconds'] =
          Variable<int>(watchedDurationSeconds.value);
    }
    if (totalDurationSeconds.present) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds.value);
    }
    if (lastWatchedAt.present) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('rating: $rating, ')
          ..write('description: $description, ')
          ..write('watchedDurationSeconds: $watchedDurationSeconds, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesEntriesTable extends SeriesEntries
    with TableInfo<$SeriesEntriesTable, SeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sources (id)'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterUrlMeta =
      const VerificationMeta('posterUrl');
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
      'poster_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
      'year', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sourceId, title, posterUrl, genre, year, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SeriesRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(_posterUrlMeta,
          posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta));
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_url']),
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}year']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
    );
  }

  @override
  $SeriesEntriesTable createAlias(String alias) {
    return $SeriesEntriesTable(attachedDatabase, alias);
  }
}

class SeriesRow extends DataClass implements Insertable<SeriesRow> {
  final String id;
  final String sourceId;
  final String title;
  final String? posterUrl;
  final String? genre;
  final String? year;
  final String? description;
  const SeriesRow(
      {required this.id,
      required this.sourceId,
      required this.title,
      this.posterUrl,
      this.genre,
      this.year,
      this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  SeriesEntriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesEntriesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      title: Value(title),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory SeriesRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<String?>(json['year']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<String?>(year),
      'description': serializer.toJson<String?>(description),
    };
  }

  SeriesRow copyWith(
          {String? id,
          String? sourceId,
          String? title,
          Value<String?> posterUrl = const Value.absent(),
          Value<String?> genre = const Value.absent(),
          Value<String?> year = const Value.absent(),
          Value<String?> description = const Value.absent()}) =>
      SeriesRow(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        title: title ?? this.title,
        posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
        genre: genre.present ? genre.value : this.genre,
        year: year.present ? year.value : this.year,
        description: description.present ? description.value : this.description,
      );
  SeriesRow copyWithCompanion(SeriesEntriesCompanion data) {
    return SeriesRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      description:
          data.description.present ? data.description.value : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sourceId, title, posterUrl, genre, year, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.posterUrl == this.posterUrl &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.description == this.description);
}

class SeriesEntriesCompanion extends UpdateCompanion<SeriesRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String?> posterUrl;
  final Value<String?> genre;
  final Value<String?> year;
  final Value<String?> description;
  final Value<int> rowid;
  const SeriesEntriesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesEntriesCompanion.insert({
    required String id,
    required String sourceId,
    required String title,
    this.posterUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sourceId = Value(sourceId),
        title = Value(title);
  static Insertable<SeriesRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? posterUrl,
    Expression<String>? genre,
    Expression<String>? year,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? sourceId,
      Value<String>? title,
      Value<String?>? posterUrl,
      Value<String?>? genre,
      Value<String?>? year,
      Value<String?>? description,
      Value<int>? rowid}) {
    return SeriesEntriesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes
    with TableInfo<$EpisodesTable, EpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seriesIdMeta =
      const VerificationMeta('seriesId');
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
      'series_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sources (id)'));
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
      'season', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _episodeMeta =
      const VerificationMeta('episode');
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
      'episode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _streamUrlMeta =
      const VerificationMeta('streamUrl');
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
      'stream_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stillUrlMeta =
      const VerificationMeta('stillUrl');
  @override
  late final GeneratedColumn<String> stillUrl = GeneratedColumn<String>(
      'still_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _watchedDurationSecondsMeta =
      const VerificationMeta('watchedDurationSeconds');
  @override
  late final GeneratedColumn<int> watchedDurationSeconds = GeneratedColumn<int>(
      'watched_duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _totalDurationSecondsMeta =
      const VerificationMeta('totalDurationSeconds');
  @override
  late final GeneratedColumn<int> totalDurationSeconds = GeneratedColumn<int>(
      'total_duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastWatchedAtMeta =
      const VerificationMeta('lastWatchedAt');
  @override
  late final GeneratedColumn<DateTime> lastWatchedAt =
      GeneratedColumn<DateTime>('last_watched_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        seriesId,
        sourceId,
        season,
        episode,
        title,
        streamUrl,
        stillUrl,
        watchedDurationSeconds,
        totalDurationSeconds,
        lastWatchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(Insertable<EpisodeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(_seriesIdMeta,
          seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta));
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('season')) {
      context.handle(_seasonMeta,
          season.isAcceptableOrUnknown(data['season']!, _seasonMeta));
    } else if (isInserting) {
      context.missing(_seasonMeta);
    }
    if (data.containsKey('episode')) {
      context.handle(_episodeMeta,
          episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta));
    } else if (isInserting) {
      context.missing(_episodeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('stream_url')) {
      context.handle(_streamUrlMeta,
          streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta));
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('still_url')) {
      context.handle(_stillUrlMeta,
          stillUrl.isAcceptableOrUnknown(data['still_url']!, _stillUrlMeta));
    }
    if (data.containsKey('watched_duration_seconds')) {
      context.handle(
          _watchedDurationSecondsMeta,
          watchedDurationSeconds.isAcceptableOrUnknown(
              data['watched_duration_seconds']!, _watchedDurationSecondsMeta));
    }
    if (data.containsKey('total_duration_seconds')) {
      context.handle(
          _totalDurationSecondsMeta,
          totalDurationSeconds.isAcceptableOrUnknown(
              data['total_duration_seconds']!, _totalDurationSecondsMeta));
    }
    if (data.containsKey('last_watched_at')) {
      context.handle(
          _lastWatchedAtMeta,
          lastWatchedAt.isAcceptableOrUnknown(
              data['last_watched_at']!, _lastWatchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      seriesId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}series_id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      season: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}season'])!,
      episode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episode'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      streamUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stream_url'])!,
      stillUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}still_url']),
      watchedDurationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}watched_duration_seconds']),
      totalDurationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_duration_seconds']),
      lastWatchedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_watched_at']),
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class EpisodeRow extends DataClass implements Insertable<EpisodeRow> {
  final String id;
  final String seriesId;
  final String sourceId;
  final int season;
  final int episode;
  final String title;
  final String streamUrl;
  final String? stillUrl;
  final int? watchedDurationSeconds;
  final int? totalDurationSeconds;
  final DateTime? lastWatchedAt;
  const EpisodeRow(
      {required this.id,
      required this.seriesId,
      required this.sourceId,
      required this.season,
      required this.episode,
      required this.title,
      required this.streamUrl,
      this.stillUrl,
      this.watchedDurationSeconds,
      this.totalDurationSeconds,
      this.lastWatchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['series_id'] = Variable<String>(seriesId);
    map['source_id'] = Variable<String>(sourceId);
    map['season'] = Variable<int>(season);
    map['episode'] = Variable<int>(episode);
    map['title'] = Variable<String>(title);
    map['stream_url'] = Variable<String>(streamUrl);
    if (!nullToAbsent || stillUrl != null) {
      map['still_url'] = Variable<String>(stillUrl);
    }
    if (!nullToAbsent || watchedDurationSeconds != null) {
      map['watched_duration_seconds'] = Variable<int>(watchedDurationSeconds);
    }
    if (!nullToAbsent || totalDurationSeconds != null) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds);
    }
    if (!nullToAbsent || lastWatchedAt != null) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt);
    }
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      seriesId: Value(seriesId),
      sourceId: Value(sourceId),
      season: Value(season),
      episode: Value(episode),
      title: Value(title),
      streamUrl: Value(streamUrl),
      stillUrl: stillUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(stillUrl),
      watchedDurationSeconds: watchedDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(watchedDurationSeconds),
      totalDurationSeconds: totalDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDurationSeconds),
      lastWatchedAt: lastWatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastWatchedAt),
    );
  }

  factory EpisodeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeRow(
      id: serializer.fromJson<String>(json['id']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      season: serializer.fromJson<int>(json['season']),
      episode: serializer.fromJson<int>(json['episode']),
      title: serializer.fromJson<String>(json['title']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      stillUrl: serializer.fromJson<String?>(json['stillUrl']),
      watchedDurationSeconds:
          serializer.fromJson<int?>(json['watchedDurationSeconds']),
      totalDurationSeconds:
          serializer.fromJson<int?>(json['totalDurationSeconds']),
      lastWatchedAt: serializer.fromJson<DateTime?>(json['lastWatchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'seriesId': serializer.toJson<String>(seriesId),
      'sourceId': serializer.toJson<String>(sourceId),
      'season': serializer.toJson<int>(season),
      'episode': serializer.toJson<int>(episode),
      'title': serializer.toJson<String>(title),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'stillUrl': serializer.toJson<String?>(stillUrl),
      'watchedDurationSeconds': serializer.toJson<int?>(watchedDurationSeconds),
      'totalDurationSeconds': serializer.toJson<int?>(totalDurationSeconds),
      'lastWatchedAt': serializer.toJson<DateTime?>(lastWatchedAt),
    };
  }

  EpisodeRow copyWith(
          {String? id,
          String? seriesId,
          String? sourceId,
          int? season,
          int? episode,
          String? title,
          String? streamUrl,
          Value<String?> stillUrl = const Value.absent(),
          Value<int?> watchedDurationSeconds = const Value.absent(),
          Value<int?> totalDurationSeconds = const Value.absent(),
          Value<DateTime?> lastWatchedAt = const Value.absent()}) =>
      EpisodeRow(
        id: id ?? this.id,
        seriesId: seriesId ?? this.seriesId,
        sourceId: sourceId ?? this.sourceId,
        season: season ?? this.season,
        episode: episode ?? this.episode,
        title: title ?? this.title,
        streamUrl: streamUrl ?? this.streamUrl,
        stillUrl: stillUrl.present ? stillUrl.value : this.stillUrl,
        watchedDurationSeconds: watchedDurationSeconds.present
            ? watchedDurationSeconds.value
            : this.watchedDurationSeconds,
        totalDurationSeconds: totalDurationSeconds.present
            ? totalDurationSeconds.value
            : this.totalDurationSeconds,
        lastWatchedAt:
            lastWatchedAt.present ? lastWatchedAt.value : this.lastWatchedAt,
      );
  EpisodeRow copyWithCompanion(EpisodesCompanion data) {
    return EpisodeRow(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      title: data.title.present ? data.title.value : this.title,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      stillUrl: data.stillUrl.present ? data.stillUrl.value : this.stillUrl,
      watchedDurationSeconds: data.watchedDurationSeconds.present
          ? data.watchedDurationSeconds.value
          : this.watchedDurationSeconds,
      totalDurationSeconds: data.totalDurationSeconds.present
          ? data.totalDurationSeconds.value
          : this.totalDurationSeconds,
      lastWatchedAt: data.lastWatchedAt.present
          ? data.lastWatchedAt.value
          : this.lastWatchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeRow(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('sourceId: $sourceId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('title: $title, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('watchedDurationSeconds: $watchedDurationSeconds, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('lastWatchedAt: $lastWatchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      seriesId,
      sourceId,
      season,
      episode,
      title,
      streamUrl,
      stillUrl,
      watchedDurationSeconds,
      totalDurationSeconds,
      lastWatchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeRow &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.sourceId == this.sourceId &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.title == this.title &&
          other.streamUrl == this.streamUrl &&
          other.stillUrl == this.stillUrl &&
          other.watchedDurationSeconds == this.watchedDurationSeconds &&
          other.totalDurationSeconds == this.totalDurationSeconds &&
          other.lastWatchedAt == this.lastWatchedAt);
}

class EpisodesCompanion extends UpdateCompanion<EpisodeRow> {
  final Value<String> id;
  final Value<String> seriesId;
  final Value<String> sourceId;
  final Value<int> season;
  final Value<int> episode;
  final Value<String> title;
  final Value<String> streamUrl;
  final Value<String?> stillUrl;
  final Value<int?> watchedDurationSeconds;
  final Value<int?> totalDurationSeconds;
  final Value<DateTime?> lastWatchedAt;
  final Value<int> rowid;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.title = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.watchedDurationSeconds = const Value.absent(),
    this.totalDurationSeconds = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesCompanion.insert({
    required String id,
    required String seriesId,
    required String sourceId,
    required int season,
    required int episode,
    required String title,
    required String streamUrl,
    this.stillUrl = const Value.absent(),
    this.watchedDurationSeconds = const Value.absent(),
    this.totalDurationSeconds = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        seriesId = Value(seriesId),
        sourceId = Value(sourceId),
        season = Value(season),
        episode = Value(episode),
        title = Value(title),
        streamUrl = Value(streamUrl);
  static Insertable<EpisodeRow> custom({
    Expression<String>? id,
    Expression<String>? seriesId,
    Expression<String>? sourceId,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<String>? title,
    Expression<String>? streamUrl,
    Expression<String>? stillUrl,
    Expression<int>? watchedDurationSeconds,
    Expression<int>? totalDurationSeconds,
    Expression<DateTime>? lastWatchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (sourceId != null) 'source_id': sourceId,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (title != null) 'title': title,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (stillUrl != null) 'still_url': stillUrl,
      if (watchedDurationSeconds != null)
        'watched_duration_seconds': watchedDurationSeconds,
      if (totalDurationSeconds != null)
        'total_duration_seconds': totalDurationSeconds,
      if (lastWatchedAt != null) 'last_watched_at': lastWatchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesCompanion copyWith(
      {Value<String>? id,
      Value<String>? seriesId,
      Value<String>? sourceId,
      Value<int>? season,
      Value<int>? episode,
      Value<String>? title,
      Value<String>? streamUrl,
      Value<String?>? stillUrl,
      Value<int?>? watchedDurationSeconds,
      Value<int?>? totalDurationSeconds,
      Value<DateTime?>? lastWatchedAt,
      Value<int>? rowid}) {
    return EpisodesCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      sourceId: sourceId ?? this.sourceId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      title: title ?? this.title,
      streamUrl: streamUrl ?? this.streamUrl,
      stillUrl: stillUrl ?? this.stillUrl,
      watchedDurationSeconds:
          watchedDurationSeconds ?? this.watchedDurationSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (stillUrl.present) {
      map['still_url'] = Variable<String>(stillUrl.value);
    }
    if (watchedDurationSeconds.present) {
      map['watched_duration_seconds'] =
          Variable<int>(watchedDurationSeconds.value);
    }
    if (totalDurationSeconds.present) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds.value);
    }
    if (lastWatchedAt.present) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('sourceId: $sourceId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('title: $title, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('watchedDurationSeconds: $watchedDurationSeconds, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarEmojiMeta =
      const VerificationMeta('avatarEmoji');
  @override
  late final GeneratedColumn<String> avatarEmoji = GeneratedColumn<String>(
      'avatar_emoji', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pinHashMeta =
      const VerificationMeta('pinHash');
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
      'pin_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceIdsMeta =
      const VerificationMeta('sourceIds');
  @override
  late final GeneratedColumn<String> sourceIds = GeneratedColumn<String>(
      'source_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _favoriteChannelIdsMeta =
      const VerificationMeta('favoriteChannelIds');
  @override
  late final GeneratedColumn<String> favoriteChannelIds =
      GeneratedColumn<String>('favorite_channel_ids', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _favoriteMovieIdsMeta =
      const VerificationMeta('favoriteMovieIds');
  @override
  late final GeneratedColumn<String> favoriteMovieIds = GeneratedColumn<String>(
      'favorite_movie_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _favoriteSeriesIdsMeta =
      const VerificationMeta('favoriteSeriesIds');
  @override
  late final GeneratedColumn<String> favoriteSeriesIds =
      GeneratedColumn<String>('favorite_series_ids', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _defaultCategoryMeta =
      const VerificationMeta('defaultCategory');
  @override
  late final GeneratedColumn<String> defaultCategory = GeneratedColumn<String>(
      'default_category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('All'));
  static const VerificationMeta _channelSortOrderMeta =
      const VerificationMeta('channelSortOrder');
  @override
  late final GeneratedColumn<String> channelSortOrder = GeneratedColumn<String>(
      'channel_sort_order', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('provider'));
  static const VerificationMeta _defaultSubtitleLangMeta =
      const VerificationMeta('defaultSubtitleLang');
  @override
  late final GeneratedColumn<String> defaultSubtitleLang =
      GeneratedColumn<String>('default_subtitle_lang', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant(''));
  static const VerificationMeta _defaultAudioLangMeta =
      const VerificationMeta('defaultAudioLang');
  @override
  late final GeneratedColumn<String> defaultAudioLang = GeneratedColumn<String>(
      'default_audio_lang', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _customChannelOrderMeta =
      const VerificationMeta('customChannelOrder');
  @override
  late final GeneratedColumn<String> customChannelOrder =
      GeneratedColumn<String>('custom_channel_order', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('{}'));
  static const VerificationMeta _epgOverridesMeta =
      const VerificationMeta('epgOverrides');
  @override
  late final GeneratedColumn<String> epgOverrides = GeneratedColumn<String>(
      'epg_overrides', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _hiddenCategoriesMeta =
      const VerificationMeta('hiddenCategories');
  @override
  late final GeneratedColumn<String> hiddenCategories = GeneratedColumn<String>(
      'hidden_categories', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        avatarEmoji,
        pinHash,
        sourceIds,
        favoriteChannelIds,
        favoriteMovieIds,
        favoriteSeriesIds,
        defaultCategory,
        channelSortOrder,
        defaultSubtitleLang,
        defaultAudioLang,
        customChannelOrder,
        epgOverrides,
        hiddenCategories,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<ProfileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_emoji')) {
      context.handle(
          _avatarEmojiMeta,
          avatarEmoji.isAcceptableOrUnknown(
              data['avatar_emoji']!, _avatarEmojiMeta));
    } else if (isInserting) {
      context.missing(_avatarEmojiMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(_pinHashMeta,
          pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta));
    }
    if (data.containsKey('source_ids')) {
      context.handle(_sourceIdsMeta,
          sourceIds.isAcceptableOrUnknown(data['source_ids']!, _sourceIdsMeta));
    }
    if (data.containsKey('favorite_channel_ids')) {
      context.handle(
          _favoriteChannelIdsMeta,
          favoriteChannelIds.isAcceptableOrUnknown(
              data['favorite_channel_ids']!, _favoriteChannelIdsMeta));
    }
    if (data.containsKey('favorite_movie_ids')) {
      context.handle(
          _favoriteMovieIdsMeta,
          favoriteMovieIds.isAcceptableOrUnknown(
              data['favorite_movie_ids']!, _favoriteMovieIdsMeta));
    }
    if (data.containsKey('favorite_series_ids')) {
      context.handle(
          _favoriteSeriesIdsMeta,
          favoriteSeriesIds.isAcceptableOrUnknown(
              data['favorite_series_ids']!, _favoriteSeriesIdsMeta));
    }
    if (data.containsKey('default_category')) {
      context.handle(
          _defaultCategoryMeta,
          defaultCategory.isAcceptableOrUnknown(
              data['default_category']!, _defaultCategoryMeta));
    }
    if (data.containsKey('channel_sort_order')) {
      context.handle(
          _channelSortOrderMeta,
          channelSortOrder.isAcceptableOrUnknown(
              data['channel_sort_order']!, _channelSortOrderMeta));
    }
    if (data.containsKey('default_subtitle_lang')) {
      context.handle(
          _defaultSubtitleLangMeta,
          defaultSubtitleLang.isAcceptableOrUnknown(
              data['default_subtitle_lang']!, _defaultSubtitleLangMeta));
    }
    if (data.containsKey('default_audio_lang')) {
      context.handle(
          _defaultAudioLangMeta,
          defaultAudioLang.isAcceptableOrUnknown(
              data['default_audio_lang']!, _defaultAudioLangMeta));
    }
    if (data.containsKey('custom_channel_order')) {
      context.handle(
          _customChannelOrderMeta,
          customChannelOrder.isAcceptableOrUnknown(
              data['custom_channel_order']!, _customChannelOrderMeta));
    }
    if (data.containsKey('epg_overrides')) {
      context.handle(
          _epgOverridesMeta,
          epgOverrides.isAcceptableOrUnknown(
              data['epg_overrides']!, _epgOverridesMeta));
    }
    if (data.containsKey('hidden_categories')) {
      context.handle(
          _hiddenCategoriesMeta,
          hiddenCategories.isAcceptableOrUnknown(
              data['hidden_categories']!, _hiddenCategoriesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      avatarEmoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_emoji'])!,
      pinHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pin_hash']),
      sourceIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_ids'])!,
      favoriteChannelIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}favorite_channel_ids'])!,
      favoriteMovieIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}favorite_movie_ids'])!,
      favoriteSeriesIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}favorite_series_ids'])!,
      defaultCategory: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}default_category'])!,
      channelSortOrder: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}channel_sort_order'])!,
      defaultSubtitleLang: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}default_subtitle_lang'])!,
      defaultAudioLang: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}default_audio_lang'])!,
      customChannelOrder: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}custom_channel_order'])!,
      epgOverrides: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}epg_overrides'])!,
      hiddenCategories: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}hidden_categories'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String name;
  final String avatarEmoji;
  final String? pinHash;
  final String sourceIds;
  final String favoriteChannelIds;
  final String favoriteMovieIds;
  final String favoriteSeriesIds;
  final String defaultCategory;
  final String channelSortOrder;
  final String defaultSubtitleLang;
  final String defaultAudioLang;
  final String customChannelOrder;
  final String epgOverrides;
  final String hiddenCategories;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProfileRow(
      {required this.id,
      required this.name,
      required this.avatarEmoji,
      this.pinHash,
      required this.sourceIds,
      required this.favoriteChannelIds,
      required this.favoriteMovieIds,
      required this.favoriteSeriesIds,
      required this.defaultCategory,
      required this.channelSortOrder,
      required this.defaultSubtitleLang,
      required this.defaultAudioLang,
      required this.customChannelOrder,
      required this.epgOverrides,
      required this.hiddenCategories,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['avatar_emoji'] = Variable<String>(avatarEmoji);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    map['source_ids'] = Variable<String>(sourceIds);
    map['favorite_channel_ids'] = Variable<String>(favoriteChannelIds);
    map['favorite_movie_ids'] = Variable<String>(favoriteMovieIds);
    map['favorite_series_ids'] = Variable<String>(favoriteSeriesIds);
    map['default_category'] = Variable<String>(defaultCategory);
    map['channel_sort_order'] = Variable<String>(channelSortOrder);
    map['default_subtitle_lang'] = Variable<String>(defaultSubtitleLang);
    map['default_audio_lang'] = Variable<String>(defaultAudioLang);
    map['custom_channel_order'] = Variable<String>(customChannelOrder);
    map['epg_overrides'] = Variable<String>(epgOverrides);
    map['hidden_categories'] = Variable<String>(hiddenCategories);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      avatarEmoji: Value(avatarEmoji),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      sourceIds: Value(sourceIds),
      favoriteChannelIds: Value(favoriteChannelIds),
      favoriteMovieIds: Value(favoriteMovieIds),
      favoriteSeriesIds: Value(favoriteSeriesIds),
      defaultCategory: Value(defaultCategory),
      channelSortOrder: Value(channelSortOrder),
      defaultSubtitleLang: Value(defaultSubtitleLang),
      defaultAudioLang: Value(defaultAudioLang),
      customChannelOrder: Value(customChannelOrder),
      epgOverrides: Value(epgOverrides),
      hiddenCategories: Value(hiddenCategories),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarEmoji: serializer.fromJson<String>(json['avatarEmoji']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      sourceIds: serializer.fromJson<String>(json['sourceIds']),
      favoriteChannelIds:
          serializer.fromJson<String>(json['favoriteChannelIds']),
      favoriteMovieIds: serializer.fromJson<String>(json['favoriteMovieIds']),
      favoriteSeriesIds: serializer.fromJson<String>(json['favoriteSeriesIds']),
      defaultCategory: serializer.fromJson<String>(json['defaultCategory']),
      channelSortOrder: serializer.fromJson<String>(json['channelSortOrder']),
      defaultSubtitleLang:
          serializer.fromJson<String>(json['defaultSubtitleLang']),
      defaultAudioLang: serializer.fromJson<String>(json['defaultAudioLang']),
      customChannelOrder:
          serializer.fromJson<String>(json['customChannelOrder']),
      epgOverrides: serializer.fromJson<String>(json['epgOverrides']),
      hiddenCategories: serializer.fromJson<String>(json['hiddenCategories']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatarEmoji': serializer.toJson<String>(avatarEmoji),
      'pinHash': serializer.toJson<String?>(pinHash),
      'sourceIds': serializer.toJson<String>(sourceIds),
      'favoriteChannelIds': serializer.toJson<String>(favoriteChannelIds),
      'favoriteMovieIds': serializer.toJson<String>(favoriteMovieIds),
      'favoriteSeriesIds': serializer.toJson<String>(favoriteSeriesIds),
      'defaultCategory': serializer.toJson<String>(defaultCategory),
      'channelSortOrder': serializer.toJson<String>(channelSortOrder),
      'defaultSubtitleLang': serializer.toJson<String>(defaultSubtitleLang),
      'defaultAudioLang': serializer.toJson<String>(defaultAudioLang),
      'customChannelOrder': serializer.toJson<String>(customChannelOrder),
      'epgOverrides': serializer.toJson<String>(epgOverrides),
      'hiddenCategories': serializer.toJson<String>(hiddenCategories),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProfileRow copyWith(
          {String? id,
          String? name,
          String? avatarEmoji,
          Value<String?> pinHash = const Value.absent(),
          String? sourceIds,
          String? favoriteChannelIds,
          String? favoriteMovieIds,
          String? favoriteSeriesIds,
          String? defaultCategory,
          String? channelSortOrder,
          String? defaultSubtitleLang,
          String? defaultAudioLang,
          String? customChannelOrder,
          String? epgOverrides,
          String? hiddenCategories,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ProfileRow(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        pinHash: pinHash.present ? pinHash.value : this.pinHash,
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
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarEmoji:
          data.avatarEmoji.present ? data.avatarEmoji.value : this.avatarEmoji,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      sourceIds: data.sourceIds.present ? data.sourceIds.value : this.sourceIds,
      favoriteChannelIds: data.favoriteChannelIds.present
          ? data.favoriteChannelIds.value
          : this.favoriteChannelIds,
      favoriteMovieIds: data.favoriteMovieIds.present
          ? data.favoriteMovieIds.value
          : this.favoriteMovieIds,
      favoriteSeriesIds: data.favoriteSeriesIds.present
          ? data.favoriteSeriesIds.value
          : this.favoriteSeriesIds,
      defaultCategory: data.defaultCategory.present
          ? data.defaultCategory.value
          : this.defaultCategory,
      channelSortOrder: data.channelSortOrder.present
          ? data.channelSortOrder.value
          : this.channelSortOrder,
      defaultSubtitleLang: data.defaultSubtitleLang.present
          ? data.defaultSubtitleLang.value
          : this.defaultSubtitleLang,
      defaultAudioLang: data.defaultAudioLang.present
          ? data.defaultAudioLang.value
          : this.defaultAudioLang,
      customChannelOrder: data.customChannelOrder.present
          ? data.customChannelOrder.value
          : this.customChannelOrder,
      epgOverrides: data.epgOverrides.present
          ? data.epgOverrides.value
          : this.epgOverrides,
      hiddenCategories: data.hiddenCategories.present
          ? data.hiddenCategories.value
          : this.hiddenCategories,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('pinHash: $pinHash, ')
          ..write('sourceIds: $sourceIds, ')
          ..write('favoriteChannelIds: $favoriteChannelIds, ')
          ..write('favoriteMovieIds: $favoriteMovieIds, ')
          ..write('favoriteSeriesIds: $favoriteSeriesIds, ')
          ..write('defaultCategory: $defaultCategory, ')
          ..write('channelSortOrder: $channelSortOrder, ')
          ..write('defaultSubtitleLang: $defaultSubtitleLang, ')
          ..write('defaultAudioLang: $defaultAudioLang, ')
          ..write('customChannelOrder: $customChannelOrder, ')
          ..write('epgOverrides: $epgOverrides, ')
          ..write('hiddenCategories: $hiddenCategories, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      avatarEmoji,
      pinHash,
      sourceIds,
      favoriteChannelIds,
      favoriteMovieIds,
      favoriteSeriesIds,
      defaultCategory,
      channelSortOrder,
      defaultSubtitleLang,
      defaultAudioLang,
      customChannelOrder,
      epgOverrides,
      hiddenCategories,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarEmoji == this.avatarEmoji &&
          other.pinHash == this.pinHash &&
          other.sourceIds == this.sourceIds &&
          other.favoriteChannelIds == this.favoriteChannelIds &&
          other.favoriteMovieIds == this.favoriteMovieIds &&
          other.favoriteSeriesIds == this.favoriteSeriesIds &&
          other.defaultCategory == this.defaultCategory &&
          other.channelSortOrder == this.channelSortOrder &&
          other.defaultSubtitleLang == this.defaultSubtitleLang &&
          other.defaultAudioLang == this.defaultAudioLang &&
          other.customChannelOrder == this.customChannelOrder &&
          other.epgOverrides == this.epgOverrides &&
          other.hiddenCategories == this.hiddenCategories &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> avatarEmoji;
  final Value<String?> pinHash;
  final Value<String> sourceIds;
  final Value<String> favoriteChannelIds;
  final Value<String> favoriteMovieIds;
  final Value<String> favoriteSeriesIds;
  final Value<String> defaultCategory;
  final Value<String> channelSortOrder;
  final Value<String> defaultSubtitleLang;
  final Value<String> defaultAudioLang;
  final Value<String> customChannelOrder;
  final Value<String> epgOverrides;
  final Value<String> hiddenCategories;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarEmoji = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.sourceIds = const Value.absent(),
    this.favoriteChannelIds = const Value.absent(),
    this.favoriteMovieIds = const Value.absent(),
    this.favoriteSeriesIds = const Value.absent(),
    this.defaultCategory = const Value.absent(),
    this.channelSortOrder = const Value.absent(),
    this.defaultSubtitleLang = const Value.absent(),
    this.defaultAudioLang = const Value.absent(),
    this.customChannelOrder = const Value.absent(),
    this.epgOverrides = const Value.absent(),
    this.hiddenCategories = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    required String avatarEmoji,
    this.pinHash = const Value.absent(),
    this.sourceIds = const Value.absent(),
    this.favoriteChannelIds = const Value.absent(),
    this.favoriteMovieIds = const Value.absent(),
    this.favoriteSeriesIds = const Value.absent(),
    this.defaultCategory = const Value.absent(),
    this.channelSortOrder = const Value.absent(),
    this.defaultSubtitleLang = const Value.absent(),
    this.defaultAudioLang = const Value.absent(),
    this.customChannelOrder = const Value.absent(),
    this.epgOverrides = const Value.absent(),
    this.hiddenCategories = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        avatarEmoji = Value(avatarEmoji),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatarEmoji,
    Expression<String>? pinHash,
    Expression<String>? sourceIds,
    Expression<String>? favoriteChannelIds,
    Expression<String>? favoriteMovieIds,
    Expression<String>? favoriteSeriesIds,
    Expression<String>? defaultCategory,
    Expression<String>? channelSortOrder,
    Expression<String>? defaultSubtitleLang,
    Expression<String>? defaultAudioLang,
    Expression<String>? customChannelOrder,
    Expression<String>? epgOverrides,
    Expression<String>? hiddenCategories,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (pinHash != null) 'pin_hash': pinHash,
      if (sourceIds != null) 'source_ids': sourceIds,
      if (favoriteChannelIds != null)
        'favorite_channel_ids': favoriteChannelIds,
      if (favoriteMovieIds != null) 'favorite_movie_ids': favoriteMovieIds,
      if (favoriteSeriesIds != null) 'favorite_series_ids': favoriteSeriesIds,
      if (defaultCategory != null) 'default_category': defaultCategory,
      if (channelSortOrder != null) 'channel_sort_order': channelSortOrder,
      if (defaultSubtitleLang != null)
        'default_subtitle_lang': defaultSubtitleLang,
      if (defaultAudioLang != null) 'default_audio_lang': defaultAudioLang,
      if (customChannelOrder != null)
        'custom_channel_order': customChannelOrder,
      if (epgOverrides != null) 'epg_overrides': epgOverrides,
      if (hiddenCategories != null) 'hidden_categories': hiddenCategories,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? avatarEmoji,
      Value<String?>? pinHash,
      Value<String>? sourceIds,
      Value<String>? favoriteChannelIds,
      Value<String>? favoriteMovieIds,
      Value<String>? favoriteSeriesIds,
      Value<String>? defaultCategory,
      Value<String>? channelSortOrder,
      Value<String>? defaultSubtitleLang,
      Value<String>? defaultAudioLang,
      Value<String>? customChannelOrder,
      Value<String>? epgOverrides,
      Value<String>? hiddenCategories,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      pinHash: pinHash ?? this.pinHash,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarEmoji.present) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (sourceIds.present) {
      map['source_ids'] = Variable<String>(sourceIds.value);
    }
    if (favoriteChannelIds.present) {
      map['favorite_channel_ids'] = Variable<String>(favoriteChannelIds.value);
    }
    if (favoriteMovieIds.present) {
      map['favorite_movie_ids'] = Variable<String>(favoriteMovieIds.value);
    }
    if (favoriteSeriesIds.present) {
      map['favorite_series_ids'] = Variable<String>(favoriteSeriesIds.value);
    }
    if (defaultCategory.present) {
      map['default_category'] = Variable<String>(defaultCategory.value);
    }
    if (channelSortOrder.present) {
      map['channel_sort_order'] = Variable<String>(channelSortOrder.value);
    }
    if (defaultSubtitleLang.present) {
      map['default_subtitle_lang'] =
          Variable<String>(defaultSubtitleLang.value);
    }
    if (defaultAudioLang.present) {
      map['default_audio_lang'] = Variable<String>(defaultAudioLang.value);
    }
    if (customChannelOrder.present) {
      map['custom_channel_order'] = Variable<String>(customChannelOrder.value);
    }
    if (epgOverrides.present) {
      map['epg_overrides'] = Variable<String>(epgOverrides.value);
    }
    if (hiddenCategories.present) {
      map['hidden_categories'] = Variable<String>(hiddenCategories.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('pinHash: $pinHash, ')
          ..write('sourceIds: $sourceIds, ')
          ..write('favoriteChannelIds: $favoriteChannelIds, ')
          ..write('favoriteMovieIds: $favoriteMovieIds, ')
          ..write('favoriteSeriesIds: $favoriteSeriesIds, ')
          ..write('defaultCategory: $defaultCategory, ')
          ..write('channelSortOrder: $channelSortOrder, ')
          ..write('defaultSubtitleLang: $defaultSubtitleLang, ')
          ..write('defaultAudioLang: $defaultAudioLang, ')
          ..write('customChannelOrder: $customChannelOrder, ')
          ..write('epgOverrides: $epgOverrides, ')
          ..write('hiddenCategories: $hiddenCategories, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $ProgrammesTable programmes = $ProgrammesTable(this);
  late final $MoviesTable movies = $MoviesTable(this);
  late final $SeriesEntriesTable seriesEntries = $SeriesEntriesTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sources,
        channels,
        programmes,
        movies,
        seriesEntries,
        episodes,
        profiles
      ];
}

typedef $$SourcesTableCreateCompanionBuilder = SourcesCompanion Function({
  required String id,
  required String nickname,
  required String type,
  Value<String?> m3uUrl,
  Value<String?> xtreamHost,
  Value<String?> xtreamUsername,
  Value<String?> xtreamPassword,
  Value<String?> epgUrl,
  Value<DateTime?> lastRefreshed,
  Value<int> rowid,
});
typedef $$SourcesTableUpdateCompanionBuilder = SourcesCompanion Function({
  Value<String> id,
  Value<String> nickname,
  Value<String> type,
  Value<String?> m3uUrl,
  Value<String?> xtreamHost,
  Value<String?> xtreamUsername,
  Value<String?> xtreamPassword,
  Value<String?> epgUrl,
  Value<DateTime?> lastRefreshed,
  Value<int> rowid,
});

class $$SourcesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SourcesTable,
    SourceRow,
    $$SourcesTableFilterComposer,
    $$SourcesTableOrderingComposer,
    $$SourcesTableCreateCompanionBuilder,
    $$SourcesTableUpdateCompanionBuilder> {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SourcesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SourcesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> nickname = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> m3uUrl = const Value.absent(),
            Value<String?> xtreamHost = const Value.absent(),
            Value<String?> xtreamUsername = const Value.absent(),
            Value<String?> xtreamPassword = const Value.absent(),
            Value<String?> epgUrl = const Value.absent(),
            Value<DateTime?> lastRefreshed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SourcesCompanion(
            id: id,
            nickname: nickname,
            type: type,
            m3uUrl: m3uUrl,
            xtreamHost: xtreamHost,
            xtreamUsername: xtreamUsername,
            xtreamPassword: xtreamPassword,
            epgUrl: epgUrl,
            lastRefreshed: lastRefreshed,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String nickname,
            required String type,
            Value<String?> m3uUrl = const Value.absent(),
            Value<String?> xtreamHost = const Value.absent(),
            Value<String?> xtreamUsername = const Value.absent(),
            Value<String?> xtreamPassword = const Value.absent(),
            Value<String?> epgUrl = const Value.absent(),
            Value<DateTime?> lastRefreshed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SourcesCompanion.insert(
            id: id,
            nickname: nickname,
            type: type,
            m3uUrl: m3uUrl,
            xtreamHost: xtreamHost,
            xtreamUsername: xtreamUsername,
            xtreamPassword: xtreamPassword,
            epgUrl: epgUrl,
            lastRefreshed: lastRefreshed,
            rowid: rowid,
          ),
        ));
}

class $$SourcesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get nickname => $state.composableBuilder(
      column: $state.table.nickname,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get m3uUrl => $state.composableBuilder(
      column: $state.table.m3uUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get xtreamHost => $state.composableBuilder(
      column: $state.table.xtreamHost,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get xtreamUsername => $state.composableBuilder(
      column: $state.table.xtreamUsername,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get xtreamPassword => $state.composableBuilder(
      column: $state.table.xtreamPassword,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get epgUrl => $state.composableBuilder(
      column: $state.table.epgUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastRefreshed => $state.composableBuilder(
      column: $state.table.lastRefreshed,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter channelsRefs(
      ComposableFilter Function($$ChannelsTableFilterComposer f) f) {
    final $$ChannelsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.channels,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder, parentComposers) =>
            $$ChannelsTableFilterComposer(ComposerState(
                $state.db, $state.db.channels, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter moviesRefs(
      ComposableFilter Function($$MoviesTableFilterComposer f) f) {
    final $$MoviesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.movies,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder, parentComposers) => $$MoviesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.movies, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter seriesEntriesRefs(
      ComposableFilter Function($$SeriesEntriesTableFilterComposer f) f) {
    final $$SeriesEntriesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.seriesEntries,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder, parentComposers) =>
            $$SeriesEntriesTableFilterComposer(ComposerState($state.db,
                $state.db.seriesEntries, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter episodesRefs(
      ComposableFilter Function($$EpisodesTableFilterComposer f) f) {
    final $$EpisodesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.episodes,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder, parentComposers) =>
            $$EpisodesTableFilterComposer(ComposerState(
                $state.db, $state.db.episodes, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$SourcesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get nickname => $state.composableBuilder(
      column: $state.table.nickname,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get m3uUrl => $state.composableBuilder(
      column: $state.table.m3uUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get xtreamHost => $state.composableBuilder(
      column: $state.table.xtreamHost,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get xtreamUsername => $state.composableBuilder(
      column: $state.table.xtreamUsername,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get xtreamPassword => $state.composableBuilder(
      column: $state.table.xtreamPassword,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get epgUrl => $state.composableBuilder(
      column: $state.table.epgUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastRefreshed => $state.composableBuilder(
      column: $state.table.lastRefreshed,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ChannelsTableCreateCompanionBuilder = ChannelsCompanion Function({
  required String id,
  required String sourceId,
  required String name,
  Value<String?> logoUrl,
  required String streamUrl,
  Value<String?> groupTitle,
  Value<String?> tvgId,
  Value<String?> tvgName,
  Value<bool> isFavorite,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$ChannelsTableUpdateCompanionBuilder = ChannelsCompanion Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> name,
  Value<String?> logoUrl,
  Value<String> streamUrl,
  Value<String?> groupTitle,
  Value<String?> tvgId,
  Value<String?> tvgName,
  Value<bool> isFavorite,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$ChannelsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChannelsTable,
    ChannelRow,
    $$ChannelsTableFilterComposer,
    $$ChannelsTableOrderingComposer,
    $$ChannelsTableCreateCompanionBuilder,
    $$ChannelsTableUpdateCompanionBuilder> {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ChannelsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ChannelsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> logoUrl = const Value.absent(),
            Value<String> streamUrl = const Value.absent(),
            Value<String?> groupTitle = const Value.absent(),
            Value<String?> tvgId = const Value.absent(),
            Value<String?> tvgName = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChannelsCompanion(
            id: id,
            sourceId: sourceId,
            name: name,
            logoUrl: logoUrl,
            streamUrl: streamUrl,
            groupTitle: groupTitle,
            tvgId: tvgId,
            tvgName: tvgName,
            isFavorite: isFavorite,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sourceId,
            required String name,
            Value<String?> logoUrl = const Value.absent(),
            required String streamUrl,
            Value<String?> groupTitle = const Value.absent(),
            Value<String?> tvgId = const Value.absent(),
            Value<String?> tvgName = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChannelsCompanion.insert(
            id: id,
            sourceId: sourceId,
            name: name,
            logoUrl: logoUrl,
            streamUrl: streamUrl,
            groupTitle: groupTitle,
            tvgId: tvgId,
            tvgName: tvgName,
            isFavorite: isFavorite,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
        ));
}

class $$ChannelsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get logoUrl => $state.composableBuilder(
      column: $state.table.logoUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get streamUrl => $state.composableBuilder(
      column: $state.table.streamUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get groupTitle => $state.composableBuilder(
      column: $state.table.groupTitle,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get tvgId => $state.composableBuilder(
      column: $state.table.tvgId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get tvgName => $state.composableBuilder(
      column: $state.table.tvgName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isFavorite => $state.composableBuilder(
      column: $state.table.isFavorite,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$SourcesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ChannelsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get logoUrl => $state.composableBuilder(
      column: $state.table.logoUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get streamUrl => $state.composableBuilder(
      column: $state.table.streamUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get groupTitle => $state.composableBuilder(
      column: $state.table.groupTitle,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get tvgId => $state.composableBuilder(
      column: $state.table.tvgId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get tvgName => $state.composableBuilder(
      column: $state.table.tvgName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isFavorite => $state.composableBuilder(
      column: $state.table.isFavorite,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SourcesTableOrderingComposer(ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ProgrammesTableCreateCompanionBuilder = ProgrammesCompanion Function({
  Value<int> id,
  required String channelId,
  required DateTime start,
  required DateTime end,
  required String title,
  Value<String?> description,
  Value<String?> category,
  Value<String?> episodeNum,
});
typedef $$ProgrammesTableUpdateCompanionBuilder = ProgrammesCompanion Function({
  Value<int> id,
  Value<String> channelId,
  Value<DateTime> start,
  Value<DateTime> end,
  Value<String> title,
  Value<String?> description,
  Value<String?> category,
  Value<String?> episodeNum,
});

class $$ProgrammesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProgrammesTable,
    ProgrammeRow,
    $$ProgrammesTableFilterComposer,
    $$ProgrammesTableOrderingComposer,
    $$ProgrammesTableCreateCompanionBuilder,
    $$ProgrammesTableUpdateCompanionBuilder> {
  $$ProgrammesTableTableManager(_$AppDatabase db, $ProgrammesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProgrammesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProgrammesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> channelId = const Value.absent(),
            Value<DateTime> start = const Value.absent(),
            Value<DateTime> end = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> episodeNum = const Value.absent(),
          }) =>
              ProgrammesCompanion(
            id: id,
            channelId: channelId,
            start: start,
            end: end,
            title: title,
            description: description,
            category: category,
            episodeNum: episodeNum,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String channelId,
            required DateTime start,
            required DateTime end,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> episodeNum = const Value.absent(),
          }) =>
              ProgrammesCompanion.insert(
            id: id,
            channelId: channelId,
            start: start,
            end: end,
            title: title,
            description: description,
            category: category,
            episodeNum: episodeNum,
          ),
        ));
}

class $$ProgrammesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get channelId => $state.composableBuilder(
      column: $state.table.channelId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get start => $state.composableBuilder(
      column: $state.table.start,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get end => $state.composableBuilder(
      column: $state.table.end,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get episodeNum => $state.composableBuilder(
      column: $state.table.episodeNum,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ProgrammesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get channelId => $state.composableBuilder(
      column: $state.table.channelId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get start => $state.composableBuilder(
      column: $state.table.start,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get end => $state.composableBuilder(
      column: $state.table.end,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get episodeNum => $state.composableBuilder(
      column: $state.table.episodeNum,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$MoviesTableCreateCompanionBuilder = MoviesCompanion Function({
  required String id,
  required String sourceId,
  required String title,
  Value<String?> posterUrl,
  required String streamUrl,
  Value<String?> genre,
  Value<String?> year,
  Value<String?> rating,
  Value<String?> description,
  Value<int?> watchedDurationSeconds,
  Value<int?> totalDurationSeconds,
  Value<DateTime?> lastWatchedAt,
  Value<int> rowid,
});
typedef $$MoviesTableUpdateCompanionBuilder = MoviesCompanion Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> title,
  Value<String?> posterUrl,
  Value<String> streamUrl,
  Value<String?> genre,
  Value<String?> year,
  Value<String?> rating,
  Value<String?> description,
  Value<int?> watchedDurationSeconds,
  Value<int?> totalDurationSeconds,
  Value<DateTime?> lastWatchedAt,
  Value<int> rowid,
});

class $$MoviesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MoviesTable,
    MovieRow,
    $$MoviesTableFilterComposer,
    $$MoviesTableOrderingComposer,
    $$MoviesTableCreateCompanionBuilder,
    $$MoviesTableUpdateCompanionBuilder> {
  $$MoviesTableTableManager(_$AppDatabase db, $MoviesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$MoviesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$MoviesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterUrl = const Value.absent(),
            Value<String> streamUrl = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> rating = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int?> watchedDurationSeconds = const Value.absent(),
            Value<int?> totalDurationSeconds = const Value.absent(),
            Value<DateTime?> lastWatchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MoviesCompanion(
            id: id,
            sourceId: sourceId,
            title: title,
            posterUrl: posterUrl,
            streamUrl: streamUrl,
            genre: genre,
            year: year,
            rating: rating,
            description: description,
            watchedDurationSeconds: watchedDurationSeconds,
            totalDurationSeconds: totalDurationSeconds,
            lastWatchedAt: lastWatchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sourceId,
            required String title,
            Value<String?> posterUrl = const Value.absent(),
            required String streamUrl,
            Value<String?> genre = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> rating = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int?> watchedDurationSeconds = const Value.absent(),
            Value<int?> totalDurationSeconds = const Value.absent(),
            Value<DateTime?> lastWatchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MoviesCompanion.insert(
            id: id,
            sourceId: sourceId,
            title: title,
            posterUrl: posterUrl,
            streamUrl: streamUrl,
            genre: genre,
            year: year,
            rating: rating,
            description: description,
            watchedDurationSeconds: watchedDurationSeconds,
            totalDurationSeconds: totalDurationSeconds,
            lastWatchedAt: lastWatchedAt,
            rowid: rowid,
          ),
        ));
}

class $$MoviesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get posterUrl => $state.composableBuilder(
      column: $state.table.posterUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get streamUrl => $state.composableBuilder(
      column: $state.table.streamUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get genre => $state.composableBuilder(
      column: $state.table.genre,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get year => $state.composableBuilder(
      column: $state.table.year,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get rating => $state.composableBuilder(
      column: $state.table.rating,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get watchedDurationSeconds => $state.composableBuilder(
      column: $state.table.watchedDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get totalDurationSeconds => $state.composableBuilder(
      column: $state.table.totalDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastWatchedAt => $state.composableBuilder(
      column: $state.table.lastWatchedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$SourcesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$MoviesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get posterUrl => $state.composableBuilder(
      column: $state.table.posterUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get streamUrl => $state.composableBuilder(
      column: $state.table.streamUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get genre => $state.composableBuilder(
      column: $state.table.genre,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get year => $state.composableBuilder(
      column: $state.table.year,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get rating => $state.composableBuilder(
      column: $state.table.rating,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get watchedDurationSeconds => $state.composableBuilder(
      column: $state.table.watchedDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get totalDurationSeconds => $state.composableBuilder(
      column: $state.table.totalDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastWatchedAt => $state.composableBuilder(
      column: $state.table.lastWatchedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SourcesTableOrderingComposer(ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SeriesEntriesTableCreateCompanionBuilder = SeriesEntriesCompanion
    Function({
  required String id,
  required String sourceId,
  required String title,
  Value<String?> posterUrl,
  Value<String?> genre,
  Value<String?> year,
  Value<String?> description,
  Value<int> rowid,
});
typedef $$SeriesEntriesTableUpdateCompanionBuilder = SeriesEntriesCompanion
    Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> title,
  Value<String?> posterUrl,
  Value<String?> genre,
  Value<String?> year,
  Value<String?> description,
  Value<int> rowid,
});

class $$SeriesEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SeriesEntriesTable,
    SeriesRow,
    $$SeriesEntriesTableFilterComposer,
    $$SeriesEntriesTableOrderingComposer,
    $$SeriesEntriesTableCreateCompanionBuilder,
    $$SeriesEntriesTableUpdateCompanionBuilder> {
  $$SeriesEntriesTableTableManager(_$AppDatabase db, $SeriesEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SeriesEntriesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SeriesEntriesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterUrl = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SeriesEntriesCompanion(
            id: id,
            sourceId: sourceId,
            title: title,
            posterUrl: posterUrl,
            genre: genre,
            year: year,
            description: description,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sourceId,
            required String title,
            Value<String?> posterUrl = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SeriesEntriesCompanion.insert(
            id: id,
            sourceId: sourceId,
            title: title,
            posterUrl: posterUrl,
            genre: genre,
            year: year,
            description: description,
            rowid: rowid,
          ),
        ));
}

class $$SeriesEntriesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SeriesEntriesTable> {
  $$SeriesEntriesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get posterUrl => $state.composableBuilder(
      column: $state.table.posterUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get genre => $state.composableBuilder(
      column: $state.table.genre,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get year => $state.composableBuilder(
      column: $state.table.year,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$SourcesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$SeriesEntriesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SeriesEntriesTable> {
  $$SeriesEntriesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get posterUrl => $state.composableBuilder(
      column: $state.table.posterUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get genre => $state.composableBuilder(
      column: $state.table.genre,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get year => $state.composableBuilder(
      column: $state.table.year,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SourcesTableOrderingComposer(ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  required String id,
  required String seriesId,
  required String sourceId,
  required int season,
  required int episode,
  required String title,
  required String streamUrl,
  Value<String?> stillUrl,
  Value<int?> watchedDurationSeconds,
  Value<int?> totalDurationSeconds,
  Value<DateTime?> lastWatchedAt,
  Value<int> rowid,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<String> id,
  Value<String> seriesId,
  Value<String> sourceId,
  Value<int> season,
  Value<int> episode,
  Value<String> title,
  Value<String> streamUrl,
  Value<String?> stillUrl,
  Value<int?> watchedDurationSeconds,
  Value<int?> totalDurationSeconds,
  Value<DateTime?> lastWatchedAt,
  Value<int> rowid,
});

class $$EpisodesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EpisodesTable,
    EpisodeRow,
    $$EpisodesTableFilterComposer,
    $$EpisodesTableOrderingComposer,
    $$EpisodesTableCreateCompanionBuilder,
    $$EpisodesTableUpdateCompanionBuilder> {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$EpisodesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$EpisodesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> seriesId = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<int> season = const Value.absent(),
            Value<int> episode = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> streamUrl = const Value.absent(),
            Value<String?> stillUrl = const Value.absent(),
            Value<int?> watchedDurationSeconds = const Value.absent(),
            Value<int?> totalDurationSeconds = const Value.absent(),
            Value<DateTime?> lastWatchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodesCompanion(
            id: id,
            seriesId: seriesId,
            sourceId: sourceId,
            season: season,
            episode: episode,
            title: title,
            streamUrl: streamUrl,
            stillUrl: stillUrl,
            watchedDurationSeconds: watchedDurationSeconds,
            totalDurationSeconds: totalDurationSeconds,
            lastWatchedAt: lastWatchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String seriesId,
            required String sourceId,
            required int season,
            required int episode,
            required String title,
            required String streamUrl,
            Value<String?> stillUrl = const Value.absent(),
            Value<int?> watchedDurationSeconds = const Value.absent(),
            Value<int?> totalDurationSeconds = const Value.absent(),
            Value<DateTime?> lastWatchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodesCompanion.insert(
            id: id,
            seriesId: seriesId,
            sourceId: sourceId,
            season: season,
            episode: episode,
            title: title,
            streamUrl: streamUrl,
            stillUrl: stillUrl,
            watchedDurationSeconds: watchedDurationSeconds,
            totalDurationSeconds: totalDurationSeconds,
            lastWatchedAt: lastWatchedAt,
            rowid: rowid,
          ),
        ));
}

class $$EpisodesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get seriesId => $state.composableBuilder(
      column: $state.table.seriesId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get season => $state.composableBuilder(
      column: $state.table.season,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get episode => $state.composableBuilder(
      column: $state.table.episode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get streamUrl => $state.composableBuilder(
      column: $state.table.streamUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get stillUrl => $state.composableBuilder(
      column: $state.table.stillUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get watchedDurationSeconds => $state.composableBuilder(
      column: $state.table.watchedDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get totalDurationSeconds => $state.composableBuilder(
      column: $state.table.totalDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastWatchedAt => $state.composableBuilder(
      column: $state.table.lastWatchedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$SourcesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get seriesId => $state.composableBuilder(
      column: $state.table.seriesId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get season => $state.composableBuilder(
      column: $state.table.season,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get episode => $state.composableBuilder(
      column: $state.table.episode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get streamUrl => $state.composableBuilder(
      column: $state.table.streamUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get stillUrl => $state.composableBuilder(
      column: $state.table.stillUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get watchedDurationSeconds => $state.composableBuilder(
      column: $state.table.watchedDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get totalDurationSeconds => $state.composableBuilder(
      column: $state.table.totalDurationSeconds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastWatchedAt => $state.composableBuilder(
      column: $state.table.lastWatchedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $state.db.sources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SourcesTableOrderingComposer(ComposerState(
                $state.db, $state.db.sources, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String name,
  required String avatarEmoji,
  Value<String?> pinHash,
  Value<String> sourceIds,
  Value<String> favoriteChannelIds,
  Value<String> favoriteMovieIds,
  Value<String> favoriteSeriesIds,
  Value<String> defaultCategory,
  Value<String> channelSortOrder,
  Value<String> defaultSubtitleLang,
  Value<String> defaultAudioLang,
  Value<String> customChannelOrder,
  Value<String> epgOverrides,
  Value<String> hiddenCategories,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> avatarEmoji,
  Value<String?> pinHash,
  Value<String> sourceIds,
  Value<String> favoriteChannelIds,
  Value<String> favoriteMovieIds,
  Value<String> favoriteSeriesIds,
  Value<String> defaultCategory,
  Value<String> channelSortOrder,
  Value<String> defaultSubtitleLang,
  Value<String> defaultAudioLang,
  Value<String> customChannelOrder,
  Value<String> epgOverrides,
  Value<String> hiddenCategories,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileRow,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ProfilesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ProfilesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> avatarEmoji = const Value.absent(),
            Value<String?> pinHash = const Value.absent(),
            Value<String> sourceIds = const Value.absent(),
            Value<String> favoriteChannelIds = const Value.absent(),
            Value<String> favoriteMovieIds = const Value.absent(),
            Value<String> favoriteSeriesIds = const Value.absent(),
            Value<String> defaultCategory = const Value.absent(),
            Value<String> channelSortOrder = const Value.absent(),
            Value<String> defaultSubtitleLang = const Value.absent(),
            Value<String> defaultAudioLang = const Value.absent(),
            Value<String> customChannelOrder = const Value.absent(),
            Value<String> epgOverrides = const Value.absent(),
            Value<String> hiddenCategories = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            name: name,
            avatarEmoji: avatarEmoji,
            pinHash: pinHash,
            sourceIds: sourceIds,
            favoriteChannelIds: favoriteChannelIds,
            favoriteMovieIds: favoriteMovieIds,
            favoriteSeriesIds: favoriteSeriesIds,
            defaultCategory: defaultCategory,
            channelSortOrder: channelSortOrder,
            defaultSubtitleLang: defaultSubtitleLang,
            defaultAudioLang: defaultAudioLang,
            customChannelOrder: customChannelOrder,
            epgOverrides: epgOverrides,
            hiddenCategories: hiddenCategories,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String avatarEmoji,
            Value<String?> pinHash = const Value.absent(),
            Value<String> sourceIds = const Value.absent(),
            Value<String> favoriteChannelIds = const Value.absent(),
            Value<String> favoriteMovieIds = const Value.absent(),
            Value<String> favoriteSeriesIds = const Value.absent(),
            Value<String> defaultCategory = const Value.absent(),
            Value<String> channelSortOrder = const Value.absent(),
            Value<String> defaultSubtitleLang = const Value.absent(),
            Value<String> defaultAudioLang = const Value.absent(),
            Value<String> customChannelOrder = const Value.absent(),
            Value<String> epgOverrides = const Value.absent(),
            Value<String> hiddenCategories = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            name: name,
            avatarEmoji: avatarEmoji,
            pinHash: pinHash,
            sourceIds: sourceIds,
            favoriteChannelIds: favoriteChannelIds,
            favoriteMovieIds: favoriteMovieIds,
            favoriteSeriesIds: favoriteSeriesIds,
            defaultCategory: defaultCategory,
            channelSortOrder: channelSortOrder,
            defaultSubtitleLang: defaultSubtitleLang,
            defaultAudioLang: defaultAudioLang,
            customChannelOrder: customChannelOrder,
            epgOverrides: epgOverrides,
            hiddenCategories: hiddenCategories,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$ProfilesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get avatarEmoji => $state.composableBuilder(
      column: $state.table.avatarEmoji,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get pinHash => $state.composableBuilder(
      column: $state.table.pinHash,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get sourceIds => $state.composableBuilder(
      column: $state.table.sourceIds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get favoriteChannelIds => $state.composableBuilder(
      column: $state.table.favoriteChannelIds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get favoriteMovieIds => $state.composableBuilder(
      column: $state.table.favoriteMovieIds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get favoriteSeriesIds => $state.composableBuilder(
      column: $state.table.favoriteSeriesIds,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get defaultCategory => $state.composableBuilder(
      column: $state.table.defaultCategory,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get channelSortOrder => $state.composableBuilder(
      column: $state.table.channelSortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get defaultSubtitleLang => $state.composableBuilder(
      column: $state.table.defaultSubtitleLang,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get defaultAudioLang => $state.composableBuilder(
      column: $state.table.defaultAudioLang,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get customChannelOrder => $state.composableBuilder(
      column: $state.table.customChannelOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get epgOverrides => $state.composableBuilder(
      column: $state.table.epgOverrides,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get hiddenCategories => $state.composableBuilder(
      column: $state.table.hiddenCategories,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ProfilesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get avatarEmoji => $state.composableBuilder(
      column: $state.table.avatarEmoji,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get pinHash => $state.composableBuilder(
      column: $state.table.pinHash,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get sourceIds => $state.composableBuilder(
      column: $state.table.sourceIds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get favoriteChannelIds => $state.composableBuilder(
      column: $state.table.favoriteChannelIds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get favoriteMovieIds => $state.composableBuilder(
      column: $state.table.favoriteMovieIds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get favoriteSeriesIds => $state.composableBuilder(
      column: $state.table.favoriteSeriesIds,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get defaultCategory => $state.composableBuilder(
      column: $state.table.defaultCategory,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get channelSortOrder => $state.composableBuilder(
      column: $state.table.channelSortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get defaultSubtitleLang => $state.composableBuilder(
      column: $state.table.defaultSubtitleLang,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get defaultAudioLang => $state.composableBuilder(
      column: $state.table.defaultAudioLang,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get customChannelOrder => $state.composableBuilder(
      column: $state.table.customChannelOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get epgOverrides => $state.composableBuilder(
      column: $state.table.epgOverrides,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get hiddenCategories => $state.composableBuilder(
      column: $state.table.hiddenCategories,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$ProgrammesTableTableManager get programmes =>
      $$ProgrammesTableTableManager(_db, _db.programmes);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db, _db.movies);
  $$SeriesEntriesTableTableManager get seriesEntries =>
      $$SeriesEntriesTableTableManager(_db, _db.seriesEntries);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
}
