import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'role_models.dart';

/// Daftar fitur dan aksinya (sumber kebenarannya ada di server).
final roleCatalogProvider = FutureProvider.autoDispose<List<PermFeature>>((
  ref,
) async {
  final data =
      await ref.read(apiClientProvider).get('/roles/catalog') as List<dynamic>;
  return [
    for (final m in data) PermFeature.fromJson(m as Map<String, dynamic>),
  ];
});

final rolesProvider = FutureProvider.autoDispose<List<RoleInfo>>((ref) async {
  final data = await ref.read(apiClientProvider).get('/roles') as List<dynamic>;
  return [for (final m in data) RoleInfo.fromJson(m as Map<String, dynamic>)];
});

final roleRepositoryProvider = Provider<RoleRepository>(
  (ref) => RoleRepository(ref),
);

class RoleRepository {
  RoleRepository(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  void _refresh() => _ref.invalidate(rolesProvider);

  Future<void> create({
    required String key,
    required String name,
    required String description,
    required bool isStaff,
    required Set<String> permissions,
  }) async {
    await _api.post(
      '/roles',
      data: {
        'key': key,
        'name': name,
        'description': description,
        'is_staff': isStaff,
        'permissions': permissions.toList()..sort(),
      },
    );
    _refresh();
  }

  Future<void> update(
    String key, {
    required String name,
    required String description,
    required bool isStaff,
    required Set<String> permissions,
  }) async {
    await _api.request(
      'PATCH',
      '/roles/$key',
      data: {
        'name': name,
        'description': description,
        'is_staff': isStaff,
        'permissions': permissions.toList()..sort(),
      },
    );
    _refresh();
  }

  Future<void> reset(String key) async {
    await _api.post('/roles/$key/reset');
    _refresh();
  }

  Future<void> delete(String key) async {
    await _api.request('DELETE', '/roles/$key');
    _refresh();
  }
}
