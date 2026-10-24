import '../orders/order_models.dart';

/// Penjualan bersih = subtotal − diskon (sebelum pajak). Hanya pesanan berstatus paid,
/// jadi void dan refund tidak ikut dihitung.
int netSales(Order o) {
  final n = o.subtotal - o.discount;
  return n < 0 ? 0 : n;
}

class HomeStats {
  const HomeStats({
    required this.days,
    required this.totals,
    required this.counts,
    required this.top,
  });
  final List<DateTime> days; // 7 hari: terlama sampai hari ini
  final List<int> totals;
  final List<int> counts;
  final List<({String name, int qty})> top; // menu terlaris hari ini

  int get todayTotal => totals.last;
  int get todayCount => counts.last;
  int get yesterdayTotal => totals[totals.length - 2];
  int get average => todayCount == 0 ? 0 : (todayTotal / todayCount).round();
  int? get deltaPct => yesterdayTotal == 0
      ? null
      : ((todayTotal - yesterdayTotal) * 100 / yesterdayTotal).round();
}

HomeStats computeHomeStats(List<Order> orders, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  final starts = [for (final d in days) d.millisecondsSinceEpoch];
  final end = today.add(const Duration(days: 1)).millisecondsSinceEpoch;

  final totals = List<int>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  final qty = <String, int>{};

  for (final o in orders) {
    final at = o.paidAt;
    if (o.status != OrderStatus.paid ||
        at == null ||
        at < starts.first ||
        at >= end)
      continue;
    var idx = 6;
    while (idx > 0 && at < starts[idx]) {
      idx--;
    }
    totals[idx] += netSales(o);
    counts[idx]++;
    if (idx == 6) {
      for (final it in o.items) {
        qty[it.name] = (qty[it.name] ?? 0) + it.qty;
      }
    }
  }
  final top = qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return HomeStats(
    days: days,
    totals: totals,
    counts: counts,
    top: [for (final e in top.take(5)) (name: e.key, qty: e.value)],
  );
}
