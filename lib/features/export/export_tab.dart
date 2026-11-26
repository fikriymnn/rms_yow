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
import 'export_builders.dart';
import 'export_pdf.dart';
import 'export_service.dart';
import 'period_chips.dart';
import 'xlsx_writer.dart';

class ExportTab extends ConsumerStatefulWidget {
  const ExportTab({super.key});
  @override
  ConsumerState<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends ConsumerState<ExportTab> {
  DateTimeRange _range = PeriodChips.thisMonth();
  OrderSource? _source; // filter sumber pesanan untuk data penjualan
  bool _busy = false;

  static final _label = DateFormat('d MMM yyyy');
  static final _stampFmt = DateFormat('yyyyMMdd');

  String get _period =>
      '${_label.format(_range.start)} - ${_label.format(_range.end)}';
  String get _stamp =>
      '${_stampFmt.format(_range.start)}_${_stampFmt.format(_range.end)}';

  Future<ExportData> _data() => loadExportData(
    ref,
    _range.start.millisecondsSinceEpoch,
    DateTime(_range.end.year, _range.end.month, _range.end.day + 1).millisecondsSinceEpoch,
    _source,
  );

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

  static const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  String get _sourceTag => _source == null ? '' : '_${_source!.name}';

  XlsxSheet _sheet(String name, List<List<Object?>> rows) => XlsxSheet(
    name,
    rows,
    boldRows: {
      if (rows.length > 1 && rows.last.isNotEmpty && rows.last.first == 'TOTAL') rows.length - 1,
    },
  );

  /// Info periode & filter di sheet pertama agar file jelas asal-usulnya.
  XlsxSheet _infoSheet(ExportData d, String title) => XlsxSheet('Info', [
    [title],
    ['Periode', _period],
    ['Sumber pesanan', d.sourceLabel],
    ['Dibuat', DateTime.now()],
  ], headerRows: 0, boldRows: {0});

  Future<void> _xlsx(
    String name,
    String title,
    List<List<Object?>> Function(ExportData) build,
  ) => _run(() async {
    final d = await _data();
    final rows = build(d);
    if (rows.length <= 1) {
      _toast('Tidak ada data pada periode ini');
      return;
    }
    await shareBytes(
      'rms_${name}${_sourceTag}_$_stamp.xlsx',
      _xlsxMime,
      buildXlsx([_sheet(title, rows), _infoSheet(d, title)], headerArgb: AppColors.primaryHex),
    );
  });

  /// Satu file Excel berisi semua laporan (satu sheet per laporan).
  Future<void> _xlsxAll() => _run(() async {
    final d = await _data();
    if (d.soldOrders.isEmpty && expensesRows(d).length <= 1 && stockRows(d).length <= 1) {
      _toast('Tidak ada data pada periode ini');
      return;
    }
    await shareBytes(
      'rms_laporan${_sourceTag}_$_stamp.xlsx',
      _xlsxMime,
      buildXlsx([
        _infoSheet(d, 'Laporan RMS'),
        _sheet('Laba rugi', plRows(d)),
        _sheet('Sumber pesanan', sourceRows(d)),
        _sheet('Penjualan per order', ordersRows(d)),
        _sheet('Penjualan per item', itemsRows(d)),
        _sheet('Biaya', expensesRows(d)),
        _sheet('Mutasi stok', stockRows(d)),
      ], headerArgb: AppColors.primaryHex),
    );
  });

  Future<void> _pdf() => _run(() async {
    final bytes = await buildSummaryPdf(await _data(), _period);
    await shareBytes('rms_ringkasan${_sourceTag}_$_stamp.pdf', 'application/pdf', bytes);
  });

  Future<void> _pdfTransactions() => _run(() async {
    final d = await _data();
    if (d.soldOrders.isEmpty) {
      _toast('Tidak ada transaksi pada periode ini');
      return;
    }
    final bytes = await buildTransactionsPdf(d, _period);
    await shareBytes('rms_transaksi${_sourceTag}_$_stamp.pdf', 'application/pdf', bytes);
  });

  Widget _card(
    IconData icon,
    String title,
    String sub,
    String format,
    VoidCallback onTap, {
    bool pdf = false,
  }) {
    final tone = toneColors(pdf ? Tone.danger : Tone.success); // PDF merah, Excel hijau
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        sub,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(format, tone: pdf ? Tone.danger : Tone.success),
                const SizedBox(width: 6),
                Icon(Icons.ios_share, size: 20, color: AppColors.muted),
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
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _period,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
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
          title: 'Sumber pesanan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final src in <OrderSource?>[null, ...OrderSource.values])
                    ChoiceChip(
                      label: Text(src?.label ?? 'Semua'),
                      selected: _source == src,
                      onSelected: (_) => setState(() => _source = src),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Berlaku untuk data penjualan. Laba rugi selalu dihitung dari semua sumber.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.faint),
              ),
            ],
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
              Icons.table_view_outlined,
              'Laporan lengkap',
              'Semua laporan di bawah dalam satu file Excel',
              'XLSX',
              _xlsxAll,
            ),
            _card(
              Icons.picture_as_pdf_outlined,
              'Ringkasan laporan',
              'Laba rugi, sumber pesanan, metode bayar, menu terlaris',
              'PDF',
              _pdf,
              pdf: true,
            ),
            _card(
              Icons.fact_check_outlined,
              'Daftar transaksi',
              'Untuk arsip & cek silang nomor pesanan online',
              'PDF',
              _pdfTransactions,
              pdf: true,
            ),
            _card(
              Icons.receipt_long,
              'Penjualan per order',
              'Satu baris per transaksi, dengan sumber & no. online',
              'XLSX',
              () => _xlsx('penjualan_order', 'Penjualan per order', ordersRows),
            ),
            _card(
              Icons.list_alt,
              'Penjualan per item',
              'Rincian item terjual',
              'XLSX',
              () => _xlsx('penjualan_item', 'Penjualan per item', itemsRows),
            ),
            _card(
              Icons.payments_outlined,
              'Biaya operasional',
              'Daftar biaya pada periode',
              'XLSX',
              () => _xlsx('biaya', 'Biaya', expensesRows),
            ),
            _card(
              Icons.inventory_2_outlined,
              'Mutasi stok',
              'Belanja, penjualan, waste, opname',
              'XLSX',
              () => _xlsx('mutasi_stok', 'Mutasi stok', stockRows),
            ),
            _card(
              Icons.account_balance_wallet_outlined,
              'Laba rugi',
              'Ringkasan laba rugi',
              'XLSX',
              () => _xlsx('laba_rugi', 'Laba rugi', plRows),
            ),
          ],
        ),
      ],
    );
  }
}


/// Kumpulkan data ekspor untuk rentang [start, end) (juga dipakai tombol Unduh di Laporan).
Future<ExportData> loadExportData(WidgetRef ref, int start, int end, OrderSource? source) async {
  final moves = await loadStockMoves(ref.read(databaseProvider), start: start, end: end);
  return ExportData(
    orders: ref.read(ordersProvider).value ?? <Order>[],
    moves: moves,
    expenses: ref.read(expensesProvider).value ?? <Expense>[],
    ingredients: {for (final i in ref.read(ingredientsProvider).value ?? <Ingredient>[]) i.id: i},
    tables: {for (final t in ref.read(tablesProvider).value ?? <DiningTable>[]) t.id: t.name},
    avgCost: ref.read(avgCostProvider),
    start: start,
    end: end,
    source: source,
  );
}
