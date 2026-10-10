/// Kategori ini tidak masuk laba rugi (biayanya sudah masuk HPP lewat Stok),
/// tapi tetap mengurangi kas laci jika dibayar dari laci.
const kPurchaseCategory = 'Pembelian bahan (sudah di Stok)';

const kExpenseCategories = [
  'Bahan baku (non-stok)',
  kPurchaseCategory,
  'Gaji & upah',
  'Sewa',
  'Listrik, air & internet',
  'Gas & BBM',
  'Transport',
  'Perawatan & perbaikan',
  'Marketing',
  'Lain-lain',
];

class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.at,
    this.note = '',
    this.fromDrawer = false,
    this.shiftId,
    this.userName = '',
  });

  final String id;
  final String category;
  final int amount;
  final int at;
  final String note;
  final bool fromDrawer; // dibayar dari kas laci (mengurangi kas shift)
  final String? shiftId;
  final String userName;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'] as String,
    category: m['category'] as String? ?? 'Lain-lain',
    amount: (m['amount'] as num?)?.toInt() ?? 0,
    at: (m['at'] as num?)?.toInt() ?? 0,
    note: m['note'] as String? ?? '',
    fromDrawer: m['fromDrawer'] as bool? ?? false,
    shiftId: m['shiftId'] as String?,
    userName: m['userName'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'amount': amount,
    'at': at,
    'note': note,
    'fromDrawer': fromDrawer,
    'shiftId': shiftId,
    'userName': userName,
  };
}
