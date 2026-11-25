import '../finance/expense.dart';
import '../finance/profit_loss.dart';
import '../inventory/inventory_models.dart';
import '../orders/order_models.dart';

/// Tanggal sebagai DateTime asli (di Excel bisa diurutkan & difilter); kosong bila 0.
DateTime? _t(int ms) => ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);

class ExportData {
  const ExportData({
    required this.orders,
    required this.moves,
    required this.expenses,
    required this.ingredients,
    required this.tables,
    required this.avgCost,
    required this.start,
    required this.end,
    this.source,
  });

  final List<Order> orders;
  final List<StockMove> moves;
  final List<Expense> expenses;
  final Map<String, Ingredient> ingredients;
  final Map<String, String> tables;
  final Map<String, double> avgCost;
  final int start; // inklusif
  final int end; // eksklusif

  /// Filter sumber pesanan untuk data penjualan (null = semua). Laba rugi selalu semua sumber,
  /// karena biaya & HPP tidak bisa dipisah per sumber.
  final OrderSource? source;

  String get sourceLabel => source?.label ?? 'Semua sumber';

  bool inRange(int t) => t >= start && t < end;

  List<Order> get soldOrders =>
      orders
          .where(
            (o) =>
                (o.status == OrderStatus.paid ||
                    o.status == OrderStatus.refunded) &&
                inRange(o.paidAt ?? 0) &&
                (source == null || o.source == source),
          )
          .toList()
        ..sort((a, b) => (a.paidAt ?? 0).compareTo(b.paidAt ?? 0));

  /// Penjualan per sumber (tanpa filter sumber), untuk ringkasan.
  Map<OrderSource, ({int n, int total})> get bySource {
    final m = <OrderSource, ({int n, int total})>{};
    for (final o in orders) {
      if ((o.status != OrderStatus.paid && o.status != OrderStatus.refunded) || !inRange(o.paidAt ?? 0)) {
        continue;
      }
      final c = m[o.source] ?? (n: 0, total: 0);
      m[o.source] = (n: c.n + 1, total: c.total + o.total);
    }
    return m;
  }
}

List<List<Object?>> ordersRows(ExportData d) => _withTotal(_ordersRows(d), const {
  'Subtotal',
  'Diskon',
  'Pajak',
  'Service',
  'Total',
});

/// Tambah baris TOTAL di bawah untuk kolom-kolom angka yang disebut.
List<List<Object?>> _withTotal(List<List<Object?>> rows, Set<String> sumCols) {
  if (rows.length <= 1) return rows;
  final head = rows.first;
  final total = List<Object?>.filled(head.length, null);
  total[0] = 'TOTAL';
  for (var c = 0; c < head.length; c++) {
    if (!sumCols.contains(head[c])) continue;
    num s = 0;
    for (final r in rows.skip(1)) {
      final v = r[c];
      if (v is num) s += v;
    }
    total[c] = s;
  }
  return [...rows, total];
}

List<List<Object?>> _ordersRows(ExportData d) => [
  [
    'Nomor',
    'Tanggal bayar',
    'Tipe',
    'Meja',
    'Nomor antrean',
    'Sumber',
    'No. pesanan online',
    'Status',
    'Metode',
    'Subtotal',
    'Diskon',
    'Pajak',
    'Service',
    'Total',
    'Dibayar',
    'Tanggal refund',
    'Alasan refund',
    'Kasir',
  ],
  for (final o in d.soldOrders)
    [
      o.number,
      _t(o.paidAt ?? 0),
      o.type == OrderType.takeaway ? 'Takeaway' : 'Dine-in',
      d.tables[o.tableId] ?? '',
      o.queueNo ?? '',
      o.source.label,
      o.externalNo ?? '',
      o.status == OrderStatus.refunded ? 'Refund' : 'Lunas',
      o.payMethod?.label ?? '',
      o.subtotal,
      o.discount,
      o.tax,
      o.service,
      o.total,
      o.paidAmount,
      _t(o.refundedAt ?? 0),
      o.refundReason ?? '',
      o.paidByName ?? '',
    ],
];

