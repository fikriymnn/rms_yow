import 'package:intl/intl.dart';

import '../orders/order_models.dart';
import 'printer_settings.dart';

class RLine {
  const RLine(this.text, {this.bold = false});
  final String text;
  final bool bold;
}

final _num = NumberFormat.decimalPattern('id_ID');
String _n(int v) => _num.format(v);

// karakter non-ASCII diganti '?', printer thermal umumnya tidak mendukungnya
String _ascii(String t) =>
    String.fromCharCodes(t.runes.map((r) => r < 128 ? r : 63));

String _spaces(int n) => n <= 0 ? '' : ' ' * n;

List<String> _wrap(String text, int width) {
  final lines = <String>[];
  var cur = '';
  for (final word in text.split(' ')) {
    if (word.isEmpty) continue;
    var rest = word;
    while (rest.length > width) {
      if (cur.isNotEmpty) {
        lines.add(cur);
        cur = '';
      }
      lines.add(rest.substring(0, width));
      rest = rest.substring(width);
    }
    if (cur.isEmpty) {
      cur = rest;
    } else if (cur.length + 1 + rest.length <= width) {
      cur = '$cur $rest';
    } else {
      lines.add(cur);
      cur = rest;
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  return lines;
}

String _lr(String l, String r, int w) {
  final max = w - r.length - 1;
  final left = (max > 0 && l.length > max) ? l.substring(0, max) : l;
  return left + _spaces(w - left.length - r.length) + r;
}

List<String> _centerWrap(String t, int w) => [
  for (final l in _wrap(t, w)) _spaces((w - l.length) ~/ 2) + l,
];

List<RLine> buildReceipt({
  required Order order,
  required PrinterSettings s,
  String? tableName,
  String? cashier,
  bool copy = false,
}) {
  final w = s.cols;
  final out = <RLine>[];
  void add(String t, {bool bold = false}) =>
      out.add(RLine(_ascii(t), bold: bold));
  void center(String t, {bool bold = false}) {
    for (final l in _centerWrap(t, w)) {
      add(l, bold: bold);
    }
  }

  final line = '-' * w;
  final d = DateTime.fromMillisecondsSinceEpoch(
    order.paidAt ?? order.createdAt,
  );
  final type = order.type == OrderType.takeaway
      ? 'Takeaway'
      : 'Dine-in ${tableName ?? ''}'.trim();

  center(s.shopName, bold: true);
  center(s.shopAddress);
  add(line);
  add('No   : ${order.number}');
  add('Tgl  : ${DateFormat('dd/MM/yy HH:mm').format(d)}');
  add('Tipe : $type');
  if (cashier != null && cashier.isNotEmpty) add('Kasir: $cashier');
  add(line);

  for (final it in order.items) {
    for (final l in _wrap(it.name, w)) {
      add(l);
    }
    add(_lr('  ${it.qty} x ${_n(it.price)}', _n(it.total), w));
    if (it.note.isNotEmpty) {
      for (final l in _wrap('* ${it.note}', w - 2)) {
        add('  $l');
      }
    }
  }
  add(line);

  add(_lr('Subtotal', _n(order.subtotal), w));
  if (order.discount > 0) add(_lr('Diskon', '-${_n(order.discount)}', w));
  if (order.tax > 0) add(_lr('Pajak $kTaxPercent%', _n(order.tax), w));
  if (order.service > 0) {
    add(_lr('Service $kServicePercent%', _n(order.service), w));
  }
  add(_lr('TOTAL', _n(order.total), w), bold: true);
  if (order.payMethod != null) {
    add(
      _lr(
        'Bayar (${order.payMethod!.name.toUpperCase()})',
        _n(order.paidAmount),
        w,
      ),
    );
    if (order.payMethod == PayMethod.cash && order.paidAmount > order.total) {
      add(_lr('Kembali', _n(order.paidAmount - order.total), w));
    }
  }
  add(line);
  if (order.status == OrderStatus.refunded)
    center('*** REFUND ***', bold: true);
  if (copy) center('*** SALINAN ***', bold: true);
  center(s.footer);
  return out;
}

/// Struk uji: penggaris angka untuk memeriksa lebar kolom.
List<RLine> testLines(PrinterSettings s) {
  final w = s.cols;
  final ruler = List.generate(w, (i) => '${(i + 1) % 10}').join();
  return [
    for (final l in _centerWrap('TES CETAK', w)) RLine(l, bold: true),
    for (final l in _centerWrap(s.shopName, w)) RLine(_ascii(l)),
    RLine('-' * w),
    RLine(ruler),
    RLine('-' * w),
    RLine(_lr('Contoh item', '10.000', w)),
    RLine(_lr('TOTAL', '10.000', w), bold: true),
    RLine('Lebar: $w karakter'),
    for (final l in _centerWrap(s.footer, w)) RLine(_ascii(l)),
  ];
}
