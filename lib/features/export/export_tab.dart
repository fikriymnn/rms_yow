import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/data_window.dart';
import 'package:rms_yow/core/sync/sync_controller.dart';
import 'package:rms_yow/features/tables/table_providers.dart';

import '../finance/finance_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/dining_table.dart';
import '../finance/expense.dart';
import 'csv_util.dart';
import 'export_builders.dart';
import 'export_pdf.dart';
import 'export_service.dart';
import 'period_chips.dart';

class ExportTab extends ConsumerStatefulWidget {
  const ExportTab({super.key});
  @override
  ConsumerState<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends ConsumerState<ExportTab> {
  DateTimeRange _range = PeriodChips.thisMonth();
  String _sep = ';';
  bool _busy = false;

  static final _label = DateFormat('d MMM yyyy');
  static final _stampFmt = DateFormat('yyyyMMdd');

  String get _period =>
      '${_label.format(_range.start)} - ${_label.format(_range.end)}';
  String get _stamp =>
      '${_stampFmt.format(_range.start)}_${_stampFmt.format(_range.end)}';

  Future<ExportData> _data() async {
    final start = _range.start.millisecondsSinceEpoch;
    final end = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day + 1,
    ).millisecondsSinceEpoch;
    final moves = await loadStockMoves(
      ref.read(databaseProvider),
      start: start,
      end: end,
    );
    return ExportData(
      orders: ref.read(ordersProvider).value ?? <Order>[],
      moves: moves,
      expenses: ref.read(expensesProvider).value ?? <Expense>[],
      ingredients: {
        for (final i in ref.read(ingredientsProvider).value ?? <Ingredient>[])
          i.id: i,
      },
      tables: {
        for (final t in ref.read(tablesProvider).value ?? <DiningTable>[])
          t.id: t.name,
      },
      avgCost: ref.read(avgCostProvider),
      start: start,
      end: end,
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _toast('Ekspor gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _csv(
    String name,
    List<List<Object?>> Function(ExportData) build,
  ) => _run(() async {
    final rows = build(await _data());
    if (rows.length <= 1) {
      _toast('Tidak ada data pada periode ini');
      return;
    }
    await shareBytes(
      'rms_${name}_$_stamp.csv',
      'text/csv',
      Uint8List.fromList(toCsvBytes(rows, sep: _sep)),
    );
  });

  Future<void> _pdf() => _run(() async {
    final bytes = await buildSummaryPdf(await _data(), _period);
    await shareBytes('rms_ringkasan_$_stamp.pdf', 'application/pdf', bytes);
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(sub),
          trailing: const Icon(Icons.ios_share),
          enabled: !_busy,
          onTap: onTap,
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PeriodChips(
          range: _range,
          onChanged: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: 8),
        Text(_period, style: th.bodySmall),
        WindowNotice(rangeStart: _range.start),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 16),
        Text('Pemisah kolom CSV', style: th.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: ';', label: Text('Titik koma (Excel ID)')),
            ButtonSegment(value: ',', label: Text('Koma (Sheets)')),
          ],
          selected: {_sep},
          onSelectionChanged: (v) => setState(() => _sep = v.first),
        ),
        const Divider(height: 32),
        tile(
          Icons.receipt_long,
          'Penjualan per order',
          'CSV',
          () => _csv('penjualan_order', ordersRows),
        ),
        tile(
          Icons.list_alt,
          'Penjualan per item',
          'CSV',
          () => _csv('penjualan_item', itemsRows),
        ),
        tile(
          Icons.payments_outlined,
          'Biaya operasional',
          'CSV',
          () => _csv('biaya', expensesRows),
        ),
        tile(
          Icons.inventory_2_outlined,
          'Mutasi stok',
          'CSV',
          () => _csv('mutasi_stok', stockRows),
        ),
        tile(
          Icons.account_balance_wallet_outlined,
          'Laba rugi',
          'CSV',
          () => _csv('laba_rugi', plRows),
        ),
        const Divider(height: 32),
        tile(Icons.picture_as_pdf_outlined, 'Ringkasan laporan', 'PDF', _pdf),
      ],
    );
  }
}
