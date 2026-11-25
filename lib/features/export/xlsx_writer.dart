/// Penulis file Excel (.xlsx) mandiri: tanpa paket tambahan dan jalan di Android maupun web.
///
/// Fitur yang dipakai laporan: beberapa sheet, baris judul tebal berwarna + beku + filter,
/// angka ribuan (1.250.000), tanggal-jam asli Excel, lebar kolom otomatis.
/// Nilai sel: String, int, double, DateTime, bool, atau null (kosong).
library;

import 'dart:convert';
import 'dart:typed_data';

class XlsxSheet {
  XlsxSheet(this.name, this.rows, {this.headerRows = 1, this.boldRows = const {}});

  /// Nama sheet (maks. 31 karakter, tanpa : \ / ? * [ ]).
  final String name;
  final List<List<Object?>> rows;

  /// Baris judul kolom (tebal, berwarna, dibekukan, diberi filter). 0 = tanpa judul.
  final int headerRows;

  /// Indeks baris (0-based) yang ditebalkan, mis. baris total.
  final Set<int> boldRows;
}

/// [headerArgb] = warna latar judul kolom, mis. 'FF7D0B1E' (ikut tema aplikasi).
Uint8List buildXlsx(List<XlsxSheet> sheets, {String headerArgb = 'FF7D0B1E'}) {
  final used = <String>{};
  String safeName(String n) {
    var s = n.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (s.isEmpty) s = 'Sheet';
    if (s.length > 31) s = s.substring(0, 31);
    var out = s;
    for (var i = 2; !used.add(out.toLowerCase()); i++) {
      final suffix = ' ($i)';
      out = (s.length + suffix.length > 31 ? s.substring(0, 31 - suffix.length) : s) + suffix;
    }
    return out;
  }

  final names = [for (final s in sheets) safeName(s.name)];
  final files = <String, String>{
    '[Content_Types].xml': _contentTypes(sheets.length),
    '_rels/.rels': _rootRels,
    'xl/workbook.xml': _workbook(names),
    'xl/_rels/workbook.xml.rels': _workbookRels(sheets.length),
    'xl/styles.xml': _styles.replaceFirst('FF7D0B1E', headerArgb),
    for (var i = 0; i < sheets.length; i++) 'xl/worksheets/sheet${i + 1}.xml': _sheet(sheets[i]),
  };
  return _zipStored({for (final e in files.entries) e.key: utf8.encode(e.value)});
}

