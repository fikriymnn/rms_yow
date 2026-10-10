import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import 'expense.dart';
import 'finance_providers.dart';
import 'profit_loss.dart';

class ProfitLossTab extends ConsumerStatefulWidget {
  const ProfitLossTab({super.key});
  @override
  ConsumerState<ProfitLossTab> createState() => _ProfitLossTabState();
}

class _ProfitLossTabState extends ConsumerState<ProfitLossTab> {
  static final _fmt = DateFormat('d MMM yyyy');

  static DateTimeRange _today() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return DateTimeRange(start: d, end: d);
  }

  static DateTimeRange _thisMonth() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month),
      end: DateTime(n.year, n.month + 1, 0),
    );
  }

  static DateTimeRange _lastMonth() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month - 1),
      end: DateTime(n.year, n.month, 0),
    );
  }

  DateTimeRange _range = _thisMonth();

  Future<void> _custom() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Widget _chip(String label, DateTimeRange r) => ChoiceChip(
    label: Text(label),
    selected: _range == r,
    onSelected: (_) => setState(() => _range = r),
  );

  Widget _row(
    String k,
    int v, {
    bool bold = false,
    bool indent = false,
    Color? color,
  }) {
    final st = TextStyle(
      fontWeight: bold ? FontWeight.bold : null,
      color: color,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 16 : 0, 3, 0, 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(k, style: st)),
          Text(rupiah.format(v), style: st),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? <Order>[];
    final moves = ref.watch(stockMovesProvider).value ?? <StockMove>[];
    final avg = ref.watch(avgCostProvider);
    final expenses = ref.watch(expensesProvider).value ?? <Expense>[];

    final p = computeProfitLoss(
      orders: orders,
      moves: moves,
      avgCost: avg,
      expenses: expenses,
      start: _range.start.millisecondsSinceEpoch,
      end: DateTime(
        _range.end.year,
        _range.end.month,
        _range.end.day + 1,
      ).millisecondsSinceEpoch,
    );
    final opex = p.opex.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cs = Theme.of(context).colorScheme;
    final preset =
        _range == _today() || _range == _thisMonth() || _range == _lastMonth();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            _chip('Hari ini', _today()),
            _chip('Bulan ini', _thisMonth()),
            _chip('Bulan lalu', _lastMonth()),
            ChoiceChip(
              label: const Text('Kustom'),
              selected: !preset,
              onSelected: (_) => _custom(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_fmt.format(_range.start)} – ${_fmt.format(_range.end)} • ${p.orderCount} order',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 24),
        _row('Penjualan (sebelum pajak)', p.revenue),
        if (p.refunds > 0) _row('Refund', -p.refunds),
        _row('Penjualan bersih', p.netRevenue, bold: true),
        _row('HPP (bahan terjual)', -p.cogs),
        _row(
          'Laba kotor (${p.grossMarginPct.toStringAsFixed(1)}%)',
          p.grossProfit,
          bold: true,
        ),
        const Divider(height: 24),
        _row('Waste & selisih stok', -p.shrink),
        _row('Biaya operasional', -p.opexTotal),
        for (final e in opex) _row(e.key, -e.value, indent: true),
        const Divider(height: 24),
        _row(
          'Laba bersih',
          p.netProfit,
          bold: true,
          color: p.netProfit >= 0 ? cs.primary : cs.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Pajak (PB1) tidak dihitung sebagai pendapatan. HPP memakai harga beli '
          'rata-rata saat ini. Biaya dicatat sesuai tanggal input (basis kas).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
