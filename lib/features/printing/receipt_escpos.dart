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
  // Catatan: g.cut() bawaan esc_pos_utils selalu memajukan 5 baris kosong dulu, ditambah
  // feed sebelumnya = kertas kosong panjang di printer tanpa pemotong. Kirim perintah sendiri.
  if (s.autoCut) {
    bytes.addAll(const [0x1D, 0x56, 0x42, 0x00]); // GS V 66 0: maju ke posisi potong lalu potong
  } else if (s.feedLines > 0) {
    bytes.addAll([0x1B, 0x64, s.feedLines]); // ESC d n: maju n baris agar melewati sisi sobek
  }
  return bytes;
}
