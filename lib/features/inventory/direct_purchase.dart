import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import '../../core/sync/sync_controller.dart';

/// Belanja langsung tanpa PO (pasar / toko), satu dokumen berisi banyak bahan.
/// Koleksi sinkron `direct_purchases` (per outlet, tidak bisa diubah setelah dicatat).
/// Server membuat stok masuk per baris (id `bl_<belanja>_<baris>`) beserta harga belinya.
class PurchaseLine {
  const PurchaseLine({
    required this.ingredientId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.factor,
    required this.price,
    this.note = '',
  });

  final String ingredientId;
  final String name;
  final double qty; // dalam [unit]
  final String unit; // satuan yang diketik (satuan beli atau dasar)
  final double factor; // 1 [unit] = factor satuan dasar
  final double price; // total harga baris (Rp)
  final String note;

  double get baseQty => qty * factor;

  factory PurchaseLine.fromMap(Map<String, dynamic> m) => PurchaseLine(
    ingredientId: m['ingredientId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    qty: (m['qty'] as num?)?.toDouble() ?? 0,
    unit: m['unit'] as String? ?? '',
    factor: (m['factor'] as num?)?.toDouble() ?? 1,
    price: (m['price'] as num?)?.toDouble() ?? 0,
    note: m['note'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'ingredientId': ingredientId,
    'name': name,
    'qty': qty,
    'unit': unit,
    'factor': factor,
    'price': price,
    'note': note,
  };
}

class DirectPurchase {
  const DirectPurchase({
    required this.id,
    required this.number,
    required this.at,
    required this.lines,
    this.place = '',
    this.note = '',
    this.createdByName = '',
    this.createdAt = 0,
  });

  final String id;
  final String number; // BL-20261126-7F3A
  final int at; // tanggal belanja
  final List<PurchaseLine> lines;
  final String place; // tempat belanja
  final String note; // catatan keseluruhan
  final String createdByName;
  final int createdAt;

  double get total => lines.fold(0, (s, l) => s + l.price);

  factory DirectPurchase.fromMap(Map<String, dynamic> m) => DirectPurchase(
    id: m['id'] as String,
    number: m['number'] as String? ?? '',
    at: (m['at'] as num?)?.toInt() ?? 0,
    lines: [
      for (final e in (m['lines'] as List? ?? const []))
        PurchaseLine.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
    place: m['place'] as String? ?? '',
    note: m['note'] as String? ?? '',
    createdByName: m['createdByName'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'at': at,
    'lines': [for (final l in lines) l.toMap()],
    'place': place,
    'note': note,
    'total': total,
    'createdByName': createdByName,
    'createdAt': createdAt,
  };
}

class DirectPurchaseRepository extends LocalFirstRepository<DirectPurchase> {
  DirectPurchaseRepository(super.ref);
  @override
  String get collection => 'direct_purchases';
  @override
  DirectPurchase fromMap(Map<String, dynamic> m) => DirectPurchase.fromMap(m);
  @override
  Map<String, dynamic> toMap(DirectPurchase p) => p.toMap();
  @override
  String idOf(DirectPurchase p) => p.id;
}

final directPurchaseRepositoryProvider = Provider<DirectPurchaseRepository>(
  (ref) => DirectPurchaseRepository(ref),
);

/// Id belanja yang belum diterima server (stok baru bertambah setelah diterima).
final unsyncedPurchasesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).watchDirtyIds('direct_purchases'),
);

/// Riwayat belanja langsung outlet aktif, terbaru dulu.
final directPurchasesProvider = StreamProvider<List<DirectPurchase>>(
  (ref) => ref
      .watch(directPurchaseRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.at.compareTo(a.at))),
);
