import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/config/app_config.dart';
import '../../core/db/meta_db.dart';
import '../auth/auth_providers.dart';
import 'client_models.dart';

const _kMetaKey = 'client';

/// ID acak per instalasi aplikasi. Sengaja TIDAK dihapus saat keluar dari akun restoran,
/// supaya aktivasi ulang di perangkat yang sama tidak menghabiskan jatah perangkat.
const _kInstallKey = 'install_id';
const _kDayMs = 24 * 3600 * 1000;

int _now() => DateTime.now().millisecondsSinceEpoch;

String clientPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    _ => 'linux',
  };
}

/// Alasan aplikasi dikunci ke layar "Hubungi CS".
BlockReason blockReasonOf(ClientState c, {int? now}) {
  final local = now ?? _now();
  final sub = c.info.subscription;
  if (sub.suspended) return BlockReason.suspended;
  if (c.blockedByServer || !sub.allowed) return BlockReason.expired;
  // perkiraan jam server dari selisih jam saat status terakhir dicek
  final offset = sub.serverTime - c.checkedAt;
  if (local + offset > sub.graceUntil) return BlockReason.expired;
  if (local - c.checkedAt > kOfflineGraceDays * _kDayMs) {
    return BlockReason.offlineTooLong;
  }
  return BlockReason.none;
}

Dio _dio(String base) => Dio(
  BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
    validateStatus: (_) => true,
  ),
);

/// Perangkat teraktivasi untuk satu klien (login tahap pertama).
class ClientNotifier extends AsyncNotifier<ClientState?> {
  bool _refreshing = false;

