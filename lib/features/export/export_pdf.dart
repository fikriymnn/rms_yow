import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import 'export_builders.dart';

/// Ringkasan: laba rugi, penjualan per metode bayar, biaya, menu terlaris.
Future<Uint8List> buildSummaryPdf(ExportData d, String periodLabel) async {
  final p = profitLossOf(d);
  final sold = d.soldOrders;

  final byMethod = <String, int>{};
  final qty = <String, int>{};
  final rev = <String, int>{};
  for (final o in sold) {
    final m = (o.payMethod?.name ?? 'other').toUpperCase();
    byMethod[m] = (byMethod[m] ?? 0) + o.total;
    for (final it in o.items) {
      qty[it.name] = (qty[it.name] ?? 0) + it.qty;
      rev[it.name] = (rev[it.name] ?? 0) + it.total;
    }
  }
  final top = (rev.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(10)
      .toList();
  final opex = p.opex.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  pw.Widget kv(String k, String v, {bool bold = false, double indent = 0}) {
    final st = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(indent, 2, 0, 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: st),
          pw.Text(v, style: st),
        ],
      ),
    );
  }

  pw.Widget h(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
    child: pw.Text(
      t,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Halaman ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (_) => [
        pw.Text(
          'Laporan Ringkasan',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(periodLabel),
        pw.Text(
          'Dibuat ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Divider(),
        h('Laba rugi'),
        kv('Jumlah order', '${p.orderCount}'),
        kv('Penjualan (sebelum pajak)', rupiah.format(p.revenue)),
        if (p.refunds > 0) kv('Refund', rupiah.format(-p.refunds)),
        kv('Penjualan bersih', rupiah.format(p.netRevenue), bold: true),
        kv('HPP (bahan terjual)', rupiah.format(-p.cogs)),
        kv(
          'Laba kotor (${p.grossMarginPct.toStringAsFixed(1)}%)',
          rupiah.format(p.grossProfit),
          bold: true,
        ),
        kv('Waste & selisih stok', rupiah.format(-p.shrink)),
        kv('Biaya operasional', rupiah.format(-p.opexTotal)),
        for (final e in opex) kv(e.key, rupiah.format(-e.value), indent: 14),
        pw.Divider(),
        kv('Laba bersih', rupiah.format(p.netProfit), bold: true),
        if (byMethod.isNotEmpty)
          h('Penjualan per metode bayar (termasuk pajak)'),
        for (final e in byMethod.entries) kv(e.key, rupiah.format(e.value)),
        if (top.isNotEmpty) h('Menu terlaris'),
        for (final e in top)
          kv('${e.key}  (${qty[e.key]}x)', rupiah.format(e.value)),
        pw.SizedBox(height: 16),
        pw.Text(
          'Pajak (PB1) tidak dihitung sebagai pendapatan. HPP memakai harga beli '
          'rata-rata saat ini. Biaya dicatat sesuai tanggal input (basis kas).',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return doc.save();
}
