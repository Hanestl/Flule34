// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserAccountsTable extends UserAccounts
    with TableInfo<$UserAccountsTable, UserAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastAuthenticatedAtMeta =
      const VerificationMeta('lastAuthenticatedAt');
  @override
  late final GeneratedColumn<DateTime> lastAuthenticatedAt =
      GeneratedColumn<DateTime>(
        'last_authenticated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    displayName,
    avatarUrl,
    createdAt,
    lastAuthenticatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_authenticated_at')) {
      context.handle(
        _lastAuthenticatedAtMeta,
        lastAuthenticatedAt.isAcceptableOrUnknown(
          data['last_authenticated_at']!,
          _lastAuthenticatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserAccount(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAuthenticatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_authenticated_at'],
      )!,
    );
  }

  @override
  $UserAccountsTable createAlias(String alias) {
    return $UserAccountsTable(attachedDatabase, alias);
  }
}

class UserAccount extends DataClass implements Insertable<UserAccount> {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastAuthenticatedAt;
  const UserAccount({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.lastAuthenticatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_authenticated_at'] = Variable<DateTime>(lastAuthenticatedAt);
    return map;
  }

  UserAccountsCompanion toCompanion(bool nullToAbsent) {
    return UserAccountsCompanion(
      userId: Value(userId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      createdAt: Value(createdAt),
      lastAuthenticatedAt: Value(lastAuthenticatedAt),
    );
  }

  factory UserAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserAccount(
      userId: serializer.fromJson<String>(json['userId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAuthenticatedAt: serializer.fromJson<DateTime>(
        json['lastAuthenticatedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'displayName': serializer.toJson<String?>(displayName),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAuthenticatedAt': serializer.toJson<DateTime>(lastAuthenticatedAt),
    };
  }

  UserAccount copyWith({
    String? userId,
    Value<String?> displayName = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    DateTime? createdAt,
    DateTime? lastAuthenticatedAt,
  }) => UserAccount(
    userId: userId ?? this.userId,
    displayName: displayName.present ? displayName.value : this.displayName,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    createdAt: createdAt ?? this.createdAt,
    lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
  );
  UserAccount copyWithCompanion(UserAccountsCompanion data) {
    return UserAccount(
      userId: data.userId.present ? data.userId.value : this.userId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAuthenticatedAt: data.lastAuthenticatedAt.present
          ? data.lastAuthenticatedAt.value
          : this.lastAuthenticatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserAccount(')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAuthenticatedAt: $lastAuthenticatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    displayName,
    avatarUrl,
    createdAt,
    lastAuthenticatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserAccount &&
          other.userId == this.userId &&
          other.displayName == this.displayName &&
          other.avatarUrl == this.avatarUrl &&
          other.createdAt == this.createdAt &&
          other.lastAuthenticatedAt == this.lastAuthenticatedAt);
}

class UserAccountsCompanion extends UpdateCompanion<UserAccount> {
  final Value<String> userId;
  final Value<String?> displayName;
  final Value<String?> avatarUrl;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastAuthenticatedAt;
  final Value<int> rowid;
  const UserAccountsCompanion({
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAuthenticatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserAccountsCompanion.insert({
    required String userId,
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAuthenticatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<UserAccount> custom({
    Expression<String>? userId,
    Expression<String>? displayName,
    Expression<String>? avatarUrl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAuthenticatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAuthenticatedAt != null)
        'last_authenticated_at': lastAuthenticatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserAccountsCompanion copyWith({
    Value<String>? userId,
    Value<String?>? displayName,
    Value<String?>? avatarUrl,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastAuthenticatedAt,
    Value<int>? rowid,
  }) {
    return UserAccountsCompanion(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAuthenticatedAt.present) {
      map['last_authenticated_at'] = Variable<DateTime>(
        lastAuthenticatedAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserAccountsCompanion(')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAuthenticatedAt: $lastAuthenticatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackPositionsTable extends PlaybackPositions
    with TableInfo<$PlaybackPositionsTable, PlaybackPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_accounts (user_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationLabelMeta = const VerificationMeta(
    'durationLabel',
  );
  @override
  late final GeneratedColumn<String> durationLabel = GeneratedColumn<String>(
    'duration_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    videoId,
    title,
    slug,
    thumbnailUrl,
    durationLabel,
    positionMs,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackPosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('duration_label')) {
      context.handle(
        _durationLabelMeta,
        durationLabel.isAcceptableOrUnknown(
          data['duration_label']!,
          _durationLabelMeta,
        ),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, videoId};
  @override
  PlaybackPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackPosition(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      durationLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration_label'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackPositionsTable createAlias(String alias) {
    return $PlaybackPositionsTable(attachedDatabase, alias);
  }
}

class PlaybackPosition extends DataClass
    implements Insertable<PlaybackPosition> {
  final String userId;
  final String videoId;
  final String? title;
  final String? slug;
  final String? thumbnailUrl;
  final String? durationLabel;
  final int positionMs;
  final int? durationMs;
  final DateTime updatedAt;
  const PlaybackPosition({
    required this.userId,
    required this.videoId,
    this.title,
    this.slug,
    this.thumbnailUrl,
    this.durationLabel,
    required this.positionMs,
    this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['video_id'] = Variable<String>(videoId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || slug != null) {
      map['slug'] = Variable<String>(slug);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || durationLabel != null) {
      map['duration_label'] = Variable<String>(durationLabel);
    }
    map['position_ms'] = Variable<int>(positionMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackPositionsCompanion toCompanion(bool nullToAbsent) {
    return PlaybackPositionsCompanion(
      userId: Value(userId),
      videoId: Value(videoId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      slug: slug == null && nullToAbsent ? const Value.absent() : Value(slug),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationLabel: durationLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(durationLabel),
      positionMs: Value(positionMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackPosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackPosition(
      userId: serializer.fromJson<String>(json['userId']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String?>(json['title']),
      slug: serializer.fromJson<String?>(json['slug']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationLabel: serializer.fromJson<String?>(json['durationLabel']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String?>(title),
      'slug': serializer.toJson<String?>(slug),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationLabel': serializer.toJson<String?>(durationLabel),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackPosition copyWith({
    String? userId,
    String? videoId,
    Value<String?> title = const Value.absent(),
    Value<String?> slug = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> durationLabel = const Value.absent(),
    int? positionMs,
    Value<int?> durationMs = const Value.absent(),
    DateTime? updatedAt,
  }) => PlaybackPosition(
    userId: userId ?? this.userId,
    videoId: videoId ?? this.videoId,
    title: title.present ? title.value : this.title,
    slug: slug.present ? slug.value : this.slug,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    durationLabel: durationLabel.present
        ? durationLabel.value
        : this.durationLabel,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackPosition copyWithCompanion(PlaybackPositionsCompanion data) {
    return PlaybackPosition(
      userId: data.userId.present ? data.userId.value : this.userId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      slug: data.slug.present ? data.slug.value : this.slug,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationLabel: data.durationLabel.present
          ? data.durationLabel.value
          : this.durationLabel,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPosition(')
          ..write('userId: $userId, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationLabel: $durationLabel, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    videoId,
    title,
    slug,
    thumbnailUrl,
    durationLabel,
    positionMs,
    durationMs,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackPosition &&
          other.userId == this.userId &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.slug == this.slug &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationLabel == this.durationLabel &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class PlaybackPositionsCompanion extends UpdateCompanion<PlaybackPosition> {
  final Value<String> userId;
  final Value<String> videoId;
  final Value<String?> title;
  final Value<String?> slug;
  final Value<String?> thumbnailUrl;
  final Value<String?> durationLabel;
  final Value<int> positionMs;
  final Value<int?> durationMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackPositionsCompanion({
    this.userId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.slug = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationLabel = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackPositionsCompanion.insert({
    required String userId,
    required String videoId,
    this.title = const Value.absent(),
    this.slug = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationLabel = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       videoId = Value(videoId);
  static Insertable<PlaybackPosition> custom({
    Expression<String>? userId,
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? slug,
    Expression<String>? thumbnailUrl,
    Expression<String>? durationLabel,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (slug != null) 'slug': slug,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationLabel != null) 'duration_label': durationLabel,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackPositionsCompanion copyWith({
    Value<String>? userId,
    Value<String>? videoId,
    Value<String?>? title,
    Value<String?>? slug,
    Value<String?>? thumbnailUrl,
    Value<String?>? durationLabel,
    Value<int>? positionMs,
    Value<int?>? durationMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaybackPositionsCompanion(
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationLabel: durationLabel ?? this.durationLabel,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationLabel.present) {
      map['duration_label'] = Variable<String>(durationLabel.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
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
    return (StringBuffer('PlaybackPositionsCompanion(')
          ..write('userId: $userId, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationLabel: $durationLabel, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadRecordsTable extends DownloadRecords
    with TableInfo<$DownloadRecordsTable, DownloadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_accounts (user_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesDownloadedMeta = const VerificationMeta(
    'bytesDownloaded',
  );
  @override
  late final GeneratedColumn<int> bytesDownloaded = GeneratedColumn<int>(
    'bytes_downloaded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    videoId,
    title,
    quality,
    thumbnailUrl,
    fileName,
    state,
    taskId,
    filePath,
    bytesDownloaded,
    totalBytes,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('bytes_downloaded')) {
      context.handle(
        _bytesDownloadedMeta,
        bytesDownloaded.isAcceptableOrUnknown(
          data['bytes_downloaded']!,
          _bytesDownloadedMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {userId, videoId, quality},
  ];
  @override
  DownloadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      bytesDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_downloaded'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadRecordsTable createAlias(String alias) {
    return $DownloadRecordsTable(attachedDatabase, alias);
  }
}

class DownloadRecord extends DataClass implements Insertable<DownloadRecord> {
  final String id;
  final String userId;
  final String videoId;
  final String title;
  final String quality;
  final String? thumbnailUrl;
  final String? fileName;
  final String state;
  final String? taskId;
  final String? filePath;
  final int bytesDownloaded;
  final int? totalBytes;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const DownloadRecord({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.title,
    required this.quality,
    this.thumbnailUrl,
    this.fileName,
    required this.state,
    this.taskId,
    this.filePath,
    required this.bytesDownloaded,
    this.totalBytes,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['quality'] = Variable<String>(quality);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['bytes_downloaded'] = Variable<int>(bytesDownloaded);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadRecordsCompanion toCompanion(bool nullToAbsent) {
    return DownloadRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      videoId: Value(videoId),
      title: Value(title),
      quality: Value(quality),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      state: Value(state),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      bytesDownloaded: Value(bytesDownloaded),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      quality: serializer.fromJson<String>(json['quality']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      state: serializer.fromJson<String>(json['state']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      bytesDownloaded: serializer.fromJson<int>(json['bytesDownloaded']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'quality': serializer.toJson<String>(quality),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'fileName': serializer.toJson<String?>(fileName),
      'state': serializer.toJson<String>(state),
      'taskId': serializer.toJson<String?>(taskId),
      'filePath': serializer.toJson<String?>(filePath),
      'bytesDownloaded': serializer.toJson<int>(bytesDownloaded),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadRecord copyWith({
    String? id,
    String? userId,
    String? videoId,
    String? title,
    String? quality,
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> fileName = const Value.absent(),
    String? state,
    Value<String?> taskId = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    int? bytesDownloaded,
    Value<int?> totalBytes = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    videoId: videoId ?? this.videoId,
    title: title ?? this.title,
    quality: quality ?? this.quality,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    fileName: fileName.present ? fileName.value : this.fileName,
    state: state ?? this.state,
    taskId: taskId.present ? taskId.value : this.taskId,
    filePath: filePath.present ? filePath.value : this.filePath,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadRecord copyWithCompanion(DownloadRecordsCompanion data) {
    return DownloadRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      quality: data.quality.present ? data.quality.value : this.quality,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      state: data.state.present ? data.state.value : this.state,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      bytesDownloaded: data.bytesDownloaded.present
          ? data.bytesDownloaded.value
          : this.bytesDownloaded,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('quality: $quality, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('fileName: $fileName, ')
          ..write('state: $state, ')
          ..write('taskId: $taskId, ')
          ..write('filePath: $filePath, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    videoId,
    title,
    quality,
    thumbnailUrl,
    fileName,
    state,
    taskId,
    filePath,
    bytesDownloaded,
    totalBytes,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.quality == this.quality &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.fileName == this.fileName &&
          other.state == this.state &&
          other.taskId == this.taskId &&
          other.filePath == this.filePath &&
          other.bytesDownloaded == this.bytesDownloaded &&
          other.totalBytes == this.totalBytes &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadRecordsCompanion extends UpdateCompanion<DownloadRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> quality;
  final Value<String?> thumbnailUrl;
  final Value<String?> fileName;
  final Value<String> state;
  final Value<String?> taskId;
  final Value<String?> filePath;
  final Value<int> bytesDownloaded;
  final Value<int?> totalBytes;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.quality = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    this.state = const Value.absent(),
    this.taskId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadRecordsCompanion.insert({
    required String id,
    required String userId,
    required String videoId,
    required String title,
    required String quality,
    this.thumbnailUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    required String state,
    this.taskId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       videoId = Value(videoId),
       title = Value(title),
       quality = Value(quality),
       state = Value(state);
  static Insertable<DownloadRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? quality,
    Expression<String>? thumbnailUrl,
    Expression<String>? fileName,
    Expression<String>? state,
    Expression<String>? taskId,
    Expression<String>? filePath,
    Expression<int>? bytesDownloaded,
    Expression<int>? totalBytes,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (quality != null) 'quality': quality,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (fileName != null) 'file_name': fileName,
      if (state != null) 'state': state,
      if (taskId != null) 'task_id': taskId,
      if (filePath != null) 'file_path': filePath,
      if (bytesDownloaded != null) 'bytes_downloaded': bytesDownloaded,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? videoId,
    Value<String>? title,
    Value<String>? quality,
    Value<String?>? thumbnailUrl,
    Value<String?>? fileName,
    Value<String>? state,
    Value<String?>? taskId,
    Value<String?>? filePath,
    Value<int>? bytesDownloaded,
    Value<int?>? totalBytes,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      quality: quality ?? this.quality,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      state: state ?? this.state,
      taskId: taskId ?? this.taskId,
      filePath: filePath ?? this.filePath,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (bytesDownloaded.present) {
      map['bytes_downloaded'] = Variable<int>(bytesDownloaded.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('quality: $quality, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('fileName: $fileName, ')
          ..write('state: $state, ')
          ..write('taskId: $taskId, ')
          ..write('filePath: $filePath, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoriesTable extends SearchHistories
    with TableInfo<$SearchHistoriesTable, SearchHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_accounts (user_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _normalizedQueryMeta = const VerificationMeta(
    'normalizedQuery',
  );
  @override
  late final GeneratedColumn<String> normalizedQuery = GeneratedColumn<String>(
    'normalized_query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayQueryMeta = const VerificationMeta(
    'displayQuery',
  );
  @override
  late final GeneratedColumn<String> displayQuery = GeneratedColumn<String>(
    'display_query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSearchedAtMeta = const VerificationMeta(
    'lastSearchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSearchedAt =
      GeneratedColumn<DateTime>(
        'last_searched_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    normalizedQuery,
    displayQuery,
    lastSearchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('normalized_query')) {
      context.handle(
        _normalizedQueryMeta,
        normalizedQuery.isAcceptableOrUnknown(
          data['normalized_query']!,
          _normalizedQueryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedQueryMeta);
    }
    if (data.containsKey('display_query')) {
      context.handle(
        _displayQueryMeta,
        displayQuery.isAcceptableOrUnknown(
          data['display_query']!,
          _displayQueryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayQueryMeta);
    }
    if (data.containsKey('last_searched_at')) {
      context.handle(
        _lastSearchedAtMeta,
        lastSearchedAt.isAcceptableOrUnknown(
          data['last_searched_at']!,
          _lastSearchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, normalizedQuery};
  @override
  SearchHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistory(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      normalizedQuery: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_query'],
      )!,
      displayQuery: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_query'],
      )!,
      lastSearchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoriesTable createAlias(String alias) {
    return $SearchHistoriesTable(attachedDatabase, alias);
  }
}

class SearchHistory extends DataClass implements Insertable<SearchHistory> {
  final String userId;
  final String normalizedQuery;
  final String displayQuery;
  final DateTime lastSearchedAt;
  const SearchHistory({
    required this.userId,
    required this.normalizedQuery,
    required this.displayQuery,
    required this.lastSearchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['normalized_query'] = Variable<String>(normalizedQuery);
    map['display_query'] = Variable<String>(displayQuery);
    map['last_searched_at'] = Variable<DateTime>(lastSearchedAt);
    return map;
  }

  SearchHistoriesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoriesCompanion(
      userId: Value(userId),
      normalizedQuery: Value(normalizedQuery),
      displayQuery: Value(displayQuery),
      lastSearchedAt: Value(lastSearchedAt),
    );
  }

  factory SearchHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistory(
      userId: serializer.fromJson<String>(json['userId']),
      normalizedQuery: serializer.fromJson<String>(json['normalizedQuery']),
      displayQuery: serializer.fromJson<String>(json['displayQuery']),
      lastSearchedAt: serializer.fromJson<DateTime>(json['lastSearchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'normalizedQuery': serializer.toJson<String>(normalizedQuery),
      'displayQuery': serializer.toJson<String>(displayQuery),
      'lastSearchedAt': serializer.toJson<DateTime>(lastSearchedAt),
    };
  }

  SearchHistory copyWith({
    String? userId,
    String? normalizedQuery,
    String? displayQuery,
    DateTime? lastSearchedAt,
  }) => SearchHistory(
    userId: userId ?? this.userId,
    normalizedQuery: normalizedQuery ?? this.normalizedQuery,
    displayQuery: displayQuery ?? this.displayQuery,
    lastSearchedAt: lastSearchedAt ?? this.lastSearchedAt,
  );
  SearchHistory copyWithCompanion(SearchHistoriesCompanion data) {
    return SearchHistory(
      userId: data.userId.present ? data.userId.value : this.userId,
      normalizedQuery: data.normalizedQuery.present
          ? data.normalizedQuery.value
          : this.normalizedQuery,
      displayQuery: data.displayQuery.present
          ? data.displayQuery.value
          : this.displayQuery,
      lastSearchedAt: data.lastSearchedAt.present
          ? data.lastSearchedAt.value
          : this.lastSearchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistory(')
          ..write('userId: $userId, ')
          ..write('normalizedQuery: $normalizedQuery, ')
          ..write('displayQuery: $displayQuery, ')
          ..write('lastSearchedAt: $lastSearchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, normalizedQuery, displayQuery, lastSearchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistory &&
          other.userId == this.userId &&
          other.normalizedQuery == this.normalizedQuery &&
          other.displayQuery == this.displayQuery &&
          other.lastSearchedAt == this.lastSearchedAt);
}

class SearchHistoriesCompanion extends UpdateCompanion<SearchHistory> {
  final Value<String> userId;
  final Value<String> normalizedQuery;
  final Value<String> displayQuery;
  final Value<DateTime> lastSearchedAt;
  final Value<int> rowid;
  const SearchHistoriesCompanion({
    this.userId = const Value.absent(),
    this.normalizedQuery = const Value.absent(),
    this.displayQuery = const Value.absent(),
    this.lastSearchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoriesCompanion.insert({
    required String userId,
    required String normalizedQuery,
    required String displayQuery,
    this.lastSearchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       normalizedQuery = Value(normalizedQuery),
       displayQuery = Value(displayQuery);
  static Insertable<SearchHistory> custom({
    Expression<String>? userId,
    Expression<String>? normalizedQuery,
    Expression<String>? displayQuery,
    Expression<DateTime>? lastSearchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (normalizedQuery != null) 'normalized_query': normalizedQuery,
      if (displayQuery != null) 'display_query': displayQuery,
      if (lastSearchedAt != null) 'last_searched_at': lastSearchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoriesCompanion copyWith({
    Value<String>? userId,
    Value<String>? normalizedQuery,
    Value<String>? displayQuery,
    Value<DateTime>? lastSearchedAt,
    Value<int>? rowid,
  }) {
    return SearchHistoriesCompanion(
      userId: userId ?? this.userId,
      normalizedQuery: normalizedQuery ?? this.normalizedQuery,
      displayQuery: displayQuery ?? this.displayQuery,
      lastSearchedAt: lastSearchedAt ?? this.lastSearchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (normalizedQuery.present) {
      map['normalized_query'] = Variable<String>(normalizedQuery.value);
    }
    if (displayQuery.present) {
      map['display_query'] = Variable<String>(displayQuery.value);
    }
    if (lastSearchedAt.present) {
      map['last_searched_at'] = Variable<DateTime>(lastSearchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoriesCompanion(')
          ..write('userId: $userId, ')
          ..write('normalizedQuery: $normalizedQuery, ')
          ..write('displayQuery: $displayQuery, ')
          ..write('lastSearchedAt: $lastSearchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLibrariesTable extends LocalLibraries
    with TableInfo<$LocalLibrariesTable, LocalLibrary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLibrariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    seedKey,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_libraries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalLibrary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {normalizedName},
  ];
  @override
  LocalLibrary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLibrary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalLibrariesTable createAlias(String alias) {
    return $LocalLibrariesTable(attachedDatabase, alias);
  }
}

class LocalLibrary extends DataClass implements Insertable<LocalLibrary> {
  final int id;
  final String name;
  final String normalizedName;
  final String? seedKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalLibrary({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.seedKey,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || seedKey != null) {
      map['seed_key'] = Variable<String>(seedKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalLibrariesCompanion toCompanion(bool nullToAbsent) {
    return LocalLibrariesCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      seedKey: seedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seedKey),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalLibrary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLibrary(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      seedKey: serializer.fromJson<String?>(json['seedKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'seedKey': serializer.toJson<String?>(seedKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalLibrary copyWith({
    int? id,
    String? name,
    String? normalizedName,
    Value<String?> seedKey = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalLibrary(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    seedKey: seedKey.present ? seedKey.value : this.seedKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalLibrary copyWithCompanion(LocalLibrariesCompanion data) {
    return LocalLibrary(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLibrary(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('seedKey: $seedKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, normalizedName, seedKey, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLibrary &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.seedKey == this.seedKey &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalLibrariesCompanion extends UpdateCompanion<LocalLibrary> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> seedKey;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LocalLibrariesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.seedKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalLibrariesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String normalizedName,
    this.seedKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       normalizedName = Value(normalizedName);
  static Insertable<LocalLibrary> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? seedKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (seedKey != null) 'seed_key': seedKey,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalLibrariesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String?>? seedKey,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LocalLibrariesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      seedKey: seedKey ?? this.seedKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLibrariesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('seedKey: $seedKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CuratedLibrarySeedsTable extends CuratedLibrarySeeds
    with TableInfo<$CuratedLibrarySeedsTable, CuratedLibrarySeed> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CuratedLibrarySeedsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packVersionMeta = const VerificationMeta(
    'packVersion',
  );
  @override
  late final GeneratedColumn<int> packVersion = GeneratedColumn<int>(
    'pack_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta(
    'dismissed',
  );
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<DateTime> appliedAt = GeneratedColumn<DateTime>(
    'applied_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seedKey,
    packVersion,
    dismissed,
    appliedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'curated_library_seeds';
  @override
  VerificationContext validateIntegrity(
    Insertable<CuratedLibrarySeed> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seedKeyMeta);
    }
    if (data.containsKey('pack_version')) {
      context.handle(
        _packVersionMeta,
        packVersion.isAcceptableOrUnknown(
          data['pack_version']!,
          _packVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packVersionMeta);
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
      );
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seedKey};
  @override
  CuratedLibrarySeed map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CuratedLibrarySeed(
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      )!,
      packVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pack_version'],
      )!,
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}applied_at'],
      )!,
    );
  }

  @override
  $CuratedLibrarySeedsTable createAlias(String alias) {
    return $CuratedLibrarySeedsTable(attachedDatabase, alias);
  }
}

class CuratedLibrarySeed extends DataClass
    implements Insertable<CuratedLibrarySeed> {
  final String seedKey;
  final int packVersion;
  final bool dismissed;
  final DateTime appliedAt;
  const CuratedLibrarySeed({
    required this.seedKey,
    required this.packVersion,
    required this.dismissed,
    required this.appliedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seed_key'] = Variable<String>(seedKey);
    map['pack_version'] = Variable<int>(packVersion);
    map['dismissed'] = Variable<bool>(dismissed);
    map['applied_at'] = Variable<DateTime>(appliedAt);
    return map;
  }

  CuratedLibrarySeedsCompanion toCompanion(bool nullToAbsent) {
    return CuratedLibrarySeedsCompanion(
      seedKey: Value(seedKey),
      packVersion: Value(packVersion),
      dismissed: Value(dismissed),
      appliedAt: Value(appliedAt),
    );
  }

  factory CuratedLibrarySeed.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CuratedLibrarySeed(
      seedKey: serializer.fromJson<String>(json['seedKey']),
      packVersion: serializer.fromJson<int>(json['packVersion']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
      appliedAt: serializer.fromJson<DateTime>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seedKey': serializer.toJson<String>(seedKey),
      'packVersion': serializer.toJson<int>(packVersion),
      'dismissed': serializer.toJson<bool>(dismissed),
      'appliedAt': serializer.toJson<DateTime>(appliedAt),
    };
  }

  CuratedLibrarySeed copyWith({
    String? seedKey,
    int? packVersion,
    bool? dismissed,
    DateTime? appliedAt,
  }) => CuratedLibrarySeed(
    seedKey: seedKey ?? this.seedKey,
    packVersion: packVersion ?? this.packVersion,
    dismissed: dismissed ?? this.dismissed,
    appliedAt: appliedAt ?? this.appliedAt,
  );
  CuratedLibrarySeed copyWithCompanion(CuratedLibrarySeedsCompanion data) {
    return CuratedLibrarySeed(
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
      packVersion: data.packVersion.present
          ? data.packVersion.value
          : this.packVersion,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CuratedLibrarySeed(')
          ..write('seedKey: $seedKey, ')
          ..write('packVersion: $packVersion, ')
          ..write('dismissed: $dismissed, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seedKey, packVersion, dismissed, appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CuratedLibrarySeed &&
          other.seedKey == this.seedKey &&
          other.packVersion == this.packVersion &&
          other.dismissed == this.dismissed &&
          other.appliedAt == this.appliedAt);
}

class CuratedLibrarySeedsCompanion extends UpdateCompanion<CuratedLibrarySeed> {
  final Value<String> seedKey;
  final Value<int> packVersion;
  final Value<bool> dismissed;
  final Value<DateTime> appliedAt;
  final Value<int> rowid;
  const CuratedLibrarySeedsCompanion({
    this.seedKey = const Value.absent(),
    this.packVersion = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CuratedLibrarySeedsCompanion.insert({
    required String seedKey,
    required int packVersion,
    this.dismissed = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : seedKey = Value(seedKey),
       packVersion = Value(packVersion);
  static Insertable<CuratedLibrarySeed> custom({
    Expression<String>? seedKey,
    Expression<int>? packVersion,
    Expression<bool>? dismissed,
    Expression<DateTime>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (seedKey != null) 'seed_key': seedKey,
      if (packVersion != null) 'pack_version': packVersion,
      if (dismissed != null) 'dismissed': dismissed,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CuratedLibrarySeedsCompanion copyWith({
    Value<String>? seedKey,
    Value<int>? packVersion,
    Value<bool>? dismissed,
    Value<DateTime>? appliedAt,
    Value<int>? rowid,
  }) {
    return CuratedLibrarySeedsCompanion(
      seedKey: seedKey ?? this.seedKey,
      packVersion: packVersion ?? this.packVersion,
      dismissed: dismissed ?? this.dismissed,
      appliedAt: appliedAt ?? this.appliedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
    }
    if (packVersion.present) {
      map['pack_version'] = Variable<int>(packVersion.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<DateTime>(appliedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CuratedLibrarySeedsCompanion(')
          ..write('seedKey: $seedKey, ')
          ..write('packVersion: $packVersion, ')
          ..write('dismissed: $dismissed, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLibraryVideosTable extends LocalLibraryVideos
    with TableInfo<$LocalLibraryVideosTable, LocalLibraryVideo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLibraryVideosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<int> libraryId = GeneratedColumn<int>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_libraries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationLabelMeta = const VerificationMeta(
    'durationLabel',
  );
  @override
  late final GeneratedColumn<String> durationLabel = GeneratedColumn<String>(
    'duration_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedLabelMeta = const VerificationMeta(
    'publishedLabel',
  );
  @override
  late final GeneratedColumn<String> publishedLabel = GeneratedColumn<String>(
    'published_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewsMeta = const VerificationMeta('views');
  @override
  late final GeneratedColumn<int> views = GeneratedColumn<int>(
    'views',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingVotesMeta = const VerificationMeta(
    'ratingVotes',
  );
  @override
  late final GeneratedColumn<int> ratingVotes = GeneratedColumn<int>(
    'rating_votes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    libraryId,
    videoId,
    title,
    slug,
    thumbnailUrl,
    durationLabel,
    publishedLabel,
    views,
    rating,
    ratingVotes,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_library_videos';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalLibraryVideo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('duration_label')) {
      context.handle(
        _durationLabelMeta,
        durationLabel.isAcceptableOrUnknown(
          data['duration_label']!,
          _durationLabelMeta,
        ),
      );
    }
    if (data.containsKey('published_label')) {
      context.handle(
        _publishedLabelMeta,
        publishedLabel.isAcceptableOrUnknown(
          data['published_label']!,
          _publishedLabelMeta,
        ),
      );
    }
    if (data.containsKey('views')) {
      context.handle(
        _viewsMeta,
        views.isAcceptableOrUnknown(data['views']!, _viewsMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('rating_votes')) {
      context.handle(
        _ratingVotesMeta,
        ratingVotes.isAcceptableOrUnknown(
          data['rating_votes']!,
          _ratingVotesMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {libraryId, videoId};
  @override
  LocalLibraryVideo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLibraryVideo(
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}library_id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      durationLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration_label'],
      ),
      publishedLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}published_label'],
      ),
      views: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}views'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      ratingVotes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating_votes'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LocalLibraryVideosTable createAlias(String alias) {
    return $LocalLibraryVideosTable(attachedDatabase, alias);
  }
}

class LocalLibraryVideo extends DataClass
    implements Insertable<LocalLibraryVideo> {
  final int libraryId;
  final String videoId;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final String? durationLabel;
  final String? publishedLabel;
  final int? views;
  final int? rating;
  final int? ratingVotes;
  final DateTime addedAt;
  const LocalLibraryVideo({
    required this.libraryId,
    required this.videoId,
    required this.title,
    required this.slug,
    this.thumbnailUrl,
    this.durationLabel,
    this.publishedLabel,
    this.views,
    this.rating,
    this.ratingVotes,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['library_id'] = Variable<int>(libraryId);
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['slug'] = Variable<String>(slug);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || durationLabel != null) {
      map['duration_label'] = Variable<String>(durationLabel);
    }
    if (!nullToAbsent || publishedLabel != null) {
      map['published_label'] = Variable<String>(publishedLabel);
    }
    if (!nullToAbsent || views != null) {
      map['views'] = Variable<int>(views);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    if (!nullToAbsent || ratingVotes != null) {
      map['rating_votes'] = Variable<int>(ratingVotes);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LocalLibraryVideosCompanion toCompanion(bool nullToAbsent) {
    return LocalLibraryVideosCompanion(
      libraryId: Value(libraryId),
      videoId: Value(videoId),
      title: Value(title),
      slug: Value(slug),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationLabel: durationLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(durationLabel),
      publishedLabel: publishedLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedLabel),
      views: views == null && nullToAbsent
          ? const Value.absent()
          : Value(views),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      ratingVotes: ratingVotes == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingVotes),
      addedAt: Value(addedAt),
    );
  }

  factory LocalLibraryVideo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLibraryVideo(
      libraryId: serializer.fromJson<int>(json['libraryId']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      slug: serializer.fromJson<String>(json['slug']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationLabel: serializer.fromJson<String?>(json['durationLabel']),
      publishedLabel: serializer.fromJson<String?>(json['publishedLabel']),
      views: serializer.fromJson<int?>(json['views']),
      rating: serializer.fromJson<int?>(json['rating']),
      ratingVotes: serializer.fromJson<int?>(json['ratingVotes']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'libraryId': serializer.toJson<int>(libraryId),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'slug': serializer.toJson<String>(slug),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationLabel': serializer.toJson<String?>(durationLabel),
      'publishedLabel': serializer.toJson<String?>(publishedLabel),
      'views': serializer.toJson<int?>(views),
      'rating': serializer.toJson<int?>(rating),
      'ratingVotes': serializer.toJson<int?>(ratingVotes),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LocalLibraryVideo copyWith({
    int? libraryId,
    String? videoId,
    String? title,
    String? slug,
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> durationLabel = const Value.absent(),
    Value<String?> publishedLabel = const Value.absent(),
    Value<int?> views = const Value.absent(),
    Value<int?> rating = const Value.absent(),
    Value<int?> ratingVotes = const Value.absent(),
    DateTime? addedAt,
  }) => LocalLibraryVideo(
    libraryId: libraryId ?? this.libraryId,
    videoId: videoId ?? this.videoId,
    title: title ?? this.title,
    slug: slug ?? this.slug,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    durationLabel: durationLabel.present
        ? durationLabel.value
        : this.durationLabel,
    publishedLabel: publishedLabel.present
        ? publishedLabel.value
        : this.publishedLabel,
    views: views.present ? views.value : this.views,
    rating: rating.present ? rating.value : this.rating,
    ratingVotes: ratingVotes.present ? ratingVotes.value : this.ratingVotes,
    addedAt: addedAt ?? this.addedAt,
  );
  LocalLibraryVideo copyWithCompanion(LocalLibraryVideosCompanion data) {
    return LocalLibraryVideo(
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      slug: data.slug.present ? data.slug.value : this.slug,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationLabel: data.durationLabel.present
          ? data.durationLabel.value
          : this.durationLabel,
      publishedLabel: data.publishedLabel.present
          ? data.publishedLabel.value
          : this.publishedLabel,
      views: data.views.present ? data.views.value : this.views,
      rating: data.rating.present ? data.rating.value : this.rating,
      ratingVotes: data.ratingVotes.present
          ? data.ratingVotes.value
          : this.ratingVotes,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLibraryVideo(')
          ..write('libraryId: $libraryId, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationLabel: $durationLabel, ')
          ..write('publishedLabel: $publishedLabel, ')
          ..write('views: $views, ')
          ..write('rating: $rating, ')
          ..write('ratingVotes: $ratingVotes, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    libraryId,
    videoId,
    title,
    slug,
    thumbnailUrl,
    durationLabel,
    publishedLabel,
    views,
    rating,
    ratingVotes,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLibraryVideo &&
          other.libraryId == this.libraryId &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.slug == this.slug &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationLabel == this.durationLabel &&
          other.publishedLabel == this.publishedLabel &&
          other.views == this.views &&
          other.rating == this.rating &&
          other.ratingVotes == this.ratingVotes &&
          other.addedAt == this.addedAt);
}

class LocalLibraryVideosCompanion extends UpdateCompanion<LocalLibraryVideo> {
  final Value<int> libraryId;
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> slug;
  final Value<String?> thumbnailUrl;
  final Value<String?> durationLabel;
  final Value<String?> publishedLabel;
  final Value<int?> views;
  final Value<int?> rating;
  final Value<int?> ratingVotes;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const LocalLibraryVideosCompanion({
    this.libraryId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.slug = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationLabel = const Value.absent(),
    this.publishedLabel = const Value.absent(),
    this.views = const Value.absent(),
    this.rating = const Value.absent(),
    this.ratingVotes = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLibraryVideosCompanion.insert({
    required int libraryId,
    required String videoId,
    required String title,
    required String slug,
    this.thumbnailUrl = const Value.absent(),
    this.durationLabel = const Value.absent(),
    this.publishedLabel = const Value.absent(),
    this.views = const Value.absent(),
    this.rating = const Value.absent(),
    this.ratingVotes = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : libraryId = Value(libraryId),
       videoId = Value(videoId),
       title = Value(title),
       slug = Value(slug);
  static Insertable<LocalLibraryVideo> custom({
    Expression<int>? libraryId,
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? slug,
    Expression<String>? thumbnailUrl,
    Expression<String>? durationLabel,
    Expression<String>? publishedLabel,
    Expression<int>? views,
    Expression<int>? rating,
    Expression<int>? ratingVotes,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (libraryId != null) 'library_id': libraryId,
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (slug != null) 'slug': slug,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationLabel != null) 'duration_label': durationLabel,
      if (publishedLabel != null) 'published_label': publishedLabel,
      if (views != null) 'views': views,
      if (rating != null) 'rating': rating,
      if (ratingVotes != null) 'rating_votes': ratingVotes,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLibraryVideosCompanion copyWith({
    Value<int>? libraryId,
    Value<String>? videoId,
    Value<String>? title,
    Value<String>? slug,
    Value<String?>? thumbnailUrl,
    Value<String?>? durationLabel,
    Value<String?>? publishedLabel,
    Value<int?>? views,
    Value<int?>? rating,
    Value<int?>? ratingVotes,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return LocalLibraryVideosCompanion(
      libraryId: libraryId ?? this.libraryId,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationLabel: durationLabel ?? this.durationLabel,
      publishedLabel: publishedLabel ?? this.publishedLabel,
      views: views ?? this.views,
      rating: rating ?? this.rating,
      ratingVotes: ratingVotes ?? this.ratingVotes,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (libraryId.present) {
      map['library_id'] = Variable<int>(libraryId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationLabel.present) {
      map['duration_label'] = Variable<String>(durationLabel.value);
    }
    if (publishedLabel.present) {
      map['published_label'] = Variable<String>(publishedLabel.value);
    }
    if (views.present) {
      map['views'] = Variable<int>(views.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (ratingVotes.present) {
      map['rating_votes'] = Variable<int>(ratingVotes.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLibraryVideosCompanion(')
          ..write('libraryId: $libraryId, ')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationLabel: $durationLabel, ')
          ..write('publishedLabel: $publishedLabel, ')
          ..write('views: $views, ')
          ..write('rating: $rating, ')
          ..write('ratingVotes: $ratingVotes, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserAccountsTable userAccounts = $UserAccountsTable(this);
  late final $PlaybackPositionsTable playbackPositions =
      $PlaybackPositionsTable(this);
  late final $DownloadRecordsTable downloadRecords = $DownloadRecordsTable(
    this,
  );
  late final $SearchHistoriesTable searchHistories = $SearchHistoriesTable(
    this,
  );
  late final $LocalLibrariesTable localLibraries = $LocalLibrariesTable(this);
  late final $CuratedLibrarySeedsTable curatedLibrarySeeds =
      $CuratedLibrarySeedsTable(this);
  late final $LocalLibraryVideosTable localLibraryVideos =
      $LocalLibraryVideosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userAccounts,
    playbackPositions,
    downloadRecords,
    searchHistories,
    localLibraries,
    curatedLibrarySeeds,
    localLibraryVideos,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playback_positions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('search_histories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_libraries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_library_videos', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$UserAccountsTableCreateCompanionBuilder =
    UserAccountsCompanion Function({
      required String userId,
      Value<String?> displayName,
      Value<String?> avatarUrl,
      Value<DateTime> createdAt,
      Value<DateTime> lastAuthenticatedAt,
      Value<int> rowid,
    });
typedef $$UserAccountsTableUpdateCompanionBuilder =
    UserAccountsCompanion Function({
      Value<String> userId,
      Value<String?> displayName,
      Value<String?> avatarUrl,
      Value<DateTime> createdAt,
      Value<DateTime> lastAuthenticatedAt,
      Value<int> rowid,
    });

final class $$UserAccountsTableReferences
    extends BaseReferences<_$AppDatabase, $UserAccountsTable, UserAccount> {
  $$UserAccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaybackPositionsTable, List<PlaybackPosition>>
  _playbackPositionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playbackPositions,
        aliasName: 'user_accounts__user_id__playback_positions__user_id',
      );

  $$PlaybackPositionsTableProcessedTableManager get playbackPositionsRefs {
    final manager =
        $$PlaybackPositionsTableTableManager(
          $_db,
          $_db.playbackPositions,
        ).filter(
          (f) => f.userId.userId.sqlEquals($_itemColumn<String>('user_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _playbackPositionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadRecordsTable, List<DownloadRecord>>
  _downloadRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadRecords,
    aliasName: 'user_accounts__user_id__download_records__user_id',
  );

  $$DownloadRecordsTableProcessedTableManager get downloadRecordsRefs {
    final manager =
        $$DownloadRecordsTableTableManager($_db, $_db.downloadRecords).filter(
          (f) => f.userId.userId.sqlEquals($_itemColumn<String>('user_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _downloadRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SearchHistoriesTable, List<SearchHistory>>
  _searchHistoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.searchHistories,
    aliasName: 'user_accounts__user_id__search_histories__user_id',
  );

  $$SearchHistoriesTableProcessedTableManager get searchHistoriesRefs {
    final manager =
        $$SearchHistoriesTableTableManager($_db, $_db.searchHistories).filter(
          (f) => f.userId.userId.sqlEquals($_itemColumn<String>('user_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _searchHistoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $UserAccountsTable> {
  $$UserAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAuthenticatedAt => $composableBuilder(
    column: $table.lastAuthenticatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playbackPositionsRefs(
    Expression<bool> Function($$PlaybackPositionsTableFilterComposer f) f,
  ) {
    final $$PlaybackPositionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.playbackPositions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackPositionsTableFilterComposer(
            $db: $db,
            $table: $db.playbackPositions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadRecordsRefs(
    Expression<bool> Function($$DownloadRecordsTableFilterComposer f) f,
  ) {
    final $$DownloadRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.downloadRecords,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadRecordsTableFilterComposer(
            $db: $db,
            $table: $db.downloadRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> searchHistoriesRefs(
    Expression<bool> Function($$SearchHistoriesTableFilterComposer f) f,
  ) {
    final $$SearchHistoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.searchHistories,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchHistoriesTableFilterComposer(
            $db: $db,
            $table: $db.searchHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserAccountsTable> {
  $$UserAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAuthenticatedAt => $composableBuilder(
    column: $table.lastAuthenticatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserAccountsTable> {
  $$UserAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAuthenticatedAt => $composableBuilder(
    column: $table.lastAuthenticatedAt,
    builder: (column) => column,
  );

  Expression<T> playbackPositionsRefs<T extends Object>(
    Expression<T> Function($$PlaybackPositionsTableAnnotationComposer a) f,
  ) {
    final $$PlaybackPositionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.userId,
          referencedTable: $db.playbackPositions,
          getReferencedColumn: (t) => t.userId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaybackPositionsTableAnnotationComposer(
                $db: $db,
                $table: $db.playbackPositions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> downloadRecordsRefs<T extends Object>(
    Expression<T> Function($$DownloadRecordsTableAnnotationComposer a) f,
  ) {
    final $$DownloadRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.downloadRecords,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> searchHistoriesRefs<T extends Object>(
    Expression<T> Function($$SearchHistoriesTableAnnotationComposer a) f,
  ) {
    final $$SearchHistoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.searchHistories,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchHistoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.searchHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserAccountsTable,
          UserAccount,
          $$UserAccountsTableFilterComposer,
          $$UserAccountsTableOrderingComposer,
          $$UserAccountsTableAnnotationComposer,
          $$UserAccountsTableCreateCompanionBuilder,
          $$UserAccountsTableUpdateCompanionBuilder,
          (UserAccount, $$UserAccountsTableReferences),
          UserAccount,
          PrefetchHooks Function({
            bool playbackPositionsRefs,
            bool downloadRecordsRefs,
            bool searchHistoriesRefs,
          })
        > {
  $$UserAccountsTableTableManager(_$AppDatabase db, $UserAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAuthenticatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAccountsCompanion(
                userId: userId,
                displayName: displayName,
                avatarUrl: avatarUrl,
                createdAt: createdAt,
                lastAuthenticatedAt: lastAuthenticatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String?> displayName = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAuthenticatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAccountsCompanion.insert(
                userId: userId,
                displayName: displayName,
                avatarUrl: avatarUrl,
                createdAt: createdAt,
                lastAuthenticatedAt: lastAuthenticatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                playbackPositionsRefs = false,
                downloadRecordsRefs = false,
                searchHistoriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playbackPositionsRefs) db.playbackPositions,
                    if (downloadRecordsRefs) db.downloadRecords,
                    if (searchHistoriesRefs) db.searchHistories,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playbackPositionsRefs)
                        await $_getPrefetchedData<
                          UserAccount,
                          $UserAccountsTable,
                          PlaybackPosition
                        >(
                          currentTable: table,
                          referencedTable: $$UserAccountsTableReferences
                              ._playbackPositionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).playbackPositionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.userId,
                              ),
                          typedResults: items,
                        ),
                      if (downloadRecordsRefs)
                        await $_getPrefetchedData<
                          UserAccount,
                          $UserAccountsTable,
                          DownloadRecord
                        >(
                          currentTable: table,
                          referencedTable: $$UserAccountsTableReferences
                              ._downloadRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.userId,
                              ),
                          typedResults: items,
                        ),
                      if (searchHistoriesRefs)
                        await $_getPrefetchedData<
                          UserAccount,
                          $UserAccountsTable,
                          SearchHistory
                        >(
                          currentTable: table,
                          referencedTable: $$UserAccountsTableReferences
                              ._searchHistoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).searchHistoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.userId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UserAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserAccountsTable,
      UserAccount,
      $$UserAccountsTableFilterComposer,
      $$UserAccountsTableOrderingComposer,
      $$UserAccountsTableAnnotationComposer,
      $$UserAccountsTableCreateCompanionBuilder,
      $$UserAccountsTableUpdateCompanionBuilder,
      (UserAccount, $$UserAccountsTableReferences),
      UserAccount,
      PrefetchHooks Function({
        bool playbackPositionsRefs,
        bool downloadRecordsRefs,
        bool searchHistoriesRefs,
      })
    >;
typedef $$PlaybackPositionsTableCreateCompanionBuilder =
    PlaybackPositionsCompanion Function({
      required String userId,
      required String videoId,
      Value<String?> title,
      Value<String?> slug,
      Value<String?> thumbnailUrl,
      Value<String?> durationLabel,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PlaybackPositionsTableUpdateCompanionBuilder =
    PlaybackPositionsCompanion Function({
      Value<String> userId,
      Value<String> videoId,
      Value<String?> title,
      Value<String?> slug,
      Value<String?> thumbnailUrl,
      Value<String?> durationLabel,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlaybackPositionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaybackPositionsTable,
          PlaybackPosition
        > {
  $$PlaybackPositionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UserAccountsTable _userIdTable(_$AppDatabase db) => db.userAccounts
      .createAlias('playback_positions__user_id__user_accounts__user_id');

  $$UserAccountsTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserAccountsTableTableManager(
      $_db,
      $_db.userAccounts,
    ).filter((f) => f.userId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTable> {
  $$PlaybackPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get durationLabel => $composableBuilder(
    column: $table.durationLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UserAccountsTableFilterComposer get userId {
    final $$UserAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableFilterComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTable> {
  $$PlaybackPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get durationLabel => $composableBuilder(
    column: $table.durationLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserAccountsTableOrderingComposer get userId {
    final $$UserAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTable> {
  $$PlaybackPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get durationLabel => $composableBuilder(
    column: $table.durationLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$UserAccountsTableAnnotationComposer get userId {
    final $$UserAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackPositionsTable,
          PlaybackPosition,
          $$PlaybackPositionsTableFilterComposer,
          $$PlaybackPositionsTableOrderingComposer,
          $$PlaybackPositionsTableAnnotationComposer,
          $$PlaybackPositionsTableCreateCompanionBuilder,
          $$PlaybackPositionsTableUpdateCompanionBuilder,
          (PlaybackPosition, $$PlaybackPositionsTableReferences),
          PlaybackPosition,
          PrefetchHooks Function({bool userId})
        > {
  $$PlaybackPositionsTableTableManager(
    _$AppDatabase db,
    $PlaybackPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackPositionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> durationLabel = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackPositionsCompanion(
                userId: userId,
                videoId: videoId,
                title: title,
                slug: slug,
                thumbnailUrl: thumbnailUrl,
                durationLabel: durationLabel,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String videoId,
                Value<String?> title = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> durationLabel = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackPositionsCompanion.insert(
                userId: userId,
                videoId: videoId,
                title: title,
                slug: slug,
                thumbnailUrl: thumbnailUrl,
                durationLabel: durationLabel,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackPositionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable:
                                    $$PlaybackPositionsTableReferences
                                        ._userIdTable(db),
                                referencedColumn:
                                    $$PlaybackPositionsTableReferences
                                        ._userIdTable(db)
                                        .userId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackPositionsTable,
      PlaybackPosition,
      $$PlaybackPositionsTableFilterComposer,
      $$PlaybackPositionsTableOrderingComposer,
      $$PlaybackPositionsTableAnnotationComposer,
      $$PlaybackPositionsTableCreateCompanionBuilder,
      $$PlaybackPositionsTableUpdateCompanionBuilder,
      (PlaybackPosition, $$PlaybackPositionsTableReferences),
      PlaybackPosition,
      PrefetchHooks Function({bool userId})
    >;
typedef $$DownloadRecordsTableCreateCompanionBuilder =
    DownloadRecordsCompanion Function({
      required String id,
      required String userId,
      required String videoId,
      required String title,
      required String quality,
      Value<String?> thumbnailUrl,
      Value<String?> fileName,
      required String state,
      Value<String?> taskId,
      Value<String?> filePath,
      Value<int> bytesDownloaded,
      Value<int?> totalBytes,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadRecordsTableUpdateCompanionBuilder =
    DownloadRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> videoId,
      Value<String> title,
      Value<String> quality,
      Value<String?> thumbnailUrl,
      Value<String?> fileName,
      Value<String> state,
      Value<String?> taskId,
      Value<String?> filePath,
      Value<int> bytesDownloaded,
      Value<int?> totalBytes,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$DownloadRecordsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DownloadRecordsTable, DownloadRecord> {
  $$DownloadRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UserAccountsTable _userIdTable(_$AppDatabase db) => db.userAccounts
      .createAlias('download_records__user_id__user_accounts__user_id');

  $$UserAccountsTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserAccountsTableTableManager(
      $_db,
      $_db.userAccounts,
    ).filter((f) => f.userId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UserAccountsTableFilterComposer get userId {
    final $$UserAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableFilterComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserAccountsTableOrderingComposer get userId {
    final $$UserAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get bytesDownloaded => $composableBuilder(
    column: $table.bytesDownloaded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$UserAccountsTableAnnotationComposer get userId {
    final $$UserAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadRecordsTable,
          DownloadRecord,
          $$DownloadRecordsTableFilterComposer,
          $$DownloadRecordsTableOrderingComposer,
          $$DownloadRecordsTableAnnotationComposer,
          $$DownloadRecordsTableCreateCompanionBuilder,
          $$DownloadRecordsTableUpdateCompanionBuilder,
          (DownloadRecord, $$DownloadRecordsTableReferences),
          DownloadRecord,
          PrefetchHooks Function({bool userId})
        > {
  $$DownloadRecordsTableTableManager(
    _$AppDatabase db,
    $DownloadRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> quality = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int> bytesDownloaded = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordsCompanion(
                id: id,
                userId: userId,
                videoId: videoId,
                title: title,
                quality: quality,
                thumbnailUrl: thumbnailUrl,
                fileName: fileName,
                state: state,
                taskId: taskId,
                filePath: filePath,
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String videoId,
                required String title,
                required String quality,
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                required String state,
                Value<String?> taskId = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int> bytesDownloaded = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordsCompanion.insert(
                id: id,
                userId: userId,
                videoId: videoId,
                title: title,
                quality: quality,
                thumbnailUrl: thumbnailUrl,
                fileName: fileName,
                state: state,
                taskId: taskId,
                filePath: filePath,
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable:
                                    $$DownloadRecordsTableReferences
                                        ._userIdTable(db),
                                referencedColumn:
                                    $$DownloadRecordsTableReferences
                                        ._userIdTable(db)
                                        .userId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadRecordsTable,
      DownloadRecord,
      $$DownloadRecordsTableFilterComposer,
      $$DownloadRecordsTableOrderingComposer,
      $$DownloadRecordsTableAnnotationComposer,
      $$DownloadRecordsTableCreateCompanionBuilder,
      $$DownloadRecordsTableUpdateCompanionBuilder,
      (DownloadRecord, $$DownloadRecordsTableReferences),
      DownloadRecord,
      PrefetchHooks Function({bool userId})
    >;
typedef $$SearchHistoriesTableCreateCompanionBuilder =
    SearchHistoriesCompanion Function({
      required String userId,
      required String normalizedQuery,
      required String displayQuery,
      Value<DateTime> lastSearchedAt,
      Value<int> rowid,
    });
typedef $$SearchHistoriesTableUpdateCompanionBuilder =
    SearchHistoriesCompanion Function({
      Value<String> userId,
      Value<String> normalizedQuery,
      Value<String> displayQuery,
      Value<DateTime> lastSearchedAt,
      Value<int> rowid,
    });

final class $$SearchHistoriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $SearchHistoriesTable, SearchHistory> {
  $$SearchHistoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UserAccountsTable _userIdTable(_$AppDatabase db) => db.userAccounts
      .createAlias('search_histories__user_id__user_accounts__user_id');

  $$UserAccountsTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserAccountsTableTableManager(
      $_db,
      $_db.userAccounts,
    ).filter((f) => f.userId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SearchHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get normalizedQuery => $composableBuilder(
    column: $table.normalizedQuery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayQuery => $composableBuilder(
    column: $table.displayQuery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSearchedAt => $composableBuilder(
    column: $table.lastSearchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UserAccountsTableFilterComposer get userId {
    final $$UserAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableFilterComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get normalizedQuery => $composableBuilder(
    column: $table.normalizedQuery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayQuery => $composableBuilder(
    column: $table.displayQuery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSearchedAt => $composableBuilder(
    column: $table.lastSearchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserAccountsTableOrderingComposer get userId {
    final $$UserAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get normalizedQuery => $composableBuilder(
    column: $table.normalizedQuery,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayQuery => $composableBuilder(
    column: $table.displayQuery,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSearchedAt => $composableBuilder(
    column: $table.lastSearchedAt,
    builder: (column) => column,
  );

  $$UserAccountsTableAnnotationComposer get userId {
    final $$UserAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userAccounts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.userAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoriesTable,
          SearchHistory,
          $$SearchHistoriesTableFilterComposer,
          $$SearchHistoriesTableOrderingComposer,
          $$SearchHistoriesTableAnnotationComposer,
          $$SearchHistoriesTableCreateCompanionBuilder,
          $$SearchHistoriesTableUpdateCompanionBuilder,
          (SearchHistory, $$SearchHistoriesTableReferences),
          SearchHistory,
          PrefetchHooks Function({bool userId})
        > {
  $$SearchHistoriesTableTableManager(
    _$AppDatabase db,
    $SearchHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> normalizedQuery = const Value.absent(),
                Value<String> displayQuery = const Value.absent(),
                Value<DateTime> lastSearchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoriesCompanion(
                userId: userId,
                normalizedQuery: normalizedQuery,
                displayQuery: displayQuery,
                lastSearchedAt: lastSearchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String normalizedQuery,
                required String displayQuery,
                Value<DateTime> lastSearchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoriesCompanion.insert(
                userId: userId,
                normalizedQuery: normalizedQuery,
                displayQuery: displayQuery,
                lastSearchedAt: lastSearchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SearchHistoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable:
                                    $$SearchHistoriesTableReferences
                                        ._userIdTable(db),
                                referencedColumn:
                                    $$SearchHistoriesTableReferences
                                        ._userIdTable(db)
                                        .userId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SearchHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoriesTable,
      SearchHistory,
      $$SearchHistoriesTableFilterComposer,
      $$SearchHistoriesTableOrderingComposer,
      $$SearchHistoriesTableAnnotationComposer,
      $$SearchHistoriesTableCreateCompanionBuilder,
      $$SearchHistoriesTableUpdateCompanionBuilder,
      (SearchHistory, $$SearchHistoriesTableReferences),
      SearchHistory,
      PrefetchHooks Function({bool userId})
    >;
typedef $$LocalLibrariesTableCreateCompanionBuilder =
    LocalLibrariesCompanion Function({
      Value<int> id,
      required String name,
      required String normalizedName,
      Value<String?> seedKey,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$LocalLibrariesTableUpdateCompanionBuilder =
    LocalLibrariesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<String?> seedKey,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$LocalLibrariesTableReferences
    extends BaseReferences<_$AppDatabase, $LocalLibrariesTable, LocalLibrary> {
  $$LocalLibrariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LocalLibraryVideosTable, List<LocalLibraryVideo>>
  _localLibraryVideosRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localLibraryVideos,
        aliasName: 'local_libraries__id__local_library_videos__library_id',
      );

  $$LocalLibraryVideosTableProcessedTableManager get localLibraryVideosRefs {
    final manager = $$LocalLibraryVideosTableTableManager(
      $_db,
      $_db.localLibraryVideos,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localLibraryVideosRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalLibrariesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLibrariesTable> {
  $$LocalLibrariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localLibraryVideosRefs(
    Expression<bool> Function($$LocalLibraryVideosTableFilterComposer f) f,
  ) {
    final $$LocalLibraryVideosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localLibraryVideos,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLibraryVideosTableFilterComposer(
            $db: $db,
            $table: $db.localLibraryVideos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalLibrariesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLibrariesTable> {
  $$LocalLibrariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalLibrariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLibrariesTable> {
  $$LocalLibrariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> localLibraryVideosRefs<T extends Object>(
    Expression<T> Function($$LocalLibraryVideosTableAnnotationComposer a) f,
  ) {
    final $$LocalLibraryVideosTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localLibraryVideos,
          getReferencedColumn: (t) => t.libraryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalLibraryVideosTableAnnotationComposer(
                $db: $db,
                $table: $db.localLibraryVideos,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalLibrariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLibrariesTable,
          LocalLibrary,
          $$LocalLibrariesTableFilterComposer,
          $$LocalLibrariesTableOrderingComposer,
          $$LocalLibrariesTableAnnotationComposer,
          $$LocalLibrariesTableCreateCompanionBuilder,
          $$LocalLibrariesTableUpdateCompanionBuilder,
          (LocalLibrary, $$LocalLibrariesTableReferences),
          LocalLibrary,
          PrefetchHooks Function({bool localLibraryVideosRefs})
        > {
  $$LocalLibrariesTableTableManager(
    _$AppDatabase db,
    $LocalLibrariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLibrariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLibrariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLibrariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String?> seedKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalLibrariesCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                seedKey: seedKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String normalizedName,
                Value<String?> seedKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalLibrariesCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                seedKey: seedKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalLibrariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localLibraryVideosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localLibraryVideosRefs) db.localLibraryVideos,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localLibraryVideosRefs)
                    await $_getPrefetchedData<
                      LocalLibrary,
                      $LocalLibrariesTable,
                      LocalLibraryVideo
                    >(
                      currentTable: table,
                      referencedTable: $$LocalLibrariesTableReferences
                          ._localLibraryVideosRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalLibrariesTableReferences(
                            db,
                            table,
                            p0,
                          ).localLibraryVideosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.libraryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalLibrariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLibrariesTable,
      LocalLibrary,
      $$LocalLibrariesTableFilterComposer,
      $$LocalLibrariesTableOrderingComposer,
      $$LocalLibrariesTableAnnotationComposer,
      $$LocalLibrariesTableCreateCompanionBuilder,
      $$LocalLibrariesTableUpdateCompanionBuilder,
      (LocalLibrary, $$LocalLibrariesTableReferences),
      LocalLibrary,
      PrefetchHooks Function({bool localLibraryVideosRefs})
    >;
typedef $$CuratedLibrarySeedsTableCreateCompanionBuilder =
    CuratedLibrarySeedsCompanion Function({
      required String seedKey,
      required int packVersion,
      Value<bool> dismissed,
      Value<DateTime> appliedAt,
      Value<int> rowid,
    });
typedef $$CuratedLibrarySeedsTableUpdateCompanionBuilder =
    CuratedLibrarySeedsCompanion Function({
      Value<String> seedKey,
      Value<int> packVersion,
      Value<bool> dismissed,
      Value<DateTime> appliedAt,
      Value<int> rowid,
    });

class $$CuratedLibrarySeedsTableFilterComposer
    extends Composer<_$AppDatabase, $CuratedLibrarySeedsTable> {
  $$CuratedLibrarySeedsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packVersion => $composableBuilder(
    column: $table.packVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CuratedLibrarySeedsTableOrderingComposer
    extends Composer<_$AppDatabase, $CuratedLibrarySeedsTable> {
  $$CuratedLibrarySeedsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packVersion => $composableBuilder(
    column: $table.packVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CuratedLibrarySeedsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CuratedLibrarySeedsTable> {
  $$CuratedLibrarySeedsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

  GeneratedColumn<int> get packVersion => $composableBuilder(
    column: $table.packVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  GeneratedColumn<DateTime> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$CuratedLibrarySeedsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CuratedLibrarySeedsTable,
          CuratedLibrarySeed,
          $$CuratedLibrarySeedsTableFilterComposer,
          $$CuratedLibrarySeedsTableOrderingComposer,
          $$CuratedLibrarySeedsTableAnnotationComposer,
          $$CuratedLibrarySeedsTableCreateCompanionBuilder,
          $$CuratedLibrarySeedsTableUpdateCompanionBuilder,
          (
            CuratedLibrarySeed,
            BaseReferences<
              _$AppDatabase,
              $CuratedLibrarySeedsTable,
              CuratedLibrarySeed
            >,
          ),
          CuratedLibrarySeed,
          PrefetchHooks Function()
        > {
  $$CuratedLibrarySeedsTableTableManager(
    _$AppDatabase db,
    $CuratedLibrarySeedsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CuratedLibrarySeedsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CuratedLibrarySeedsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CuratedLibrarySeedsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> seedKey = const Value.absent(),
                Value<int> packVersion = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<DateTime> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CuratedLibrarySeedsCompanion(
                seedKey: seedKey,
                packVersion: packVersion,
                dismissed: dismissed,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String seedKey,
                required int packVersion,
                Value<bool> dismissed = const Value.absent(),
                Value<DateTime> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CuratedLibrarySeedsCompanion.insert(
                seedKey: seedKey,
                packVersion: packVersion,
                dismissed: dismissed,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CuratedLibrarySeedsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CuratedLibrarySeedsTable,
      CuratedLibrarySeed,
      $$CuratedLibrarySeedsTableFilterComposer,
      $$CuratedLibrarySeedsTableOrderingComposer,
      $$CuratedLibrarySeedsTableAnnotationComposer,
      $$CuratedLibrarySeedsTableCreateCompanionBuilder,
      $$CuratedLibrarySeedsTableUpdateCompanionBuilder,
      (
        CuratedLibrarySeed,
        BaseReferences<
          _$AppDatabase,
          $CuratedLibrarySeedsTable,
          CuratedLibrarySeed
        >,
      ),
      CuratedLibrarySeed,
      PrefetchHooks Function()
    >;
typedef $$LocalLibraryVideosTableCreateCompanionBuilder =
    LocalLibraryVideosCompanion Function({
      required int libraryId,
      required String videoId,
      required String title,
      required String slug,
      Value<String?> thumbnailUrl,
      Value<String?> durationLabel,
      Value<String?> publishedLabel,
      Value<int?> views,
      Value<int?> rating,
      Value<int?> ratingVotes,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$LocalLibraryVideosTableUpdateCompanionBuilder =
    LocalLibraryVideosCompanion Function({
      Value<int> libraryId,
      Value<String> videoId,
      Value<String> title,
      Value<String> slug,
      Value<String?> thumbnailUrl,
      Value<String?> durationLabel,
      Value<String?> publishedLabel,
      Value<int?> views,
      Value<int?> rating,
      Value<int?> ratingVotes,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$LocalLibraryVideosTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalLibraryVideosTable,
          LocalLibraryVideo
        > {
  $$LocalLibraryVideosTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalLibrariesTable _libraryIdTable(_$AppDatabase db) => db
      .localLibraries
      .createAlias('local_library_videos__library_id__local_libraries__id');

  $$LocalLibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<int>('library_id')!;

    final manager = $$LocalLibrariesTableTableManager(
      $_db,
      $_db.localLibraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalLibraryVideosTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLibraryVideosTable> {
  $$LocalLibraryVideosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get durationLabel => $composableBuilder(
    column: $table.durationLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishedLabel => $composableBuilder(
    column: $table.publishedLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get views => $composableBuilder(
    column: $table.views,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratingVotes => $composableBuilder(
    column: $table.ratingVotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalLibrariesTableFilterComposer get libraryId {
    final $$LocalLibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.localLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLibrariesTableFilterComposer(
            $db: $db,
            $table: $db.localLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLibraryVideosTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLibraryVideosTable> {
  $$LocalLibraryVideosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get durationLabel => $composableBuilder(
    column: $table.durationLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishedLabel => $composableBuilder(
    column: $table.publishedLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get views => $composableBuilder(
    column: $table.views,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratingVotes => $composableBuilder(
    column: $table.ratingVotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalLibrariesTableOrderingComposer get libraryId {
    final $$LocalLibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.localLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.localLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLibraryVideosTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLibraryVideosTable> {
  $$LocalLibraryVideosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get durationLabel => $composableBuilder(
    column: $table.durationLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishedLabel => $composableBuilder(
    column: $table.publishedLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get views =>
      $composableBuilder(column: $table.views, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get ratingVotes => $composableBuilder(
    column: $table.ratingVotes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$LocalLibrariesTableAnnotationComposer get libraryId {
    final $$LocalLibrariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.localLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLibrariesTableAnnotationComposer(
            $db: $db,
            $table: $db.localLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLibraryVideosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLibraryVideosTable,
          LocalLibraryVideo,
          $$LocalLibraryVideosTableFilterComposer,
          $$LocalLibraryVideosTableOrderingComposer,
          $$LocalLibraryVideosTableAnnotationComposer,
          $$LocalLibraryVideosTableCreateCompanionBuilder,
          $$LocalLibraryVideosTableUpdateCompanionBuilder,
          (LocalLibraryVideo, $$LocalLibraryVideosTableReferences),
          LocalLibraryVideo,
          PrefetchHooks Function({bool libraryId})
        > {
  $$LocalLibraryVideosTableTableManager(
    _$AppDatabase db,
    $LocalLibraryVideosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLibraryVideosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLibraryVideosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLibraryVideosTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> libraryId = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> durationLabel = const Value.absent(),
                Value<String?> publishedLabel = const Value.absent(),
                Value<int?> views = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<int?> ratingVotes = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLibraryVideosCompanion(
                libraryId: libraryId,
                videoId: videoId,
                title: title,
                slug: slug,
                thumbnailUrl: thumbnailUrl,
                durationLabel: durationLabel,
                publishedLabel: publishedLabel,
                views: views,
                rating: rating,
                ratingVotes: ratingVotes,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int libraryId,
                required String videoId,
                required String title,
                required String slug,
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> durationLabel = const Value.absent(),
                Value<String?> publishedLabel = const Value.absent(),
                Value<int?> views = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<int?> ratingVotes = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLibraryVideosCompanion.insert(
                libraryId: libraryId,
                videoId: videoId,
                title: title,
                slug: slug,
                thumbnailUrl: thumbnailUrl,
                durationLabel: durationLabel,
                publishedLabel: publishedLabel,
                views: views,
                rating: rating,
                ratingVotes: ratingVotes,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalLibraryVideosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (libraryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryId,
                                referencedTable:
                                    $$LocalLibraryVideosTableReferences
                                        ._libraryIdTable(db),
                                referencedColumn:
                                    $$LocalLibraryVideosTableReferences
                                        ._libraryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalLibraryVideosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLibraryVideosTable,
      LocalLibraryVideo,
      $$LocalLibraryVideosTableFilterComposer,
      $$LocalLibraryVideosTableOrderingComposer,
      $$LocalLibraryVideosTableAnnotationComposer,
      $$LocalLibraryVideosTableCreateCompanionBuilder,
      $$LocalLibraryVideosTableUpdateCompanionBuilder,
      (LocalLibraryVideo, $$LocalLibraryVideosTableReferences),
      LocalLibraryVideo,
      PrefetchHooks Function({bool libraryId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserAccountsTableTableManager get userAccounts =>
      $$UserAccountsTableTableManager(_db, _db.userAccounts);
  $$PlaybackPositionsTableTableManager get playbackPositions =>
      $$PlaybackPositionsTableTableManager(_db, _db.playbackPositions);
  $$DownloadRecordsTableTableManager get downloadRecords =>
      $$DownloadRecordsTableTableManager(_db, _db.downloadRecords);
  $$SearchHistoriesTableTableManager get searchHistories =>
      $$SearchHistoriesTableTableManager(_db, _db.searchHistories);
  $$LocalLibrariesTableTableManager get localLibraries =>
      $$LocalLibrariesTableTableManager(_db, _db.localLibraries);
  $$CuratedLibrarySeedsTableTableManager get curatedLibrarySeeds =>
      $$CuratedLibrarySeedsTableTableManager(_db, _db.curatedLibrarySeeds);
  $$LocalLibraryVideosTableTableManager get localLibraryVideos =>
      $$LocalLibraryVideosTableTableManager(_db, _db.localLibraryVideos);
}
