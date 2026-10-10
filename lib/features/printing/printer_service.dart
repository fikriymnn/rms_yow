import 'package:flutter/foundation.dart' show kIsWeb;

import '../orders/order_models.dart';
import 'printer_settings.dart';
import 'receipt_builder.dart';
import 'receipt_escpos.dart';
import 'receipt_pdf.dart';
import 'printer_web.dart' if (dart.library.io) 'printer_io.dart' as transport;

export 'printer_web.dart'
    if (dart.library.io) 'printer_io.dart'
    show pairedPrinters;

Future<void> printLines(PrinterSettings s, List<RLine> lines) async {
  if (kIsWeb) {
    await printReceiptPdf(lines, s);
    return;
  }
  await transport.printBytes(s, await receiptToEscPos(lines, s));
}

Future<void> printOrderReceipt({
  required PrinterSettings settings,
  required Order order,
  String? tableName,
  String? cashier,
  bool copy = false,
}) => printLines(
  settings,
  buildReceipt(
    order: order,
    s: settings,
    tableName: tableName,
    cashier: cashier,
    copy: copy,
  ),
);
