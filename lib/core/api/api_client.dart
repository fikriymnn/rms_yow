import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import 'api_exception.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));

enum _Refresh { ok, rejected, unreachable }

class ApiClient {
  ApiClient(this._ref);
  final Ref _ref;
  Dio? _dio;
  String? _dioBase;
  Completer<_Refresh>? _refreshing;

  Dio _dioFor(String base) {
    if (_dio == null || _dioBase != base) {
      _dioBase = base;
      _dio = Dio(
        BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (_) => true, // status error ditangani manual
        ),
      );
    }
    return _dio!;
  }

  Session _session() {
    final s = _ref.read(sessionProvider).value;
    if (s == null) throw ApiException(401, 'Belum login');
    return s;
  }

  Future<Response<dynamic>> _call(
    Session s,
    String method,
    String path,
    Map<String, dynamic>? query,
    Object? data,
  ) => _dioFor(s.baseUrl).request<dynamic>(
    path,
    queryParameters: query,
    data: data,
    options: Options(
      method: method,
      headers: {'Authorization': 'Bearer ${s.accessToken}'},
    ),
  );

  /// Jaringan putus -> DioException (dianggap offline). Status >= 400 -> ApiException.
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
  }) async {
    var s = _session();
    var res = await _call(s, method, path, query, data);
    if (res.statusCode == 401) {
      final r = await _refresh();
      if (r == _Refresh.unreachable) {
        throw DioException(
          requestOptions: res.requestOptions,
          type: DioExceptionType.connectionError,
        );
      }
      if (r == _Refresh.rejected) {
        throw ApiException(401, 'Sesi berakhir, silakan login ulang');
      }
      s = _session();
      res = await _call(s, method, path, query, data);
    }
    final code = res.statusCode ?? 0;
    if (code >= 400) throw ApiException(code, apiDetail(res.data, code));
    return res.data;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, {Object? data}) =>
      request('POST', path, data: data);

  Future<_Refresh> _refresh() {
    final running = _refreshing;
    if (running != null) return running.future;
    final c = _refreshing = Completer<_Refresh>();
    () async {
      try {
        final s = _session();
        final res = await _dioFor(s.baseUrl).post<dynamic>(
          '/auth/refresh',
          data: {'refresh_token': s.refreshToken},
        );
        if (res.statusCode == 200) {
          final token = (res.data as Map)['access_token'] as String;
          await _ref.read(sessionProvider.notifier).updateAccessToken(token);
          c.complete(_Refresh.ok);
        } else if (res.statusCode == 401) {
          await _ref
              .read(sessionProvider.notifier)
              .expire(); // refresh token ditolak
          c.complete(_Refresh.rejected);
        } else {
          c.complete(_Refresh.unreachable);
        }
      } catch (_) {
        c.complete(_Refresh.unreachable); // offline: jangan keluarkan pengguna
      } finally {
        _refreshing = null;
      }
    }();
    return c.future;
  }
}
