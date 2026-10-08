import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'sync_controller.dart';

/// Basis repository: tulis ke Drift (dirty) -> sync ke Firestore saat online.
/// UI selalu membaca dari Drift, jadi jalan normal saat offline.
abstract class LocalFirstRepository<T> {
  LocalFirstRepository(this.ref);
  final Ref ref;

  String get collection;
  T fromMap(Map<String, dynamic> m);
  Map<String, dynamic> toMap(T item);
  String idOf(T item);

  AppDatabase get _db => ref.read(databaseProvider);

  Stream<List<T>> watchAll() => _db.watchCollection(collection).map((rows) =>
      rows
          .map((r) => fromMap(jsonDecode(r.json) as Map<String, dynamic>))
          .toList());

  Future<void> save(T item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {...toMap(item), 'updatedAt': now};
    await _db.upsert(DocsCompanion(
      collection: Value(collection),
      id: Value(idOf(item)),
      json: Value(jsonEncode(data)),
      updatedAt: Value(now),
      deleted: const Value(false),
      dirty: const Value(true),
    ));
    ref.read(syncControllerProvider.notifier).pushPending();
  }

  Future<void> remove(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.find(collection, id);
    await _db.upsert(DocsCompanion(
      collection: Value(collection),
      id: Value(id),
      json: Value(existing?.json ?? '{}'),
      updatedAt: Value(now),
      deleted: const Value(true),
      dirty: const Value(true),
    ));
    ref.read(syncControllerProvider.notifier).pushPending();
  }
}
