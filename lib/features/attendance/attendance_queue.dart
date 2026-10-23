import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/db/app_database.dart';
import '../../core/db/meta_db.dart';
import '../../core/sync/sync_controller.dart';
import '../auth/auth_providers.dart';
import 'attendance_models.dart';

final attendanceQueueProvider = Provider<AttendanceQueue>(
  (ref) => AttendanceQueue(ref),
);

final queueItemsProvider = StreamProvider<List<QueueItem>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchMetaPrefix('attq_')
      .map(
        (rows) => [
          for (final r in rows)
            QueueItem.fromJson(jsonDecode(r.json) as Map<String, dynamic>),
        ]..sort((a, b) => a.clientTime.compareTo(b.clientTime)),
      ),
);

final attendanceMeProvider =
    AsyncNotifierProvider<AttendanceMeNotifier, MeData?>(
      AttendanceMeNotifier.new,
    );

/// Status absensi saya (dari server, dengan cadangan lokal agar tetap tampil offline).
class AttendanceMeNotifier extends AsyncNotifier<MeData?> {
  String? get _uid => ref.read(sessionProvider).value?.user.uid;

  @override
  Future<MeData?> build() async {
    ref.watch(activeOutletIdProvider);
    final uid = _uid;
    MeData? cached;
    if (uid != null) {
      final m = await ref.read(databaseProvider).getMeta('attme_$uid');
      if (m != null) cached = MeData.fromJson(m);
    }
    Future.microtask(refresh);
    return cached;
  }

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final data =
          await ref.read(apiClientProvider).get('/attendance/me')
              as Map<String, dynamic>;
      await ref.read(databaseProvider).putMeta('attme_$uid', data);
      state = AsyncData(MeData.fromJson(data));
    } catch (_) {
      // offline atau sesi habis: tetap pakai data cadangan
    }
  }
}

class AttendanceQueue {
  AttendanceQueue(this._ref);
  final Ref _ref;
  bool _flushing = false;

  AppDatabase get _db => _ref.read(databaseProvider);

  Future<void> _put(QueueItem q) => _db.upsert(
    DocsCompanion(
      collection: const Value('device_settings'),
      id: Value('attq_${q.eventId}'),
      json: Value(jsonEncode(q.toJson())),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      deleted: const Value(false),
      dirty: const Value(false),
    ),
  );

  Future<void> enqueue(QueueItem q) => _put(q);

  Future<void> dismiss(String eventId) =>
      _db.purge('device_settings', 'attq_$eventId');

  /// Kirim antrean berurutan. Kembalikan jumlah yang berhasil terkirim.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final rows = await _db.metaPrefixRows('attq_');
      final items =
          [
              for (final r in rows)
                QueueItem.fromJson(jsonDecode(r.json) as Map<String, dynamic>),
            ].where((q) => q.status == 'pending').toList()
            ..sort((a, b) => a.clientTime.compareTo(b.clientTime));
      for (final q in items) {
        try {
          final bytes = base64Decode(q.photoB64);
          await _ref
              .read(apiClientProvider)
              .request(
                'POST',
                '/attendance/clock',
                dataBuilder: () => FormData.fromMap({
                  'event_id': q.eventId,
                  'kind': q.kind,
                  'client_time': q.clientTime,
                  'lat': q.lat,
                  'lng': q.lng,
                  'accuracy_m': q.accuracy,
                  'mocked': q.mocked,
                  'liveness_ok': q.liveness,
                  'photo': MultipartFile.fromBytes(
                    bytes,
                    filename: 'selfie.jpg',
                  ),
                }),
              );
          await dismiss(q.eventId);
          sent++;
        } on ApiException catch (e) {
          final code = e.status ?? 0;
          if (code == 401 || code >= 500) break; // coba lagi nanti
          await _put(
            q.copyWith(status: 'rejected', error: e.message),
          ); // ditolak server
        } on DioException {
          break; // offline
        }
      }
    } catch (_) {
      // abaikan; siklus sinkron berikutnya mencoba lagi
    } finally {
      _flushing = false;
    }
    if (sent > 0) _ref.read(attendanceMeProvider.notifier).refresh();
    return sent;
  }
}
