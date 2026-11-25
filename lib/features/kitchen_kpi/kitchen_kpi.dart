/// Perhitungan KPI dapur dari pesanan + status item (waktu tiap tahap).
///
/// Per item:
///   masuk   = item ditambahkan ke pesanan (addedAt; data lama: waktu pesanan / bayar untuk foodcourt)
///   antre   = masuk -> mulai dimasak
///   masak   = mulai dimasak -> siap
///   total   = masuk -> siap            (dipakai untuk "tepat waktu")
///   antar   = siap -> diantar / diambil
/// Item dihitung pada periode saat item itu SIAP. Durasi negatif atau > 4 jam dianggap salah
/// tekan dan diabaikan agar rata-rata tidak rusak.
library;

import '../orders/items_status.dart';
import '../orders/order_models.dart';

const _maxMs = 4 * 60 * 60 * 1000;

int? _span(int? from, int? to) {
  if (from == null || to == null) return null;
  final d = to - from;
  return d < 0 || d > _maxMs ? null : d;
}

class KitchenRecord {
  KitchenRecord(this.order, this.item, this.status);
  final Order order;
  final OrderItem item;
  final ItemStatus status;

  int get enteredAt =>
      item.addedAt ?? ((order.queueNo?.isNotEmpty ?? false) ? (order.paidAt ?? order.createdAt) : order.createdAt);
  int? get wait => _span(enteredAt, status.preparingAt);
  int? get cook => _span(status.preparingAt, status.readyAt);
  int? get total => _span(enteredAt, status.readyAt);
  int? get deliver => _span(status.readyAt, status.servedAt);
  String get cookName => status.readyBy.isNotEmpty ? status.readyBy : status.preparingBy;
}

/// Ringkasan durasi (milidetik).
class DurationStats {
  DurationStats(List<int> values)
    : count = values.length,
      avg = values.isEmpty ? null : values.reduce((a, b) => a + b) ~/ values.length,
      p90 = values.isEmpty ? null : (List<int>.of(values)..sort())[((values.length - 1) * 0.9).round()];
  final int count;
  final int? avg;
  final int? p90; // 90% item selesai dalam waktu ini
}

class GroupStats {
  GroupStats(this.name, this.records, int targetMs)
    : portions = records.fold(0, (s, r) => s + r.item.qty),
      cook = DurationStats([for (final r in records) ?r.cook]),
      total = DurationStats([for (final r in records) ?r.total]),
      onTime = _onTime(records, targetMs);
  final String name;
  final List<KitchenRecord> records;
  final int portions;
  final DurationStats cook;
  final DurationStats total;
  final double? onTime; // 0..1
}

double? _onTime(List<KitchenRecord> rs, int targetMs) {
  final t = [for (final r in rs) ?r.total];
  if (t.isEmpty) return null;
  return t.where((v) => v <= targetMs).length / t.length;
}

class KitchenKpi {
  KitchenKpi(this.records, this.targetMs)
    : wait = DurationStats([for (final r in records) ?r.wait]),
      cook = DurationStats([for (final r in records) ?r.cook]),
      total = DurationStats([for (final r in records) ?r.total]),
      deliver = DurationStats([for (final r in records) ?r.deliver]),
      onTime = _onTime(records, targetMs),
      portions = records.fold(0, (s, r) => s + r.item.qty);

  final List<KitchenRecord> records;
  final int targetMs;
  final DurationStats wait;
  final DurationStats cook;
  final DurationStats total;
  final DurationStats deliver;
  final double? onTime;
  final int portions;

  int get lateCount => records.where((r) => (r.total ?? 0) > targetMs).length;

  /// Porsi per jam (0–23) menurut jam item masuk.
  List<int> get perHour {
    final h = List<int>.filled(24, 0);
    for (final r in records) {
      h[DateTime.fromMillisecondsSinceEpoch(r.enteredAt).hour] += r.item.qty;
    }
    return h;
  }

  List<GroupStats> _group(String Function(KitchenRecord) key) {
    final m = <String, List<KitchenRecord>>{};
    for (final r in records) {
      final k = key(r);
      if (k.isEmpty) continue;
      (m[k] ??= []).add(r);
    }
    return [for (final e in m.entries) GroupStats(e.key, e.value, targetMs)];
  }

  /// Menu dengan waktu total rata-rata terlama (min. 2 data).
  List<GroupStats> get slowestMenus =>
      _group((r) => r.item.name).where((g) => g.total.count >= 2).toList()
        ..sort((a, b) => (b.total.avg ?? 0).compareTo(a.total.avg ?? 0));

  List<GroupStats> get byCook =>
      _group((r) => r.cookName)..sort((a, b) => b.portions.compareTo(a.portions));

  static KitchenKpi build({
    required List<Order> orders,
    required Map<String, ItemStatus> status,
    required int from,
    required int to,
    required int targetMs,
  }) {
    final out = <KitchenRecord>[];
    for (final o in orders) {
      if (o.status == OrderStatus.voided) continue;
      for (final it in o.items) {
        final s = status[it.id];
        final at = s?.readyAt;
        if (s == null || at == null || at < from || at >= to) continue;
        out.add(KitchenRecord(o, it, s));
      }
    }
    out.sort((a, b) => b.status.readyAt!.compareTo(a.status.readyAt!));
    return KitchenKpi(out, targetMs);
  }
}

String minutesText(int? ms) {
  if (ms == null) return '—';
  final m = ms / 60000;
  if (m < 1) return '${(ms / 1000).round()} dtk';
  return m < 10 ? '${m.toStringAsFixed(1).replaceAll('.', ',')} mnt' : '${m.round()} mnt';
}
