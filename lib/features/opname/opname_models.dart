/// Stok opname berbasis tiket (koleksi sinkron `stock_opnames`, per outlet).
///
/// Alur: buat tiket (tanggal) -> isi stok fisik tiap bahan (disimpan dulu di perangkat)
/// -> kirim. Server menghitung stok sistem saat tiket diterima, mencatat selisihnya sebagai
/// mutasi "opname", lalu mengisi [OpnameItem.system]/[OpnameItem.diff] dan [StockOpname.processedAt].
library;

enum OpnameStatus {
  open('Berjalan'),
  submitted('Selesai'),
  cancelled('Dibatalkan');

  const OpnameStatus(this.label);
  final String label;
}

double? _dn(Object? v) => v is num ? v.toDouble() : null;

class OpnameItem {
  const OpnameItem({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.actual,
    this.note = '',
    this.system,
    this.diff,
  });

  final String ingredientId;
  final String name;
  final String unit;
  final double actual; // stok fisik (satuan dasar)
  final String note;
  final double? system; // stok sistem menurut server (null = belum diproses)
  final double? diff; // actual - system

  factory OpnameItem.fromMap(Map<String, dynamic> m) => OpnameItem(
    ingredientId: m['ingredientId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    unit: m['unit'] as String? ?? '',
    actual: _dn(m['actual']) ?? 0,
    note: m['note'] as String? ?? '',
    system: _dn(m['system']),
    diff: _dn(m['diff']),
  );

  Map<String, dynamic> toMap() => {
    'ingredientId': ingredientId,
    'name': name,
    'unit': unit,
    'actual': actual,
    'note': note,
    if (system != null) 'system': system,
    if (diff != null) 'diff': diff,
  };
}

class StockOpname {
  const StockOpname({
    required this.id,
    required this.number,
    required this.date,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.note = '',
    this.items = const [],
    this.submittedByName = '',
    this.submittedAt,
    this.cancelledByName = '',
    this.cancelledAt,
    this.processedAt,
  });

  final String id;
  final String number; // OPN-20261121-7F3A
  final String date; // YYYY-MM-DD
  final OpnameStatus status;
  final String createdBy;
  final String createdByName;
  final int createdAt;
  final String note;
  final List<OpnameItem> items; // terisi saat dikirim
  final String submittedByName;
  final int? submittedAt;
  final String cancelledByName;
  final int? cancelledAt;
  final int? processedAt; // diisi server setelah stok disesuaikan

  bool get isOpen => status == OpnameStatus.open;

  /// Sudah dikirim tapi ringkasan server belum diterima perangkat ini.
  bool get awaitingServer => status == OpnameStatus.submitted && processedAt == null;

  int get diffCount => items.where((i) => (i.diff ?? 0).abs() > 1e-6).length;

  factory StockOpname.fromMap(Map<String, dynamic> m) => StockOpname(
    id: m['id'] as String,
    number: m['number'] as String? ?? '',
    date: m['date'] as String? ?? '',
    status: OpnameStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => OpnameStatus.open,
    ),
    createdBy: m['createdBy'] as String? ?? '',
    createdByName: m['createdByName'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    note: m['note'] as String? ?? '',
    items: [
      for (final e in (m['items'] as List? ?? const []))
        OpnameItem.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
    submittedByName: m['submittedByName'] as String? ?? '',
    submittedAt: (m['submittedAt'] as num?)?.toInt(),
    cancelledByName: m['cancelledByName'] as String? ?? '',
    cancelledAt: (m['cancelledAt'] as num?)?.toInt(),
    processedAt: (m['processedAt'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'date': date,
    'status': status.name,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': createdAt,
    'note': note,
    'items': [for (final i in items) i.toMap()],
    if (submittedByName.isNotEmpty) 'submittedByName': submittedByName,
    if (submittedAt != null) 'submittedAt': submittedAt,
    if (cancelledByName.isNotEmpty) 'cancelledByName': cancelledByName,
    if (cancelledAt != null) 'cancelledAt': cancelledAt,
    if (processedAt != null) 'processedAt': processedAt,
  };

  StockOpname copyWith({
    OpnameStatus? status,
    List<OpnameItem>? items,
    String? submittedByName,
    int? submittedAt,
    String? cancelledByName,
    int? cancelledAt,
  }) => StockOpname(
    id: id,
    number: number,
    date: date,
    status: status ?? this.status,
    createdBy: createdBy,
    createdByName: createdByName,
    createdAt: createdAt,
    note: note,
    items: items ?? this.items,
    submittedByName: submittedByName ?? this.submittedByName,
    submittedAt: submittedAt ?? this.submittedAt,
    cancelledByName: cancelledByName ?? this.cancelledByName,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    processedAt: processedAt,
  );
}

/// Hitungan yang disimpan di perangkat (belum dikirim). Teks mentah agar input tidak berubah.
class OpnameCount {
  const OpnameCount({this.actual = '', this.note = ''});
  final String actual;
  final String note;

  bool get isEmpty => actual.trim().isEmpty && note.trim().isEmpty;

  factory OpnameCount.fromMap(Map<String, dynamic> m) =>
      OpnameCount(actual: m['a'] as String? ?? '', note: m['n'] as String? ?? '');

  Map<String, dynamic> toMap() => {'a': actual, 'n': note};
}
