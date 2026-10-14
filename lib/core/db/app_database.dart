import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show listEquals;

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
  AppDatabase([String name = 'rms']) : super(driftDatabase(name: name));

  Stream<int> watchDirtyCount() => customSelect(
    'SELECT COUNT(*) AS c FROM docs WHERE dirty = 1',
    readsFrom: {docs},
  ).watch().map((r) => r.first.data['c'] as int).distinct();

  @override
  int get schemaVersion => 1;

  Stream<List<Doc>> watchCollection(String c) =>
      (select(docs)
            ..where((t) => t.collection.equals(c) & t.deleted.equals(false)))
          .watch()
          .distinct(listEquals);

  Future<Doc?> find(String c, String id) => (select(
    docs,
  )..where((t) => t.collection.equals(c) & t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(DocsCompanion d) => into(docs).insertOnConflictUpdate(d);

  Future<List<Doc>> dirtyDocs() =>
      (select(docs)..where((t) => t.dirty.equals(true))).get();

  /// Hanya bersihkan flag jika dokumen belum berubah lagi sejak dikirim.
  Future<void> markClean(String c, String id, int updatedAt) =>
      (update(docs)..where(
            (t) =>
                t.collection.equals(c) &
                t.id.equals(id) &
                t.updatedAt.equals(updatedAt),
          ))
          .write(const DocsCompanion(dirty: Value(false)));

  Future<void> purge(String c, String id) => (delete(
    docs,
  )..where((t) => t.collection.equals(c) & t.id.equals(id))).go();

  // ---- query SQL untuk ledger stok (tanpa memuat semua baris ke memori) ----
  static const _ing = r"json_extract(json, '$.ingredientId')";
  static const _qty = r"json_extract(json, '$.qty')";
  static const _type = r"json_extract(json, '$.type')";
  static const _cost = r"json_extract(json, '$.unitCost')";
  static const _at = r"json_extract(json, '$.at')";
  static const _isPurchase =
      "($_type = 'purchase' AND $_cost IS NOT NULL AND $_qty > 0)";
  static const _stockAggSql =
      "SELECT $_ing AS ing, SUM($_qty) AS total, "
      "SUM(CASE WHEN $_isPurchase THEN $_qty ELSE 0 END) AS pqty, "
      "SUM(CASE WHEN $_isPurchase THEN $_qty * $_cost ELSE 0 END) AS pcost "
      "FROM docs WHERE collection = 'stock_moves' AND deleted = 0 GROUP BY ing";

  /// Berubah hanya jika jumlah/waktu mutasi stok berubah.
  Stream<int> watchStockVersion() =>
      customSelect(
            "SELECT COUNT(*) AS c, COALESCE(MAX(updated_at), 0) AS m "
            "FROM docs WHERE collection = 'stock_moves'",
            readsFrom: {docs},
          )
          .watch()
          .map(
            (rows) => Object.hash(rows.first.data['c'], rows.first.data['m']),
          )
          .distinct();

  /// Total per bahan: stok, qty pembelian, dan nilai pembelian.
  Stream<List<QueryRow>> watchStockAgg() => watchStockVersion().asyncMap(
    (_) => customSelect(_stockAggSql, readsFrom: {docs}).get(),
  );

  Future<List<Doc>> stockMoveRows({
    String? ingredientId,
    int? start,
    int? end,
    int? limit,
  }) {
    final where = <String>["collection = 'stock_moves'", 'deleted = 0'];
    final args = <Variable>[];
    if (ingredientId != null) {
      where.add('$_ing = ?');
      args.add(Variable.withString(ingredientId));
    }
    if (start != null) {
      where.add('$_at >= ?');
      args.add(Variable.withInt(start));
    }
    if (end != null) {
      where.add('$_at < ?');
      args.add(Variable.withInt(end));
    }
    final sql =
        'SELECT * FROM docs WHERE ${where.join(' AND ')} '
        'ORDER BY $_at DESC${limit == null ? '' : ' LIMIT $limit'}';
    return customSelect(
      sql,
      variables: args,
      readsFrom: {docs},
    ).map((r) => docs.map(r.data)).get();
  }

  Future<bool> ingredientHasMoves(String id) async {
    final r = await customSelect(
      "SELECT 1 AS x FROM docs WHERE collection = 'stock_moves' "
      "AND deleted = 0 AND $_ing = ? LIMIT 1",
      variables: [Variable.withString(id)],
      readsFrom: {docs},
    ).get();
    return r.isNotEmpty;
  }

  /// Hapus salinan lokal yang sudah tersinkron dan lebih lama dari [cutoffMs],
  /// kecuali berstatus 'open'. Data di Firestore tidak tersentuh.
  Future<int> pruneOlderThan(String collection, int cutoffMs) => customUpdate(
    "DELETE FROM docs WHERE collection = ? AND dirty = 0 "
    "AND updated_at < ? AND json_extract(json, '\$.status') IS NOT 'open'",
    variables: [Variable.withString(collection), Variable.withInt(cutoffMs)],
    updates: {docs},
    updateKind: UpdateKind.delete,
  );
}
