import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'printer_settings.dart';
import 'receipt_builder.dart';

Future<List<int>> receiptToEscPos(List<RLine> lines, PrinterSettings s) async {
  final profile = await CapabilityProfile.load();
  final g = Generator(s.cols >= 40 ? PaperSize.mm80 : PaperSize.mm58, profile);
  final bytes = <int>[];
  bytes.addAll(g.reset());
  for (final l in lines) {
    bytes.addAll(g.text(l.text, styles: PosStyles(bold: l.bold)));
  }
  bytes.addAll(g.feed(3));
  bytes.addAll(g.cut());
  return bytes;
}
