// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DocsTable extends Docs with TableInfo<$DocsTable, Doc> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    collection,
    id,
    json,
    updatedAt,
    deleted,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'docs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Doc> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, id};
  @override
  Doc map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Doc(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $DocsTable createAlias(String alias) {
    return $DocsTable(attachedDatabase, alias);
  }
}

class Doc extends DataClass implements Insertable<Doc> {
  final String collection;
  final String id;
  final String json;
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  const Doc({
    required this.collection,
    required this.id,
    required this.json,
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  DocsCompanion toCompanion(bool nullToAbsent) {
    return DocsCompanion(
      collection: Value(collection),
      id: Value(id),
      json: Value(json),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
    );
  }

  factory Doc.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Doc(
      collection: serializer.fromJson<String>(json['collection']),
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  Doc copyWith({
    String? collection,
    String? id,
    String? json,
    int? updatedAt,
    bool? deleted,
    bool? dirty,
  }) => Doc(
    collection: collection ?? this.collection,
    id: id ?? this.id,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
  );
  Doc copyWithCompanion(DocsCompanion data) {
    return Doc(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Doc(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(collection, id, json, updatedAt, deleted, dirty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Doc &&
          other.collection == this.collection &&
          other.id == this.id &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty);
}

class DocsCompanion extends UpdateCompanion<Doc> {
  final Value<String> collection;
  final Value<String> id;
  final Value<String> json;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int> rowid;
  const DocsCompanion({
    this.collection = const Value.absent(),
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocsCompanion.insert({
    required String collection,
    required String id,
    required String json,
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       id = Value(id),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<Doc> custom({
    Expression<String>? collection,
    Expression<String>? id,
    Expression<String>? json,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocsCompanion copyWith({
    Value<String>? collection,
    Value<String>? id,
    Value<String>? json,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return DocsCompanion(
      collection: collection ?? this.collection,
      id: id ?? this.id,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocsCompanion(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocsTable docs = $DocsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [docs];
}

typedef $$DocsTableCreateCompanionBuilder =
    DocsCompanion Function({
      required String collection,
      required String id,
      required String json,
      required int updatedAt,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$DocsTableUpdateCompanionBuilder =
    DocsCompanion Function({
      Value<String> collection,
      Value<String> id,
      Value<String> json,
      Value<int> updatedAt,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$DocsTableFilterComposer extends Composer<_$AppDatabase, $DocsTable> {
  $$DocsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocsTableOrderingComposer extends Composer<_$AppDatabase, $DocsTable> {
  $$DocsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocsTable> {
  $$DocsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$DocsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocsTable,
          Doc,
          $$DocsTableFilterComposer,
          $$DocsTableOrderingComposer,
          $$DocsTableAnnotationComposer,
          $$DocsTableCreateCompanionBuilder,
          $$DocsTableUpdateCompanionBuilder,
          (Doc, BaseReferences<_$AppDatabase, $DocsTable, Doc>),
          Doc,
          PrefetchHooks Function()
        > {
  $$DocsTableTableManager(_$AppDatabase db, $DocsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocsCompanion(
                collection: collection,
                id: id,
                json: json,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String id,
                required String json,
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocsCompanion.insert(
                collection: collection,
                id: id,
                json: json,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocsTable, Doc>(table),
                  BaseReferences<_$AppDatabase, $DocsTable, Doc>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocsTable,
      Doc,
      $$DocsTableFilterComposer,
      $$DocsTableOrderingComposer,
      $$DocsTableAnnotationComposer,
      $$DocsTableCreateCompanionBuilder,
      $$DocsTableUpdateCompanionBuilder,
      (Doc, BaseReferences<_$AppDatabase, $DocsTable, Doc>),
      Doc,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocsTableTableManager get docs => $$DocsTableTableManager(_db, _db.docs);
}
