import 'package:intl/intl.dart';

final rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _q = NumberFormat('#,##0.##', 'id_ID');

/// Untuk tampilan: 1.250,5
String qtyText(double v) => _q.format(v);

/// Untuk isi awal field input: 1250.5
String qtyPlain(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Terima "1,5" atau "1.5". Jangan pakai pemisah ribuan.
double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