// --------------------------------------------------------------------------- isi XML

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // karakter kontrol tidak sah di XML
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _col(int i) {
  var n = i + 1, s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Tanggal Excel = jumlah hari sejak 30 Des 1899 (jam lokal apa adanya).
double _serial(DateTime d) {
  final local = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  return local.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;
}

// gaya (cellXfs): 0 biasa, 1 judul kolom, 2 angka ribuan, 3 tanggal-jam, 4 teks tebal,
// 5 angka ribuan tebal, 6 angka desimal, 7 angka desimal tebal
String _cell(String ref, Object? v, {required bool header, required bool bold}) {
  if (v == null || (v is String && v.isEmpty)) return '';
  if (v is DateTime) return '<c r="$ref" s="3"><v>${_serial(v)}</v></c>';
  if (v is num && !header) {
    if (v.isNaN || v.isInfinite) return '';
    final whole = v is int || v == v.roundToDouble();
    final s = whole ? (bold ? 5 : 2) : (bold ? 7 : 6);
    final text = whole ? v.round().toString() : v.toString();
    return '<c r="$ref" s="$s"><v>$text</v></c>';
  }
  if (v is bool) return '<c r="$ref" t="b"><v>${v ? 1 : 0}</v></c>';
  final s = header ? 1 : (bold ? 4 : 0);
  return '<c r="$ref" t="inlineStr" s="$s"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>';
}

String _sheet(XlsxSheet sh) {
  final cols = sh.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  // lebar kolom dari isi terpanjang (dibatasi agar tetap rapi)
  final widths = List<double>.filled(cols, 8);
  for (final r in sh.rows) {
    for (var c = 0; c < r.length; c++) {
      final v = r[c];
      final len = v == null
          ? 0
          : v is DateTime
          ? 16
          : v is num
          ? (v.abs() >= 1000 ? v.round().toString().length * 1.35 : v.toString().length.toDouble())
          : '$v'.length.toDouble();
      if (len + 2 > widths[c]) widths[c] = (len + 2).clamp(8, 60).toDouble();
    }
  }
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  if (sh.headerRows > 0 && sh.rows.length > sh.headerRows) {
    b.write(
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="${sh.headerRows}" '
      'topLeftCell="A${sh.headerRows + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>',
    );
  }
  if (cols > 0) {
    b.write('<cols>');
    for (var c = 0; c < cols; c++) {
      b.write('<col min="${c + 1}" max="${c + 1}" width="${widths[c].toStringAsFixed(1)}" customWidth="1"/>');
    }
    b.write('</cols>');
  }
  b.write('<sheetData>');
  for (var r = 0; r < sh.rows.length; r++) {
    final header = r < sh.headerRows;
    final bold = sh.boldRows.contains(r);
    b.write('<row r="${r + 1}">');
    final row = sh.rows[r];
    for (var c = 0; c < row.length; c++) {
      b.write(_cell('${_col(c)}${r + 1}', row[c], header: header, bold: bold));
    }
    b.write('</row>');
  }
  b.write('</sheetData>');
  if (sh.headerRows > 0 && cols > 0 && sh.rows.length > sh.headerRows) {
    b.write('<autoFilter ref="A${sh.headerRows}:${_col(cols - 1)}${sh.rows.length}"/>');
  }
  b.write('<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>');
  b.write('</worksheet>');
  return b.toString();
}

String _contentTypes(int n) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
    ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
    ..write('<Default Extension="xml" ContentType="application/xml"/>')
    ..write(
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    )
    ..write(
      '<Override PartName="/xl/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    );
  for (var i = 1; i <= n; i++) {
    b.write(
      '<Override PartName="/xl/worksheets/sheet$i.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
  }
  b.write('</Types>');
  return b.toString();
}

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/></Relationships>';

String _workbook(List<String> names) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>',
    );
  for (var i = 0; i < names.length; i++) {
    b.write('<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
  }
  b.write('</sheets>');
  // nama tersembunyi untuk filter otomatis tiap sheet
  b.write('</workbook>');
  return b.toString();
}

String _workbookRels(int n) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
  for (var i = 1; i <= n; i++) {
    b.write(
      '<Relationship Id="rId$i" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$i.xml"/>',
    );
  }
  b.write(
    '<Relationship Id="rId${n + 1}" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
  );
  b.write('</Relationships>');
  return b.toString();
}

const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="2">'
    '<numFmt numFmtId="164" formatCode="dd/mm/yyyy hh:mm"/>'
    '<numFmt numFmtId="165" formatCode="#,##0.00"/>'
    '</numFmts>'
    '<fonts count="3">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF7D0B1E"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="8">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
    '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="3" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

// --------------------------------------------------------------------------- ZIP (tanpa kompresi)

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

Uint8List _zipStored(Map<String, List<int>> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  final now = DateTime.now();
  final dosTime = (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2);
  final dosDate = ((now.year - 1980) << 9) | (now.month << 5) | now.day;

  void u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

  var count = 0;
  for (final e in files.entries) {
    final name = utf8.encode(e.key);
    final data = e.value;
    final crc = _crc32(data);
    final offset = out.length;
    // header lokal
    u32(out, 0x04034b50);
    u16(out, 20);
    u16(out, 0x0800); // nama UTF-8
    u16(out, 0); // tanpa kompresi
    u16(out, dosTime);
    u16(out, dosDate);
    u32(out, crc);
    u32(out, data.length);
    u32(out, data.length);
    u16(out, name.length);
    u16(out, 0);
    out.add(name);
    out.add(data);
    // direktori pusat
    u32(central, 0x02014b50);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0x0800);
    u16(central, 0);
    u16(central, dosTime);
    u16(central, dosDate);
    u32(central, crc);
    u32(central, data.length);
    u32(central, data.length);
    u16(central, name.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, offset);
    central.add(name);
    count++;
  }
  final cdOffset = out.length;
  final cd = central.takeBytes();
  out.add(cd);
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, count);
  u16(out, count);
  u32(out, cd.length);
  u32(out, cdOffset);
  u16(out, 0);
  return out.takeBytes();
}
