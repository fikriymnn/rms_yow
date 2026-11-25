import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../attendance/attendance_models.dart';
import 'payroll_models.dart';

String _qty(PayLine l) {
  final q = l.qty;
  if (q == null) return '';
  final qs = q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2).replaceAll('.', ',');
  if (l.rate != null) return '$qs × ${rupiah.format(l.rate)}';
  return switch (l.id) {
    'auto_overtime' => '$qs jam disetujui', // bonus lembur: nominal dari persetujuan absensi
    'auto_late' => '${qs}x terlambat',
    _ => '',
  };
}

/// Isi slip gaji (dipakai pengelola dan karyawan).
class PayslipView extends StatelessWidget {
  const PayslipView({super.key, required this.slip, this.period, this.outlet});
  final Payslip slip;
  final String? period;
  final String? outlet;

  Widget _section(String title, List<PayLine> lines, {required bool earning}) {
    final total = lines.fold<int>(0, (s, l) => s + l.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: .4),
        ),
        const SizedBox(height: 6),
        if (lines.isEmpty)
          Text('–', style: GoogleFonts.plusJakartaSans(color: AppColors.muted)),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (_qty(l).isNotEmpty)
                        Text(_qty(l), style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Text(
                  '${earning ? '' : '− '}${rupiah.format(l.amount)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: earning ? AppColors.ink : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 18),
        Row(
          children: [
            Expanded(child: Text('Total ${title.toLowerCase()}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
            Text(
              '${earning ? '' : '− '}${rupiah.format(total)}',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: earning ? AppColors.ink : AppColors.danger),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = slip;
    Widget chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Text(t, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.userName, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(
            [
              if (s.position.isNotEmpty) s.position,
              kSchemeLabels[s.scheme] ?? s.scheme,
              ?outlet,
            ].join(' • '),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted),
          ),
          if (period != null) ...[
            const SizedBox(height: 2),
            Text('Periode $period', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('${s.days} hari hadir'),
              chip(durationText(s.minutes)),
              if (s.lateCount > 0) chip('${s.lateCount}× terlambat'),
              if (s.overtimeMinutes > 0) chip('Lembur ${durationText(s.overtimeMinutes)}'),
            ],
          ),
          const SizedBox(height: 18),
          _section('Pendapatan', s.lines.where((l) => l.isEarning).toList(), earning: true),
          const SizedBox(height: 18),
          _section('Potongan', s.lines.where((l) => !l.isEarning).toList(), earning: false),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Text('Gaji diterima', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text(
                  rupiah.format(s.net),
                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
          ),
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Catatan: ${s.note}', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// Bagikan / simpan slip gaji sebagai PDF.
Future<void> sharePayslipPdf(Payslip s, {String? period, String? outlet}) async {
  final doc = pw.Document();
  String rp(int v) => rupiah.format(v);
  pw.Widget row(String a, String b, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(a, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null))),
        pw.Text(b, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
      ],
    ),
  );
  final earn = s.lines.where((l) => l.isEarning).toList();
  final ded = s.lines.where((l) => !l.isEarning).toList();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SLIP GAJI', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(AppColors.primary.toARGB32()))),
          if (outlet != null) pw.Text(outlet),
          if (period != null) pw.Text('Periode $period'),
          pw.SizedBox(height: 10),
          pw.Text(s.userName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text([if (s.position.isNotEmpty) s.position, kSchemeLabels[s.scheme] ?? s.scheme].join(' - ')),
          pw.Text('Hadir ${s.days} hari, ${durationText(s.minutes)}'
              '${s.lateCount > 0 ? ', terlambat ${s.lateCount}x' : ''}'
              '${s.overtimeMinutes > 0 ? ', lembur ${durationText(s.overtimeMinutes)}' : ''}'),
          pw.Divider(),
          pw.Text('PENDAPATAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final l in earn) row('${l.label}${_qty(l).isEmpty ? '' : ' (${_qty(l)})'}', rp(l.amount)),
          row('Total pendapatan', rp(s.gross), bold: true),
          pw.SizedBox(height: 8),
          pw.Text('POTONGAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final l in ded) row('${l.label}${_qty(l).isEmpty ? '' : ' (${_qty(l)})'}', '- ${rp(l.amount)}'),
          row('Total potongan', '- ${rp(s.deductions)}', bold: true),
          pw.Divider(),
          row('GAJI DITERIMA', rp(s.net), bold: true),
          if (s.note.isNotEmpty) ...[pw.SizedBox(height: 8), pw.Text('Catatan: ${s.note}')],
        ],
      ),
    ),
  );
  final name = 'slip-gaji-${s.userName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}-${s.periodStart ?? s.runId}.pdf';
  await Printing.sharePdf(bytes: await doc.save(), filename: name);
}
