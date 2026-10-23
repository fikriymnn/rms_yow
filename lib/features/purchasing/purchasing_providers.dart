import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/local_first_repository.dart';
import '../auth/auth_providers.dart';
import '../finance/expense.dart';
import '../finance/finance_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../shifts/shift_providers.dart';
import 'purchasing_models.dart';

class SupplierRepository extends LocalFirstRepository<Supplier> {
  SupplierRepository(super.ref);
  @override
  String get collection => 'suppliers';
  @override
  Supplier fromMap(Map<String, dynamic> m) => Supplier.fromMap(m);
  @override
  Map<String, dynamic> toMap(Supplier s) => s.toMap();
  @override
  String idOf(Supplier s) => s.id;
}

class PoRepository extends LocalFirstRepository<PurchaseOrder> {
  PoRepository(super.ref);
  @override
  String get collection => 'purchase_orders';
  @override
  PurchaseOrder fromMap(Map<String, dynamic> m) => PurchaseOrder.fromMap(m);
  @override
  Map<String, dynamic> toMap(PurchaseOrder p) => p.toMap();
  @override
  String idOf(PurchaseOrder p) => p.id;
}

class ReceiptRepository extends LocalFirstRepository<GoodsReceipt> {
  ReceiptRepository(super.ref);
  @override
  String get collection => 'goods_receipts';
  @override
  GoodsReceipt fromMap(Map<String, dynamic> m) => GoodsReceipt.fromMap(m);
  @override
  Map<String, dynamic> toMap(GoodsReceipt g) => g.toMap();
  @override
  String idOf(GoodsReceipt g) => g.id;
}

class SupplierPaymentRepository extends LocalFirstRepository<SupplierPayment> {
  SupplierPaymentRepository(super.ref);
  @override
  String get collection => 'supplier_payments';
  @override
  SupplierPayment fromMap(Map<String, dynamic> m) => SupplierPayment.fromMap(m);
  @override
  Map<String, dynamic> toMap(SupplierPayment p) => p.toMap();
  @override
  String idOf(SupplierPayment p) => p.id;
}

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => SupplierRepository(ref),
);
final poRepositoryProvider = Provider<PoRepository>((ref) => PoRepository(ref));
final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(ref),
);
final supplierPaymentRepositoryProvider = Provider<SupplierPaymentRepository>(
  (ref) => SupplierPaymentRepository(ref),
);

final suppliersProvider = StreamProvider<List<Supplier>>(
  (ref) => ref
      .watch(supplierRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      ),
);

final purchaseOrdersProvider = StreamProvider<List<PurchaseOrder>>(
  (ref) => ref
      .watch(poRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
);

final receiptsProvider = StreamProvider<List<GoodsReceipt>>(
  (ref) => ref
      .watch(receiptRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.at.compareTo(a.at))),
);

final supplierPaymentsProvider = StreamProvider<List<SupplierPayment>>(
  (ref) => ref
      .watch(supplierPaymentRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.at.compareTo(a.at))),
);

/// poId -> (ingredientId -> jumlah diterima, satuan beli)
final receivedByPoProvider = Provider<Map<String, Map<String, double>>>((ref) {
  final m = <String, Map<String, double>>{};
  for (final r in ref.watch(receiptsProvider).value ?? <GoodsReceipt>[]) {
    final inner = m.putIfAbsent(r.poId, () => <String, double>{});
    for (final l in r.lines) {
      inner[l.ingredientId] = (inner[l.ingredientId] ?? 0) + l.qty;
    }
  }
  return m;
});

/// supplierId -> hutang (penerimaan - pembayaran)
final supplierBalanceProvider = Provider<Map<String, int>>((ref) {
  final m = <String, int>{};
  for (final r in ref.watch(receiptsProvider).value ?? <GoodsReceipt>[]) {
    m[r.supplierId] = (m[r.supplierId] ?? 0) + r.total;
  }
  for (final p
      in ref.watch(supplierPaymentsProvider).value ?? <SupplierPayment>[]) {
    m[p.supplierId] = (m[p.supplierId] ?? 0) - p.amount;
  }
  return m;
});

String newNumber(String prefix) =>
    '$prefix-${DateFormat('yyMMdd').format(DateTime.now())}-'
    '${const Uuid().v4().substring(0, 4).toUpperCase()}';

/// Catat pembayaran ke supplier. Jika dari kas laci, otomatis membuat
/// pengeluaran kas (kategori pembelian, tidak masuk laba rugi).
Future<void> recordSupplierPayment(
  WidgetRef ref, {
  required String supplierId,
  required String supplierName,
  required int amount,
  String note = '',
  bool fromDrawer = false,
}) async {
  final user = ref.read(appUserProvider).value;
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = const Uuid().v4();
  await ref
      .read(supplierPaymentRepositoryProvider)
      .save(
        SupplierPayment(
          id: id,
          supplierId: supplierId,
          supplierName: supplierName,
          amount: amount,
          at: now,
          note: note,
          fromDrawer: fromDrawer,
          userName: user?.name ?? '',
        ),
      );
  if (fromDrawer) {
    final shift = await resolveCurrentShift(ref);
    await ref
        .read(expenseRepositoryProvider)
        .save(
          Expense(
            id: 'pay_$id',
            category: kPurchaseCategory,
            amount: amount,
            at: now,
            note: 'Bayar $supplierName',
            fromDrawer: true,
            shiftId: shift?.id,
            userName: user?.name ?? '',
          ),
        );
  }
}

/// Terima barang: buat penerimaan, mutasi stok masuk (dengan harga beli),
/// pembayaran (opsional), dan tutup PO jika semua item sudah diterima.
Future<void> receiveGoods(
  WidgetRef ref, {
  required PurchaseOrder po,
  required List<PoLine> received,
  required Map<String, double> receivedBefore,
  String invoiceNo = '',
  int paidNow = 0,
  bool fromDrawer = false,
}) async {
  final user = ref.read(appUserProvider).value;
  final gr = GoodsReceipt(
    id: const Uuid().v4(),
    number: newNumber('GR'),
    poId: po.id,
    supplierId: po.supplierId,
    supplierName: po.supplierName,
    at: DateTime.now().millisecondsSinceEpoch,
    lines: received,
    invoiceNo: invoiceNo,
    userName: user?.name ?? '',
  );
  await ref.read(receiptRepositoryProvider).save(gr);

  if (paidNow > 0) {
    await recordSupplierPayment(
      ref,
      supplierId: po.supplierId,
      supplierName: po.supplierName,
      amount: paidNow,
      note: 'Pembayaran ${gr.number}',
      fromDrawer: fromDrawer,
    );
  }

  final done = po.lines.every((l) {
    final now = received
        .where((r) => r.ingredientId == l.ingredientId)
        .fold<double>(0, (s, r) => s + r.qty);
    return (receivedBefore[l.ingredientId] ?? 0) + now >= l.qty - 0.0001;
  });
  if (done) {
    await ref
        .read(poRepositoryProvider)
        .save(po.copyWith(status: PoStatus.closed));
  }
}
