import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/core/data_window.dart';
import 'package:rms_yow/core/sync/sync_controller.dart';
import 'package:rms_yow/features/tables/tables_providers.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../finance/expense.dart';
import '../finance/finance_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../tables/dining_table.dart';
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

  Widget _card(
    IconData icon,
    String title,
    String sub,
    String format,
    VoidCallback onTap, {
    bool pdf = false,
  }) {
    final tone = toneColors(pdf ? Tone.danger : Tone.info);
    return Opacity(
      opacity: _busy ? .5 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tone.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tone.fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        sub,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(format, tone: pdf ? Tone.danger : Tone.info),
                const SizedBox(width: 6),
                const Icon(Icons.ios_share, size: 20, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Periode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PeriodChips(
                range: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _period,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              WindowNotice(rangeStart: _range.start),
            ],
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Pemisah kolom CSV',
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ';', label: Text('Titik koma (Excel ID)')),
              ButtonSegment(value: ',', label: Text('Koma (Sheets)')),
            ],
            selected: {_sep},
            onSelectionChanged: (v) => setState(() => _sep = v.first),
          ),
        ),
        const SizedBox(height: 16),
        Text('Unduh data', style: th.titleMedium),
        const SizedBox(height: 10),
        AdaptiveGrid(
          minTileWidth: 380,
          maxColumns: 2,
          children: [
            _card(
              Icons.receipt_long,
              'Penjualan per order',
              'Satu baris per transaksi',
              'CSV',
              () => _csv('penjualan_order', ordersRows),
            ),
            _card(
              Icons.list_alt,
              'Penjualan per item',
              'Rincian item terjual',
              'CSV',
              () => _csv('penjualan_item', itemsRows),
            ),
            _card(
              Icons.payments_outlined,
              'Biaya operasional',
              'Daftar biaya pada periode',
              'CSV',
              () => _csv('biaya', expensesRows),
            ),
            _card(
              Icons.inventory_2_outlined,
              'Mutasi stok',
              'Pembelian, penjualan, waste, opname',
              'CSV',
              () => _csv('mutasi_stok', stockRows),
            ),
            _card(
              Icons.account_balance_wallet_outlined,
              'Laba rugi',
              'Ringkasan laba rugi',
              'CSV',
              () => _csv('laba_rugi', plRows),
            ),
            _card(
              Icons.picture_as_pdf_outlined,
              'Ringkasan laporan',
              'Dokumen siap bagikan',
              'PDF',
              _pdf,
              pdf: true,
            ),
          ],
        ),
      ],
    );
  }
}
