import 'dart:async';

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

/// Jumlah belum dibaca. Disegarkan tiap 10 detik, saat ada notifikasi, dan saat aplikasi aktif kembali.
class UnreadNotifier extends Notifier<int> {
  Timer? _poll;
  Timer? _debounce;
  int _gen = 0;
  bool _disposed = false;

  @override
  int build() {
    _disposed = false;
    final session = ref.watch(sessionProvider).value;
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
      _debounce?.cancel();
    });
    if (session == null) return 0;
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    Future.microtask(_load);
    return 0;
  }

  Future<void> _load() async {
    final gen = ++_gen;
    try {
      final m =
          await ref.read(apiClientProvider).get('/notifications/unread-count')
              as Map<String, dynamic>;
      if (!_disposed && gen == _gen)
        state = (m['count'] as num).toInt(); // jawaban usang dibuang
    } catch (_) {
      /* offline: pakai angka terakhir */
    }
  }

  /// Beberapa pemanggilan beruntun digabung menjadi satu permintaan.
  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  /// Notifikasi baru masuk: tampilkan segera, lalu server mengoreksi.
  void bump() {
    _gen++; // permintaan yang sedang berjalan sudah usang
    state = state + 1;
  }
}

final unreadNotificationsProvider = NotifierProvider<UnreadNotifier, int>(
  UnreadNotifier.new,
);

final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      ref.watch(
        unreadNotificationsProvider,
      ); // jumlah berubah -> daftar dimuat ulang
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

/// Tandai dibaca. Gagal (offline) diam-diam: akan dicoba lagi saat layar dibuka berikutnya.
Future<bool> markNotificationsRead(
  WidgetRef ref, {
  List<String> ids = const [],
  bool all = false,
  String? refType,
  String? refId,
}) async {
  try {
    await ref
        .read(apiClientProvider)
        .post(
          '/notifications/read',
          data: {'ids': ids, 'all': all, 'ref_type': refType, 'ref_id': refId},
        );
  } catch (_) {
    return false;
  }
  try {
    ref.invalidate(notificationsListProvider);
    ref.read(unreadNotificationsProvider.notifier).refresh();
  } catch (_) {
    /* halaman sudah ditutup */
  }
  return true;
}
