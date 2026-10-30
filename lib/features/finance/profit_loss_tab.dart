import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/data_window.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
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

  String _neg(int v) => v == 0 ? rupiah.format(0) : '-${rupiah.format(v)}';

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? <Order>[];
    final start = _range.start.millisecondsSinceEpoch;
    final end = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day + 1,
    ).millisecondsSinceEpoch;
    final movesAsync = ref.watch(
      movesInRangeProvider((start: start, end: end)),
    );
    final moves = movesAsync.value ?? <StockMove>[];
    final avg = ref.watch(avgCostProvider);
    final expenses = ref.watch(expensesProvider).value ?? <Expense>[];

    final p = computeProfitLoss(
      orders: orders,
      moves: moves,
      avgCost: avg,
      expenses: expenses,
      start: start,
      end: end,
    );
    final opex = p.opex.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final opexDenom = max(1, p.opexTotal);
    final preset =
        _range == _today() || _range == _thisMonth() || _range == _lastMonth();
    final profit = p.netProfit;
    final positive = profit >= 0;
    final netMargin = p.netRevenue > 0
        ? (profit * 100 / p.netRevenue).round()
        : null;

    final hero = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.inkSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Laba bersih',
                style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white70),
              ),
              const Spacer(),
              if (netMargin != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Margin $netMargin%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah.format(profit),
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: positive
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFFDA4AF),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt.format(_range.start)} – ${_fmt.format(_range.end)} • ${p.orderCount} order',
            style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white54),
          ),
        ],
      ),
    );

    final tiles = AdaptiveGrid(
      children: [
        StatTile(
          icon: Icons.payments_outlined,
          label: 'Penjualan bersih',
          value: rupiah.format(p.netRevenue),
        ),
        StatTile(
          icon: Icons.trending_up,
          label: 'Laba kotor',
          value: rupiah.format(p.grossProfit),
          caption: '${p.grossMarginPct.toStringAsFixed(1)}% dari penjualan',
          tone: Tone.success,
        ),
        StatTile(
          icon: Icons.restaurant_outlined,
          label: 'HPP (bahan terjual)',
          value: rupiah.format(p.cogs),
          tone: Tone.warning,
        ),
        StatTile(
          icon: Icons.receipt_long_outlined,
          label: 'Waste + biaya operasional',
          value: rupiah.format(p.shrink + p.opexTotal),
          tone: Tone.danger,
        ),
      ],
    );

    final grossCard = SectionCard(
      title: 'Laba kotor',
      child: Column(
        children: [
          KvRow('Penjualan (sebelum pajak)', rupiah.format(p.revenue)),
          if (p.refunds > 0)
            KvRow('Refund', _neg(p.refunds), color: AppColors.danger),
          KvRow('Penjualan bersih', rupiah.format(p.netRevenue), bold: true),
          KvRow('HPP (bahan terjual)', _neg(p.cogs)),
          const Divider(height: 20),
          KvRow(
            'Laba kotor (${p.grossMarginPct.toStringAsFixed(1)}%)',
            rupiah.format(p.grossProfit),
            bold: true,
            color: AppColors.success,
          ),
        ],
      ),
    );

    final costCard = SectionCard(
      title: 'Biaya dan laba bersih',
      child: Column(
        children: [
          KvRow('Waste & selisih stok', _neg(p.shrink)),
          KvRow('Biaya operasional', _neg(p.opexTotal), bold: true),
          for (final e in opex)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 0, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Text(
                        _neg(e.value),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / opexDenom,
                      minHeight: 4,
                      color: AppColors.rose,
                      backgroundColor: AppColors.roseSoft,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          KvRow(
            'Laba bersih',
            rupiah.format(profit),
            bold: true,
            color: positive ? AppColors.success : AppColors.danger,
          ),
        ],
      ),
    );

    final note = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pajak (PB1) tidak dihitung sebagai pendapatan. HPP memakai harga beli '
              'rata-rata saat ini. Biaya dicatat sesuai tanggal input (basis kas).',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (movesAsync.isLoading) const LinearProgressIndicator(),
            WindowNotice(rangeStart: _range.start),
            Wrap(
              spacing: 8,
              runSpacing: 4,
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
            const SizedBox(height: 12),
            hero,
            const SizedBox(height: 12),
            tiles,
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: grossCard),
                  const SizedBox(width: 12),
                  Expanded(child: costCard),
                ],
              )
            else ...[
              grossCard,
              const SizedBox(height: 12),
              costCard,
            ],
            const SizedBox(height: 12),
            note,
          ],
        );
      },
    );
  }
}
