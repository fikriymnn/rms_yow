import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_providers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.refId,
    required this.createdAt,
    required this.read,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final String refId;
  final int createdAt;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> m) {
    final data = Map<String, dynamic>.from(m['data'] as Map? ?? {});
    return AppNotification(
      id: m['id'] as String,
      type: m['type'] as String? ?? '',
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      refId: data['id'] as String? ?? '',
      createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
      read: m['read'] == true,
    );
  }
}

/// Jumlah belum dibaca (penanda di navigasi), disegarkan tiap 30 detik.
final unreadNotificationsProvider = StreamProvider<int>((ref) async* {
  if (ref.watch(sessionProvider).value == null) {
    yield 0;
    return;
  }
  var last = 0;
  while (true) {
    try {
      final m =
          await ref.read(apiClientProvider).get('/notifications/unread-count')
              as Map<String, dynamic>;
      last = (m['count'] as num).toInt();
    } catch (_) {
      /* offline: pakai angka terakhir */
    }
    yield last;
    await Future<void>.delayed(const Duration(seconds: 30));
  }
});

final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      ref.watch(unreadNotificationsProvider);
      final data =
          await ref
                  .read(apiClientProvider)
                  .get('/notifications', query: {'limit': 50})
              as List<dynamic>;
      return [
        for (final m in data)
          AppNotification.fromJson(m as Map<String, dynamic>),
      ];
    });

Future<void> markNotificationsRead(
  WidgetRef ref, {
  List<String> ids = const [],
  bool all = false,
}) async {
  await ref
      .read(apiClientProvider)
      .post('/notifications/read', data: {'ids': ids, 'all': all});
  ref.invalidate(notificationsListProvider);
  ref.invalidate(unreadNotificationsProvider);
}
