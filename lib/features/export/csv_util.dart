import 'dart:convert';

String _num(double d) {
  var t = d.toStringAsFixed(4);
  t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return t.isEmpty ? '0' : t;
}

String csvCell(Object? v, String sep) {
  if (v == null) return '';
  var s = v is double ? _num(v) : v.toString();
  if (v is double && sep == ';')
    s = s.replaceAll('.', ','); // desimal Excel Indonesia
  // cegah formula injection di spreadsheet (=, +, -, @ di awal teks)
  if (v is String && s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
  if (s.contains(sep) ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    s = '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// UTF-8 + BOM agar Excel membaca karakter dengan benar.
List<int> toCsvBytes(List<List<Object?>> rows, {String sep = ';'}) {
  final text = rows
      .map((r) => r.map((c) => csvCell(c, sep)).join(sep))
      .join('\r\n');
  return [0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
}
