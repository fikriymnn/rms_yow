import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/db/meta_db.dart';

enum AppRole { owner, manager, cashier, waiter, kitchen, warehouse }

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    this.username = '',
    this.outletId,
  });
  final String uid;
  final String name;
  final AppRole role;
  final String username;
  final String? outletId;

  bool get canManageMenu => role == AppRole.owner || role == AppRole.manager;
  bool get canPay =>
      role == AppRole.owner ||
      role == AppRole.manager ||
      role == AppRole.cashier;
  bool get isManager => role == AppRole.owner || role == AppRole.manager;

  factory AppUser.fromJson(Map<String, dynamic> m) => AppUser(
    uid: m['id'] as String,
    username: m['username'] as String? ?? '',
    name: m['name'] as String? ?? '-',
    role: AppRole.values.firstWhere(
      (r) => r.name == m['role'],
      orElse: () => AppRole.waiter,
    ),
    outletId: m['outlet_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': uid,
    'username': username,
    'name': name,
    'role': role.name,
    'outlet_id': outletId,
  };
}

class OutletInfo {
  const OutletInfo({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.radiusM = 100,
  });
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final int radiusM;

  factory OutletInfo.fromJson(Map<String, dynamic> m) => OutletInfo(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    radiusM: (m['radius_m'] as num?)?.toInt() ?? 100,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'radius_m': radiusM,
  };
}

class Session {
  const Session({
    required this.baseUrl,
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.outlet,
  });
  final String baseUrl;
  final String accessToken;
  final String refreshToken;
  final AppUser user;
  final OutletInfo? outlet;

  Session withAccessToken(String t) => Session(
    baseUrl: baseUrl,
    accessToken: t,
    refreshToken: refreshToken,
    user: user,
    outlet: outlet,
  );

  factory Session.fromJson(Map<String, dynamic> m) => Session(
    baseUrl: m['baseUrl'] as String,
    accessToken: m['accessToken'] as String,
    refreshToken: m['refreshToken'] as String,
    user: AppUser.fromJson(m['user'] as Map<String, dynamic>),
    outlet: m['outlet'] == null
        ? null
        : OutletInfo.fromJson(m['outlet'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': user.toJson(),
    'outlet': outlet?.toJson(),
  };
}

String defaultServerUrl() =>
    kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

String normalizeBaseUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return defaultServerUrl();
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final m = await ref.read(metaDbProvider).getMeta('session');
    return m == null ? null : Session.fromJson(m);
  }

  Future<void> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final base = normalizeBaseUrl(baseUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final Response<dynamic> res;
    try {
      res = await dio.post<dynamic>(
        '/auth/login',
        data: {'username': username.trim(), 'password': password},
      );
    } on DioException {
      throw ApiException(
        null,
        'Tidak bisa terhubung ke server ($base). Periksa alamat dan jaringan.',
      );
    }
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, apiDetail(res.data, res.statusCode));
    }
    final m = res.data as Map<String, dynamic>;
    final session = Session(
      baseUrl: base,
      accessToken: m['access_token'] as String,
      refreshToken: m['refresh_token'] as String,
      user: AppUser.fromJson(m['user'] as Map<String, dynamic>),
      outlet: m['outlet'] == null
          ? null
          : OutletInfo.fromJson(m['outlet'] as Map<String, dynamic>),
    );
    final meta = ref.read(metaDbProvider);
    final old = await meta.getMeta('server_url');
    if (old?['url'] != base) {
      await meta.removeMeta(
        'active_outlet',
      ); // outlet pilihan milik server lain
      ref.invalidate(ownerOutletProvider);
    }
    await meta.putMeta('server_url', {'url': base});
    await meta.putMeta('session', session.toJson());
    state = AsyncData(session);
  }

  Future<void> updateAccessToken(String token) async {
    final s = state.value;
    if (s == null) return;
    final n = s.withAccessToken(token);
    await ref.read(metaDbProvider).putMeta('session', n.toJson());
    state = AsyncData(n);
  }

  /// Sesi dihapus. Data di database outlet TIDAK dihapus (yang belum terkirim tetap aman).
  Future<void> expire() async {
    await ref.read(metaDbProvider).removeMeta('session');
    state = const AsyncData(null);
  }

  Future<void> logout() async {
    final s = state.value;
    if (s != null) {
      try {
        await Dio(
          BaseOptions(
            baseUrl: s.baseUrl,
            connectTimeout: const Duration(seconds: 4),
            validateStatus: (_) => true,
          ),
        ).post<dynamic>(
          '/auth/logout',
          data: {'refresh_token': s.refreshToken},
        );
      } catch (_) {
        /* offline: tetap keluar */
      }
    }
    await expire();
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(
  SessionNotifier.new,
);

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final s = await ref.watch(sessionProvider.future);
  return s?.user;
});

/// Outlet pilihan owner (non-owner selalu outletnya sendiri).
class OwnerOutletNotifier extends AsyncNotifier<OutletInfo?> {
  @override
  Future<OutletInfo?> build() async {
    final m = await ref.read(metaDbProvider).getMeta('active_outlet');
    return m == null ? null : OutletInfo.fromJson(m);
  }

  Future<void> select(OutletInfo o) async {
    await ref.read(metaDbProvider).putMeta('active_outlet', o.toJson());
    state = AsyncData(o);
  }
}

final ownerOutletProvider =
    AsyncNotifierProvider<OwnerOutletNotifier, OutletInfo?>(
      OwnerOutletNotifier.new,
    );

final activeOutletProvider = Provider<OutletInfo?>((ref) {
  final s = ref.watch(sessionProvider).value;
  if (s == null) return null;
  if (s.user.role == AppRole.owner) return ref.watch(ownerOutletProvider).value;
  return s.outlet;
});

final activeOutletIdProvider = Provider<String?>(
  (ref) => ref.watch(activeOutletProvider)?.id,
);
