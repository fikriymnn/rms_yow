import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'printer_settings.dart';
import 'receipt_builder.dart';

/// Untuk web: PDF berukuran roll sesuai jumlah kolom (±1,5 mm per karakter).
Future<void> printReceiptPdf(List<RLine> lines, PrinterSettings s) async {
  const mm = PdfPageFormat.mm;
  final format = PdfPageFormat(
    (s.cols * 1.5 + 6) * mm,
    double.infinity,
    marginAll: 3 * mm,
  );
  final regular = pw.Font.courier();
  final bold = pw.Font.courierBold();
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            pw.Text(
              l.text.isEmpty ? ' ' : l.text,
              style: pw.TextStyle(font: l.bold ? bold : regular, fontSize: 7.1),
            ),
        ],
      ),
    ),
  );
  await Printing.layoutPdf(format: format, onLayout: (_) => doc.save());
}