  @override
  Future<ClientState?> build() async {
    final meta = ref.read(metaDbProvider);
    final m = await meta.getMeta(_kMetaKey);
    if (m == null) return null;
    if (m['base_url'] != normalizeBaseUrl(kApiUrl)) {
      // kApiUrl diganti (lokal <-> produksi): token perangkat & sesi milik server lama
      await meta.removeMeta(_kMetaKey);
      await meta.removeMeta('session');
      await meta.removeMeta('active_outlet');
      return null;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300), refreshStatus),
    );
    return ClientState.fromJson(m);
  }

  Future<String> _installId() async {
    final meta = ref.read(metaDbProvider);
    final m = await meta.getMeta(_kInstallKey);
    final cur = m?['id'] as String?;
    if (cur != null && cur.isNotEmpty) return cur;
    final id = const Uuid().v4().replaceAll('-', '');
    await meta.putMeta(_kInstallKey, {'id': id});
    return id;
  }

  Future<void> _save(ClientState c) async {
    await ref.read(metaDbProvider).putMeta(_kMetaKey, c.toJson());
    state = AsyncData(c);
  }

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException {
      throw ApiException(
        null,
        'Tidak bisa terhubung ke server. Periksa jaringan lalu coba lagi.',
      );
    }
  }

  /// Email + password klien. Berhasil walau langganan habis: gerbang aplikasi lalu
  /// menampilkan layar langganan untuk memasukkan kode aktivasi.
  Future<void> activate({
    required String baseUrl,
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final base = normalizeBaseUrl(baseUrl);
    final installId = await _installId();
    final res = await _send(
      () => _dio(base).post<dynamic>(
        '/client/activate',
        data: {
          'email': email.trim(),
          'password': password,
          'device_name': deviceName.trim(),
          'platform': clientPlatform(),
          'install_id': installId,
        },
      ),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, apiDetail(res.data, res.statusCode));
    }
    final m = Map<String, dynamic>.from(res.data as Map);
    final c = ClientState(
      baseUrl: base,
      deviceId: m['device_id'] as String,
      deviceToken: m['device_token'] as String,
      info: ClientInfo.fromJson(Map<String, dynamic>.from(m['client'] as Map)),
      checkedAt: _now(),
    );
    final meta = ref.read(metaDbProvider);
    final old = state.value;
    final prevSession = ref.read(sessionProvider).value;
    if (prevSession != null && prevSession.baseUrl != base) {
      // sesi milik server lain (mis. kApiUrl baru diganti lokal <-> produksi)
      await ref.read(sessionProvider.notifier).expire();
      await meta.removeMeta('active_outlet');
      ref.invalidate(ownerOutletProvider);
    }
    if (old != null && (old.info.code != c.info.code || old.baseUrl != base)) {
      // klien lain di perangkat ini: sesi dan outlet pilihan lama tidak berlaku
      await ref.read(sessionProvider.notifier).expire();
      await meta.removeMeta('active_outlet');
      ref.invalidate(ownerOutletProvider);
    }
    await meta.putMeta('server_url', {'url': base});
    await _save(c);
    await _dropForeignSession(c.info.code);
  }

  /// Sesi lama (sebelum aktivasi) harus milik klien yang sama.
  Future<void> _dropForeignSession(String code) async {
    if (ref.read(sessionProvider).value == null) return;
    try {
      final me =
          await ref.read(apiClientProvider).get('/auth/me')
              as Map<String, dynamic>;
      final serverCode = (me['client'] as Map?)?['code'];
      if (serverCode != null && serverCode != code) {
        await ref.read(sessionProvider.notifier).expire();
        await ref.read(metaDbProvider).removeMeta('active_outlet');
        ref.invalidate(ownerOutletProvider);
      }
    } catch (_) {
      // offline: diperiksa lagi oleh server saat request berikutnya
    }
  }

  /// Ambil status langganan terbaru. Offline = pakai status terakhir.
  Future<void> refreshStatus() async {
    final c = state.value;
    if (c == null || _refreshing) return;
    _refreshing = true;
    try {
      final res = await _dio(c.baseUrl).get<dynamic>(
        '/client/status',
        options: Options(headers: {'X-Device-Token': c.deviceToken}),
      );
      if (res.statusCode == 200) {
        final cur = state.value ?? c;
        await _save(
          cur.copyWith(
            info: ClientInfo.fromJson(Map<String, dynamic>.from(res.data as Map)),
            checkedAt: _now(),
            blockedByServer: false,
          ),
        );
      } else if (res.statusCode == 401) {
        await forget(notifyServer: false); // perangkat dicabut CS
      }
    } catch (_) {
      // offline
    } finally {
      _refreshing = false;
    }
  }

  /// Dipanggil saat API RMS menjawab 402.
  Future<void> onPaymentRequired() async {
    final c = state.value;
    if (c == null) return;
    if (!c.blockedByServer) await _save(c.copyWith(blockedByServer: true));
    unawaited(refreshStatus());
  }

  /// Perpanjangan dengan kode aktivasi dari CS. Mengembalikan status terbaru.
  /// [apply] = false: status belum disimpan (mis. tampilkan dialog sukses dulu sebelum
  /// gerbang aplikasi berpindah ke halaman login), simpan nanti dengan [applyInfo].
  Future<ClientInfo> redeem(String coupon, {bool apply = true}) async {
    final c = state.value;
    if (c == null) throw ApiException(null, 'Perangkat belum diaktivasi');
    final res = await _send(
      () => _dio(c.baseUrl).post<dynamic>(
        '/client/redeem',
        data: {'coupon': coupon.trim()},
        options: Options(headers: {'X-Device-Token': c.deviceToken}),
      ),
    );
    if (res.statusCode == 401) {
      await forget(notifyServer: false);
      throw ApiException(401, 'Perangkat ini sudah dicabut. Aktivasi ulang.');
    }
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, apiDetail(res.data, res.statusCode));
    }
    final info = ClientInfo.fromJson(Map<String, dynamic>.from(res.data as Map));
    if (apply) await applyInfo(info);
    return info;
  }

  Future<void> applyInfo(ClientInfo info) async {
    final c = state.value;
    if (c == null) return;
    await _save(c.copyWith(info: info, checkedAt: _now(), blockedByServer: false));
  }

  /// Keluar dari akun klien di perangkat ini (sesi RMS ikut keluar).
  /// [notifyServer]: beri tahu server agar perangkat ini tidak aktif lagi (jatah perangkat
  /// kembali). Tidak perlu bila server sudah menolak token perangkat (401).
  Future<void> forget({bool notifyServer = true}) async {
    try {
      await ref.read(sessionProvider.notifier).logout();
    } catch (_) {}
    final c = state.value;
    if (notifyServer && c != null) {
      try {
        await Dio(
          BaseOptions(
            baseUrl: c.baseUrl,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
            validateStatus: (_) => true,
          ),
        ).post<dynamic>(
          '/client/deactivate',
          options: Options(headers: {'X-Device-Token': c.deviceToken}),
        );
      } catch (_) {
        // offline: perangkat tetap tercatat aktif sampai dicabut CS / aktivasi ulang di sini
      }
    }
    final meta = ref.read(metaDbProvider);
    await meta.removeMeta(_kMetaKey);
    await meta.removeMeta('active_outlet');
    ref.invalidate(ownerOutletProvider);
    state = const AsyncData(null);
  }
}

final clientProvider = AsyncNotifierProvider<ClientNotifier, ClientState?>(
  ClientNotifier.new,
);

final clientBlockProvider = Provider<BlockReason>((ref) {
  final c = ref.watch(clientProvider).value;
  return c == null ? BlockReason.none : blockReasonOf(c);
});

/// Modul sewaan klien aktif? (Super Admin → Modul). Belum aktivasi / data lama = aktif.
final moduleEnabledProvider = Provider.family<bool, String>((ref, key) {
  final c = ref.watch(clientProvider).value;
  return c == null || c.info.hasModule(key);
});
