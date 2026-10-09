import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

enum SyncState { idle, syncing, offline, error }

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  final _fs = FirebaseFirestore.instance;
  final _remoteSubs = <StreamSubscription>[];
  StreamSubscription? _connSub;
  bool _pushing = false;
  bool _online = true;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  SyncState build() {
    ref.onDispose(stop);
    return SyncState.idle;
  }

  /// Panggil sekali setelah login. [collections] = koleksi yang di-mirror.
  Future<void> start(List<String> collections) async {
    await stop();
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      _online = !r.contains(ConnectivityResult.none);
      if (_online) {
        state = SyncState.idle;
        pushPending();
      } else {
        state = SyncState.offline;
      }
    });
    final r = await Connectivity().checkConnectivity();
    _online = !r.contains(ConnectivityResult.none);
    if (!_online) state = SyncState.offline;

    for (final c in collections) {
      _remoteSubs.add(
        _fs
            .collection(c)
            .snapshots()
            .listen(
              (snap) => _pull(c, snap),
              onError: (_) => state = SyncState.error,
            ),
      );
    }
    await pushPending();
  }

  Future<void> stop() async {
    await _connSub?.cancel();
    for (final s in _remoteSubs) {
      await s.cancel();
    }
    _remoteSubs.clear();
  }

  /// Kirim semua dokumen `dirty` ke Firestore (urut berdasarkan updatedAt).
  Future<void> pushPending() async {
    if (_pushing || !_online) return;
    _pushing = true;
    state = SyncState.syncing;
    try {
      final pending = await _db.dirtyDocs()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      var failed = false;
      for (final d in pending) {
        try {
          final docRef = _fs.collection(d.collection).doc(d.id);
          if (d.deleted) {
            await docRef.delete().timeout(const Duration(seconds: 15));
            await _db.purge(d.collection, d.id);
          } else {
            await docRef
                .set(
                  jsonDecode(d.json) as Map<String, dynamic>,
                  SetOptions(merge: true),
                )
                .timeout(const Duration(seconds: 15));
            await _db.markClean(d.collection, d.id, d.updatedAt);
          }
        } on TimeoutException {
          rethrow; // jaringan bermasalah, berhenti dan tandai offline
        } catch (_) {
          failed = true; // mis. ditolak rules: lanjut ke dokumen berikutnya
        }
      }
      state = failed ? SyncState.error : SyncState.idle;
    } on TimeoutException {
      state = SyncState.offline;
    } catch (_) {
      state = SyncState.error;
    } finally {
      _pushing = false;
    }
  }

  /// Tarik perubahan remote ke lokal. Last-write-wins via `updatedAt`.
  Future<void> _pull(String c, QuerySnapshot<Map<String, dynamic>> snap) async {
    for (final ch in snap.docChanges) {
      final local = await _db.find(c, ch.doc.id);
      if (local != null && local.dirty) continue; // perubahan lokal menang dulu
      if (ch.type == DocumentChangeType.removed) {
        await _db.purge(c, ch.doc.id);
        continue;
      }
      final data = ch.doc.data() ?? {};
      final remoteTs = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (local != null && local.updatedAt > remoteTs) continue;
      await _db.upsert(
        DocsCompanion(
          collection: Value(c),
          id: Value(ch.doc.id),
          json: Value(jsonEncode(data)),
          updatedAt: Value(remoteTs),
          deleted: const Value(false),
          dirty: const Value(false),
        ),
      );
    }
  }
}
