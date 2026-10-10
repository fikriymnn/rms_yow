import 'dart:math';

import '../inventory/inventory_models.dart';
import '../orders/order_models.dart';
import 'expense.dart';

class ProfitLoss {
  const ProfitLoss({
    required this.revenue,
    required this.refunds,
    required this.cogs,
    required this.shrink,
    required this.opex,
    required this.orderCount,
  });

  final int revenue; // penjualan sebelum pajak
  final int refunds;
  final int cogs; // HPP bahan terjual
  final int shrink; // waste + selisih opname/koreksi
  final Map<String, int> opex; // kategori -> total
  final int orderCount;

  int get netRevenue => revenue - refunds;
  int get grossProfit => netRevenue - cogs;
  int get opexTotal => opex.values.fold(0, (a, b) => a + b);
  int get netProfit => grossProfit - shrink - opexTotal;
  double get grossMarginPct =>
      netRevenue > 0 ? grossProfit / netRevenue * 100 : 0;
}

/// [start] inklusif, [end] eksklusif (epoch millis).
ProfitLoss computeProfitLoss({
  required List<Order> orders,
  required List<StockMove> moves,
  required Map<String, double> avgCost,
  required List<Expense> expenses,
  required int start,
  required int end,
}) {
  bool inRange(int t) => t >= start && t < end;
  int exTax(Order o) => max(0, o.subtotal - o.discount);

  var revenue = 0, refunds = 0, count = 0;
  for (final o in orders) {
    final sold =
        o.status == OrderStatus.paid || o.status == OrderStatus.refunded;
    if (sold && inRange(o.paidAt ?? 0)) {
      revenue += exTax(o);
      count++;
    }
    if (o.status == OrderStatus.refunded && inRange(o.refundedAt ?? 0)) {
      refunds += exTax(o);
    }
  }

  double cogs = 0, shrink = 0;
  for (final m in moves) {
    if (!inRange(m.at)) continue;
    final c = avgCost[m.ingredientId] ?? 0;
    switch (m.type) {
      case StockMoveType.sale:
        cogs += -m.qty * c;
      case StockMoveType.waste:
      case StockMoveType.opname:
      case StockMoveType.adjust:
        shrink += -m.qty * c;
      case StockMoveType.purchase:
        break;
    }
  }

  final opex = <String, int>{};
  for (final e in expenses) {
    if (!inRange(e.at) || e.category == kPurchaseCategory) continue;
    opex[e.category] = (opex[e.category] ?? 0) + e.amount;
  }

  return ProfitLoss(
    revenue: revenue,
    refunds: refunds,
    cogs: cogs.round(),
    shrink: shrink.round(),
    opex: opex,
    orderCount: count,
  );
}
