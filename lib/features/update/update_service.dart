import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/db/meta_db.dart';
import '../auth/auth_providers.dart';
import '../client/client_providers.dart';
import 'update_models.dart';

/// Versi aplikasi yang sedang berjalan: build = versionCode (angka setelah + di pubspec).
final appVersionProvider = FutureProvider<({String name, int build})>((
  ref,
) async {
  final p = await PackageInfo.fromPlatform();
  return (name: p.version, build: int.tryParse(p.buildNumber) ?? 0);
});

bool get _isAndroidApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Alamat server: dari perangkat klien, sesi, server yang terakhir dipakai, atau bawaan aplikasi.
Future<String?> _serverUrl(Ref ref) async {
  final c = ref.read(clientProvider).value;
  if (c != null) return c.baseUrl;
  final s = ref.read(sessionProvider).value;
  if (s != null) return s.baseUrl;
  final m = await ref.read(metaDbProvider).getMeta('server_url');
  final saved = m?['url'] as String?;
  // belum pernah login (baru dipasang): pakai server bawaan aplikasi
  return (saved == null || saved.isEmpty) ? normalizeBaseUrl(kApiUrl) : saved;
}

Future<UpdateInfo?> _fetch(String baseUrl, String channel) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (_) => true,
    ),
  );
  final res = await dio.get<dynamic>(
    '/app/latest',
    queryParameters: {'channel': channel},
  );
  if (res.statusCode != 200 || res.data is! Map) return null;
  return UpdateInfo.fromJson(
    Map<String, dynamic>.from(res.data as Map),
    baseUrl,
  );
}

/// Pemeriksaan langsung ke server. Melempar bila server tidak terjangkau
/// (dipakai tombol "Cek pembaruan" agar bisa menampilkan pesan yang jelas).
final updateCheckerProvider = Provider<Future<UpdateInfo?> Function()>(
  (ref) => () async {
    if (!_isAndroidApp) return null;
    final url = await _serverUrl(ref);
    if (url == null) return null;
    final channel = ref.read(clientProvider).value?.info.releaseChannel;
    return _fetch(url, channel ?? 'stable');
  },
);

/// Hasil pemeriksaan otomatis. Offline atau gagal = tidak ada pembaruan (diam-diam).
final latestUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  try {
    return await ref.read(updateCheckerProvider)();
  } catch (_) {
    return null;
  }
});

/// Pembaruan yang WAJIB (build di bawah min_build); null bila tidak ada.
final mandatoryUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final info = await ref.watch(latestUpdateProvider.future);
  final v = await ref.watch(appVersionProvider.future);
  return info != null && info.isMandatoryFor(v.build) ? info : null;
});
