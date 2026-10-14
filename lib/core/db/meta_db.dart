import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

final metaDbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase('rms_meta');
  ref.onDispose(db.close);
  return db;
});

extension MetaStore on AppDatabase {
  Future<Map<String, dynamic>?> getMeta(String id) async {
    final row = await find('device_settings', id);
    if (row == null) return null;
    return jsonDecode(row.json) as Map<String, dynamic>;
  }

  Future<void> putMeta(String id, Map<String, dynamic> json) => upsert(
    DocsCompanion(
      collection: const Value('device_settings'),
      id: Value(id),
      json: Value(jsonEncode(json)),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      deleted: const Value(false),
      dirty: const Value(false),
    ),
  );

  Future<void> removeMeta(String id) => purge('device_settings', id);
}
