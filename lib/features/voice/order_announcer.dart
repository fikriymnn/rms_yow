import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../auth/auth_providers.dart';
import '../notifications/notification_service.dart';
import '../orders/items_status.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/dining_table.dart';
import '../tables/tables_providers.dart';
import 'voice_service.dart';

/// Kalimat tujuan pesanan: "meja 4", "nomor 12", atau "takeaway".
String spokenWhere(Order o, Map<String, String> tableNames) {
  final q = o.queueNo;
  if (q != null && q.isNotEmpty) return 'nomor $q';
  if (o.tableId == null) return 'takeaway';
  final name = (tableNames[o.tableId] ?? '').trim();
  if (name.isEmpty) return 'meja';
  return name.toLowerCase().startsWith('meja') ? name : 'meja $name';
}

String newOrderSentence(Order o, Map<String, String> tables, {bool addition = false}) {
  final w = spokenWhere(o, tables);
  return addition ? 'Tambahan pesanan untuk $w' : 'Pesanan untuk $w sudah dibuat';
}

String readySentence(Order o, Map<String, String> tables) {
  final w = spokenWhere(o, tables);
  if (o.queueNo != null && o.queueNo!.isNotEmpty) return 'Pesanan $w siap diambil';
  if (o.tableId == null) return 'Pesanan takeaway siap';
  return 'Pesanan $w siap diantar';
}

/// Mengumumkan pesanan baru & pesanan siap dengan suara, dari data yang tersinkron ke
/// perangkat ini (bukan dari push), jadi tetap jalan walau semua memakai satu akun.
///
/// Saat mulai / ganti outlet, data yang sudah ada dicatat diam-diam (tidak dibacakan ulang).
/// Kejadian lebih lama dari [_fresh] (mis. data menumpuk setelah offline) tidak dibacakan.
class OrderAnnouncer {
  OrderAnnouncer(this._ref) {
    _ref.listen<AsyncValue<List<Order>>>(ordersProvider, (_, next) {
      final v = next.value;
      if (v != null) _onOrders(v);
    }, fireImmediately: true);
    _ref.listen<AsyncValue<Map<String, ItemStatus>>>(itemStatusDocsProvider, (_, next) {
      final v = next.value;
      if (v != null) _onStatus(v);
    }, fireImmediately: true);
    // jaga pengaturan suara tetap termuat (dibaca saat mengumumkan)
    _ref.listen(voiceSettingsProvider, (_, _) {}, fireImmediately: true);
    _ref.onDispose(() => _timer?.cancel());
  }

  final Ref _ref;
  static const _fresh = Duration(minutes: 10);

  final Map<String, Set<String>> _items = {}; // orderId -> item yang sudah dikenal
  final Set<String> _readyItems = {};
  bool _ordersSeeded = false;
  bool _statusSeeded = false;

  final Map<String, ({bool addition})> _pendingNew = {};
  final Set<String> _pendingReady = {};
  Timer? _timer;

  int get _now => DateTime.now().millisecondsSinceEpoch;
  VoiceSettings? get _settings => _ref.read(voiceSettingsProvider).value;

  void _onOrders(List<Order> orders) {
    final cutoff = _now - const Duration(hours: 12).inMilliseconds;
    for (final o in orders) {
      if (o.createdAt < cutoff || o.status == OrderStatus.voided || o.status == OrderStatus.refunded) {
        continue;
      }
      final known = _items[o.id];
      final ids = {for (final i in o.items) i.id};
      if (_ordersSeeded) {
        final added = o.items.where((i) => known == null || !known.contains(i.id)).toList();
        final fresh = added.any((i) => _now - (i.addedAt ?? o.paidAt ?? o.createdAt) < _fresh.inMilliseconds);
        if (added.isNotEmpty && fresh) {
          final prev = _pendingNew[o.id];
          _pendingNew[o.id] = (addition: prev?.addition ?? known != null);
          _schedule();
        }
      }
      _items[o.id] = {...?known, ...ids};
    }
    _ordersSeeded = true;
  }

  void _onStatus(Map<String, ItemStatus> docs) {
    for (final d in docs.values) {
      if (d.status != KitchenStatus.ready) continue;
      if (_readyItems.add(d.id) && _statusSeeded) {
        final at = d.readyAt;
        if (at == null || _now - at < _fresh.inMilliseconds) {
          _pendingReady.add(d.orderId);
          _schedule();
        }
      }
    }
    _statusSeeded = true;
  }

  /// Beberapa item berubah hampir bersamaan (satu tiket): gabungkan jadi satu kalimat.
  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 900), _flush);
  }

  void _flush() {
    // aplikasi di latar belakang: pengumuman datang lewat push (dibacakan background handler),
    // jadi di sini tidak dibacakan agar tidak terdengar dua kali
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _pendingNew.clear();
      _pendingReady.clear();
      return;
    }
    final s = _settings;
    final orders = {for (final o in _ref.read(ordersProvider).value ?? const <Order>[]) o.id: o};
    final tables = {
      for (final t in _ref.read(tablesProvider).value ?? const <DiningTable>[]) t.id: t.name,
    };
    final voice = _ref.read(voiceServiceProvider);
    if (s?.newOrder ?? false) {
      for (final e in _pendingNew.entries) {
        final o = orders[e.key];
        if (o != null) voice.say(newOrderSentence(o, tables, addition: e.value.addition));
      }
    }
    if (s?.ready ?? false) {
      for (final id in _pendingReady) {
        final o = orders[id];
        if (o != null) voice.say(readySentence(o, tables));
      }
    }
    _pendingNew.clear();
    _pendingReady.clear();
  }
}

/// Aktif selama aplikasi utama terbuka. Dibuat ulang saat ganti outlet (data disemai ulang).
final orderAnnouncerProvider = Provider<OrderAnnouncer>((ref) {
  ref.watch(activeOutletIdProvider);
  return OrderAnnouncer(ref);
});

/// Menyamakan pengaturan suara perangkat dengan server (penerima push pesanan) dan menyalakan
/// "layar tetap menyala". Aktif di HomeShell.
final voiceDeviceSyncProvider = Provider<void>((ref) {
  ref.listen<String?>(activeOutletIdProvider, (_, _) => ref.read(notificationServiceProvider).syncVoice());
  ref.listen<AsyncValue<VoiceSettings>>(voiceSettingsProvider, (prev, next) {
    final v = next.value;
    if (v == null) return;
    final p = prev?.value;
    if (p == null || p.newOrder != v.newOrder || p.ready != v.ready) {
      ref.read(notificationServiceProvider).syncVoice();
    }
    if (!kIsWeb) unawaited(v.keepAwake ? WakelockPlus.enable() : WakelockPlus.disable());
  }, fireImmediately: true);
});
