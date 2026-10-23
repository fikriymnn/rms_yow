import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/sync/sync_controller.dart';
import '../approvals/approval_providers.dart';
import 'notification_providers.dart';
import 'notification_router.dart';

const _kitchenChannel = AndroidNotificationChannel(
  'kitchen_orders',
  'Pesanan dapur',
  description: 'Pesanan baru untuk dapur',
  importance: Importance.max,
);
const _approvalChannel = AndroidNotificationChannel(
  'approvals',
  'Persetujuan',
  description: 'Pengajuan dan keputusan persetujuan',
  importance: Importance.high,
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref),
);

class NotificationService {
  NotificationService(this._ref);
  final Ref _ref;
  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _token;

  bool get _supported => !kIsWeb;

  /// Panggil setelah login. Gagal diam-diam bila Firebase belum dikonfigurasi.
  Future<void> start() async {
    if (!_supported) return;
    try {
      if (!_ready) await _init();
      final perm = await FirebaseMessaging.instance.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (_) {
      /* push tidak aktif; aplikasi tetap berjalan */
    }
  }

  Future<void> _init() async {
    await Firebase.initializeApp(); // Android: membaca google-services.json
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p == null) return;
        try {
          final m = jsonDecode(p) as Map<String, dynamic>;
          _tap(m['type'] as String?, m['id'] as String?);
        } catch (_) {}
      },
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_kitchenChannel);
    await android?.createNotificationChannel(_approvalChannel);

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _tap(m.data['type'], m.data['id']),
    );
    FirebaseMessaging.instance.onTokenRefresh.listen(_register);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _tap(initial.data['type'], initial.data['id']);
    _ready = true;
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _ref
          .read(apiClientProvider)
          .post(
            '/notifications/devices',
            data: {'token': token, 'platform': 'android'},
          );
    } catch (_) {
      /* dicoba lagi saat aplikasi dibuka berikutnya */
    }
  }

  void _tap(String? type, String? id) {
    if (type == null || id == null || id.isEmpty) return;
    _ref.read(notificationTapProvider.notifier).set(NotificationTap(type, id));
  }

  /// Aplikasi sedang terbuka: sistem tidak menampilkan notifikasi, jadi kita yang menampilkannya.
  Future<void> _onForeground(RemoteMessage m) async {
    final type = m.data['type'] ?? '';
    if (type == 'order') {
      unawaited(
        _ref.read(syncControllerProvider.notifier).syncNow(),
      ); // pesanan muncul seketika
    }
    _ref.invalidate(unreadNotificationsProvider);
    _ref.invalidate(approvalCountsProvider);
    final n = m.notification;
    if (n == null) return;
    final ch = type == 'order' ? _kitchenChannel : _approvalChannel;
    await _local.show(
      id: (m.messageId ?? '${n.title}${n.body}').hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: ch.importance,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode({'type': type, 'id': m.data['id']}),
    );
  }

  /// Panggil SEBELUM sesi dihapus (butuh token login yang masih berlaku).
  Future<void> unregister() async {
    if (!_supported || !_ready) return;
    try {
      final t = _token ?? await FirebaseMessaging.instance.getToken();
      if (t != null) {
        await _ref
            .read(apiClientProvider)
            .post('/notifications/devices/unregister', data: {'token': t});
      }
      await FirebaseMessaging.instance
          .deleteToken(); // pengguna berikutnya mendapat token baru
      _token = null;
    } catch (_) {}
  }
}
