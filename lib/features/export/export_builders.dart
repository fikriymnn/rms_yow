import 'package:intl/intl.dart';

import '../finance/expense.dart';
import '../finance/profit_loss.dart';
import '../inventory/inventory_models.dart';
import '../orders/order_models.dart';

final _dt = DateFormat('yyyy-MM-dd HH:mm');
String _t(int ms) =>
    ms == 0 ? '' : _dt.format(DateTime.fromMillisecondsSinceEpoch(ms));

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
  });

  final List<Order> orders;
  final List<StockMove> moves;
  final List<Expense> expenses;
  final Map<String, Ingredient> ingredients;
  final Map<String, String> tables;
  final Map<String, double> avgCost;
  final int start; // inklusif
  final int end; // eksklusif

  bool inRange(int t) => t >= start && t < end;

  List<Order> get soldOrders =>
      orders
          .where(
            (o) =>
                (o.status == OrderStatus.paid ||
                    o.status == OrderStatus.refunded) &&
                inRange(o.paidAt ?? 0),
          )
          .toList()
        ..sort((a, b) => (a.paidAt ?? 0).compareTo(b.paidAt ?? 0));
}

List<List<Object?>> ordersRows(ExportData d) => [
  [
    'Nomor',
    'Tanggal bayar',
    'Tipe',
    'Meja',
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
      o.status.name,
      o.payMethod?.name ?? '',
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

List<List<Object?>> itemsRows(ExportData d) => [
  [
    'Nomor',
    'Tanggal bayar',
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
        it.name,
        it.qty,
        it.price,
        it.total,
        it.note,
        o.status.name,
      ],
];

List<List<Object?>> expensesRows(ExportData d) {
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