/// Daftar transaksi ringkas (untuk PDF / cek silang dengan aplikasi online).
List<List<Object?>> transactionRows(ExportData d) => [
  ['Waktu', 'No. order', 'Sumber', 'No. pesanan online', 'Antrean', 'Metode', 'Total', 'Status'],
  for (final o in d.soldOrders)
    [
      _t(o.paidAt ?? 0),
      o.number,
      o.source.label,
      o.externalNo ?? '',
      o.queueNo ?? '',
      o.payMethod?.label ?? '',
      o.total,
      o.status == OrderStatus.refunded ? 'Refund' : 'Lunas',
    ],
];

/// Ringkasan per sumber pesanan.
List<List<Object?>> sourceRows(ExportData d) {
  final m = d.bySource.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));
  final rows = <List<Object?>>[
    ['Sumber', 'Jumlah order', 'Total penjualan'],
    for (final e in m) [e.key.label, e.value.n, e.value.total],
  ];
  return _withTotal(rows, const {'Jumlah order', 'Total penjualan'});
}

List<List<Object?>> itemsRows(ExportData d) => _withTotal(_itemsRows(d), const {'Qty', 'Total'});

List<List<Object?>> _itemsRows(ExportData d) => [
  [
    'Nomor',
    'Tanggal bayar',
    'Sumber',
    'Item',
    'Qty',
    'Harga',
    'Total',
    'Catatan',
    'Status order',
  ],
  for (final o in d.soldOrders)
    for (final it in o.items)
      [
        o.number,
        _t(o.paidAt ?? 0),
        o.source.label,
        it.name,
        it.qty,
        it.price,
        it.total,
        it.note,
        o.status == OrderStatus.refunded ? 'Refund' : 'Lunas',
      ],
];

List<List<Object?>> expensesRows(ExportData d) => _withTotal(_expensesRows(d), const {'Jumlah'});

List<List<Object?>> _expensesRows(ExportData d) {
  final list = d.expenses.where((e) => d.inRange(e.at)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return [
    [
      'Tanggal',
      'Kategori',
      'Jumlah',
      'Catatan',
      'Dari kas laci',
      'Dicatat oleh',
    ],
    for (final e in list)
      [
        _t(e.at),
        e.category,
        e.amount,
        e.note,
        e.fromDrawer ? 'ya' : 'tidak',
        e.userName,
      ],
  ];
}

List<List<Object?>> stockRows(ExportData d) {
  final list = d.moves.where((m) => d.inRange(m.at)).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return [
    [
      'Tanggal',
      'Bahan',
      'Satuan',
      'Jenis',
      'Jumlah',
      'Harga satuan',
      'Catatan',
      'Oleh',
    ],
    for (final m in list)
      [
        _t(m.at),
        d.ingredients[m.ingredientId]?.name ?? '(dihapus)',
        d.ingredients[m.ingredientId]?.unit ?? '',
        m.type.label,
        m.qty,
        m.unitCost,
        m.note,
        m.userName,
      ],
  ];
}

ProfitLoss profitLossOf(ExportData d) => computeProfitLoss(
  orders: d.orders,
  moves: d.moves,
  avgCost: d.avgCost,
  expenses: d.expenses,
  start: d.start,
  end: d.end,
);

List<List<Object?>> plRows(ExportData d) {
  final p = profitLossOf(d);
  final opex = p.opex.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    ['Keterangan', 'Nilai (Rp)'],
    ['Jumlah order', p.orderCount],
    ['Penjualan (sebelum pajak)', p.revenue],
    ['Refund', -p.refunds],
    ['Penjualan bersih', p.netRevenue],
    ['HPP (bahan terjual)', -p.cogs],
    ['Laba kotor', p.grossProfit],
    ['Waste & selisih stok', -p.shrink],
    ['Biaya operasional', -p.opexTotal],
    for (final e in opex) ['  ${e.key}', -e.value],
    ['Laba bersih', p.netProfit],
  ];
}
