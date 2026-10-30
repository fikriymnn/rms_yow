import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';

/// Meja yang tetap terisi walau pesanannya sudah dibayar
/// (mis. food court: bayar di muka, pelanggan masih makan di meja).
class TableHold {
  const TableHold({
    required this.id, // = id pesanan yang dibayar
    required this.tableId,
    required this.orderNumber,
    required this.createdAt,
    this.releasedAt,
  });
  final String id;
  final String tableId;
  final String orderNumber;
  final int createdAt;
  final int? releasedAt;

  bool get active => releasedAt == null;

  TableHold release() => TableHold(
    id: id,
    tableId: tableId,
    orderNumber: orderNumber,
    createdAt: createdAt,
    releasedAt: DateTime.now().millisecondsSinceEpoch,
  );

  factory TableHold.fromMap(Map<String, dynamic> m) => TableHold(
    id: m['id'] as String,
    tableId: m['tableId'] as String? ?? '',
    orderNumber: m['orderNumber'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    releasedAt: (m['releasedAt'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'tableId': tableId,
    'orderNumber': orderNumber,
    'createdAt': createdAt,
    'releasedAt': releasedAt,
  };
}

class TableHoldRepository extends LocalFirstRepository<TableHold> {
  TableHoldRepository(super.ref);
  @override
  String get collection => 'table_holds';
  @override
  TableHold fromMap(Map<String, dynamic> m) => TableHold.fromMap(m);
  @override
  Map<String, dynamic> toMap(TableHold h) => h.toMap();
  @override
  String idOf(TableHold h) => h.id;
}

final tableHoldRepositoryProvider = Provider<TableHoldRepository>(
  (ref) => TableHoldRepository(ref),
);

final tableHoldsProvider = StreamProvider<List<TableHold>>(
  (ref) => ref.watch(tableHoldRepositoryProvider).watchAll(),
);

/// Hanya yang masih aktif (belum dikosongkan).
final activeHoldsProvider = Provider<List<TableHold>>(
  (ref) => [
    for (final h in ref.watch(tableHoldsProvider).value ?? <TableHold>[])
      if (h.active) h,
  ],
);

/// Atur status meja sesudah pembayaran. [hold] = pelanggan masih di meja.
/// Status "sudah bayar" lama di meja yang sama dilepas.
Future<void> applyTableHold(
  WidgetRef ref, {
  required String tableId,
  required String orderId,
  required String orderNumber,
  required bool hold,
}) async {
  final repo = ref.read(tableHoldRepositoryProvider);
  for (final h in ref.read(activeHoldsProvider)) {
    if (h.tableId == tableId && h.id != orderId) await repo.save(h.release());
  }
  if (hold) {
    await repo.save(
      TableHold(
        id: orderId,
        tableId: tableId,
        orderNumber: orderNumber,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
