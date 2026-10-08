import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Satu tabel generik untuk semua koleksi Firestore.
/// `dirty = true` artinya belum terkirim ke Firestore (antrian sync).
class Docs extends Table {
  TextColumn get collection => text()();
  TextColumn get id => text()();
  TextColumn get json => text()();
  IntColumn get updatedAt => integer()(); // epoch millis
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {collection, id};
}

@DriftDatabase(tables: [Docs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'rms'));

  @override
  int get schemaVersion => 1;

  Stream<List<Doc>> watchCollection(String c) => (select(docs)
        ..where((t) => t.collection.equals(c) & t.deleted.equals(false)))
      .watch();

  Future<Doc?> find(String c, String id) =>
      (select(docs)..where((t) => t.collection.equals(c) & t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsert(DocsCompanion d) => into(docs).insertOnConflictUpdate(d);

  Future<List<Doc>> dirtyDocs() =>
      (select(docs)..where((t) => t.dirty.equals(true))).get();

  /// Hanya bersihkan flag jika dokumen belum berubah lagi sejak dikirim.
  Future<void> markClean(String c, String id, int updatedAt) =>
      (update(docs)
            ..where((t) =>
                t.collection.equals(c) &
                t.id.equals(id) &
                t.updatedAt.equals(updatedAt)))
          .write(const DocsCompanion(dirty: Value(false)));

  Future<void> purge(String c, String id) => (delete(docs)
        ..where((t) => t.collection.equals(c) & t.id.equals(id)))
      .go();
}
