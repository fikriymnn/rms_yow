import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../data_window.dart';
import '../db/app_database.dart';

/// Satu database lokal per outlet (data tiap outlet tidak bercampur di perangkat).
final databaseProvider = Provider<AppDatabase>((ref) {
  final outlet = ref.watch(activeOutletIdProvider);
  final db = AppDatabase('rms_${outlet ?? 'none'}');
  ref.onDispose(db.close);
  return db;
});

final pendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchDirtyCount(),
);

enum SyncState { idle, syncing, offline, error }

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  Timer? _timer;
  StreamSubscription? _connSub;
  bool _busy = false;
  bool _again = false;
  final _skipped = <String>{};
  final rejected = <String>[]; // "koleksi/id: alasan" (ditolak server)

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  SyncState build() {
    ref.watch(
      activeOutletIdProvider,
    ); // ganti outlet/keluar -> sinkron lama berhenti
    ref.onDispose(() {
      _timer?.cancel();
      _connSub?.cancel();
    });
    return SyncState.idle;
  }

  Future<void> start() async {
    await stop();
    final db = ref.read(databaseProvider);
    for (final e in kWindowDays.entries) {
      final cut = DateTime.now()
          .subtract(Duration(days: e.value))
          .millisecondsSinceEpoch;
      await db.pruneOlderThan(e.key, cut);
    }
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      if (r.contains(ConnectivityResult.none)) {
        state = SyncState.offline;
      } else {
        syncNow();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => syncNow());
    await syncNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _connSub?.cancel();
    _connSub = null;
  }

  /// Kirim perubahan lokal, lalu ambil perubahan baru dari server.
  Future<void> syncNow() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final db = ref.read(databaseProvider);
        final outlet = ref.read(activeOutletIdProvider);
        if (outlet == null) return;
        final staleSeq = await _push(db, outlet);
        await _pull(db, outlet);
        if (staleSeq != null) {
          await _pull(db, outlet, from: staleSeq - 1, saveCursor: false);
        }
        state = SyncState.idle;
      } while (_again);
    } on DioException {
      state = SyncState.offline;
    } on ApiException {
      state = SyncState.error;
    } catch (_) {
      state = SyncState.error;
    } finally {
      _busy = false;
    }
  }

  /// Return: seq terkecil dari dokumen "stale" (perlu diambil ulang dari server).
  Future<int?> _push(AppDatabase db, String outlet) async {
    final pending =
        (await db.dirtyDocs())
            .where((d) => !_skipped.contains('${d.collection}/${d.id}'))
            .toList()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    if (pending.isEmpty) return null;
    state = SyncState.syncing;
    int? minStale;
    for (var i = 0; i < pending.length; i += 100) {
      final batch = pending.sublist(i, min(i + 100, pending.length));
      final res =
          await _api.post(
                '/sync/push',
                data: {
                  'outlet_id': outlet,
                  'docs': [
                    for (final d in batch)
                      {
                        'collection': d.collection,
                        'id': d.id,
                        'data': jsonDecode(d.json),
                        'updated_at': d.updatedAt,
                        'deleted': d.deleted,
                      },
                  ],
                },
              )
              as Map<String, dynamic>;
      final results = (res['results'] as List).cast<Map<String, dynamic>>();
      for (var k = 0; k < results.length; k++) {
        final r = results[k];
        final d = batch[k];
        switch (r['status']) {
          case 'ok':
            await db.markClean(d.collection, d.id, d.updatedAt);
          case 'stale': // server sudah punya versi sama/lebih baru
            await db.markClean(d.collection, d.id, d.updatedAt);
            final s = (r['seq'] as num?)?.toInt();
            if (s != null) minStale = minStale == null ? s : min(minStale, s);
          default: // rejected
            _skipped.add('${d.collection}/${d.id}');
            rejected.add('${d.collection}/${d.id}: ${r['reason']}');
        }
      }
    }
    return minStale;
  }

  Future<void> _pull(
    AppDatabase db,
    String outlet, {
    int? from,
    bool saveCursor = true,
  }) async {
    final role = ref.read(appUserProvider).value?.role.name;
    var since = from ?? await _loadCursor(db, role);
    while (true) {
      final res =
          await _api.get(
                '/sync/pull',
                query: {'since': since, 'limit': 500, 'outlet_id': outlet},
              )
              as Map<String, dynamic>;
      await _apply(db, (res['docs'] as List).cast<Map<String, dynamic>>());
      since = (res['next_since'] as num).toInt();
      if (saveCursor) await _saveCursor(db, since, role);
      if (res['has_more'] != true) break;
    }
  }

  Future<void> _apply(AppDatabase db, List<Map<String, dynamic>> docs) async {
    if (docs.isEmpty) return;
    await db.transaction(() async {
      for (final m in docs) {
        final c = m['collection'] as String;
        final id = m['id'] as String;
        final ts = (m['updated_at'] as num).toInt();
        final local = await db.find(c, id);
        // perubahan lokal yang lebih baru dan belum terkirim tidak ditimpa
        if (local != null && local.dirty && local.updatedAt > ts) continue;
        await db.upsert(
          DocsCompanion(
            collection: Value(c),
            id: Value(id),
            json: Value(jsonEncode(m['data'])),
            updatedAt: Value(ts),
            deleted: Value(m['deleted'] == true),
            dirty: const Value(false),
          ),
        );
      }
    });
  }

  // kursor disimpan di database outlet; berubah role -> unduh ulang dari awal
  Future<int> _loadCursor(AppDatabase db, String? role) async {
    final row = await db.find('device_settings', 'cursor');
    if (row == null) return 0;
    final m = jsonDecode(row.json) as Map<String, dynamic>;
    if (m['role'] != role) return 0;
    return (m['since'] as num?)?.toInt() ?? 0;
  }

  Future<void> _saveCursor(AppDatabase db, int since, String? role) =>
      db.upsert(
        DocsCompanion(
          collection: const Value('device_settings'),
          id: const Value('cursor'),
          json: Value(jsonEncode({'since': since, 'role': role})),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          deleted: const Value(false),
          dirty: const Value(false),
        ),
      );
}
