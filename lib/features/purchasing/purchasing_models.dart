double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
  });
  final String id;
  final String name;
  final String phone;
  final String note;

  Supplier copyWith({String? name, String? phone, String? note}) => Supplier(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    note: note ?? this.note,
  );

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    note: m['note'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'note': note,
  };
}

class PoLine {
  const PoLine({
    required this.ingredientId,
    required this.name,
    required this.unitLabel,
    required this.factor,
    required this.qty,
    required this.unitPrice,
  });

  final String ingredientId;
  final String name;
  final String unitLabel; // satuan beli, mis. "kg"
  final double factor; // 1 satuan beli = factor satuan dasar
  final double qty; // dalam satuan beli
  final int unitPrice; // Rp per satuan beli

  int get total => (qty * unitPrice).round();

  PoLine copyWith({double? qty, int? unitPrice}) => PoLine(
    ingredientId: ingredientId,
    name: name,
    unitLabel: unitLabel,
    factor: factor,
    qty: qty ?? this.qty,
    unitPrice: unitPrice ?? this.unitPrice,
  );

  factory PoLine.fromMap(Map<String, dynamic> m) => PoLine(
    ingredientId: m['ingredientId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    unitLabel: m['unitLabel'] as String? ?? '',
    factor: _d(m['factor']) > 0 ? _d(m['factor']) : 1,
    qty: _d(m['qty']),
    unitPrice: (m['unitPrice'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'ingredientId': ingredientId,
    'name': name,
    'unitLabel': unitLabel,
    'factor': factor,
    'qty': qty,
    'unitPrice': unitPrice,
  };
}

List<PoLine> _lines(Object? v) => [
  for (final e in (v as List? ?? []))
    PoLine.fromMap(Map<String, dynamic>.from(e as Map)),
];

enum PoStatus {
  draft('Draft'),
  pending('Menunggu persetujuan'), // diatur server
  ordered('Dipesan'),
  closed('Selesai'),
  cancelled('Dibatalkan'),
  rejected('Ditolak'); // diatur server

  const PoStatus(this.label);
  final String label;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.supplierName,
    required this.createdAt,
    this.status = PoStatus.draft,
    this.lines = const [],
    this.note = '',
    this.createdBy = '',
    this.createdByName = '',
  });

  final String id;
  final String number;
  final String supplierId;
  final String supplierName;
  final int createdAt;
  final PoStatus status;
  final List<PoLine> lines;
  final String note;
  final String createdBy;
  final String createdByName;

  int get total => lines.fold(0, (s, l) => s + l.total);

  PurchaseOrder copyWith({PoStatus? status}) => PurchaseOrder(
    id: id,
    number: number,
    supplierId: supplierId,
    supplierName: supplierName,
    createdAt: createdAt,
    status: status ?? this.status,
    lines: lines,
    note: note,
    createdBy: createdBy,
    createdByName: createdByName,
  );

  factory PurchaseOrder.fromMap(Map<String, dynamic> m) => PurchaseOrder(
    id: m['id'] as String,
    number: m['number'] as String? ?? '',
    supplierId: m['supplierId'] as String? ?? '',
    supplierName: m['supplierName'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    status: PoStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => PoStatus.draft,
    ),
    lines: _lines(m['lines']),
    note: m['note'] as String? ?? '',
    createdBy: m['createdBy'] as String? ?? '',
    createdByName: m['createdByName'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'createdAt': createdAt,
    'status': status.name,
    'lines': [for (final l in lines) l.toMap()],
    'note': note,
    'total': total,
    'createdBy': createdBy,
    'createdByName': createdByName,
  };
}

class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.number,
    required this.poId,
    required this.supplierId,
    required this.supplierName,
    required this.at,
    this.lines = const [],
    this.invoiceNo = '',
    this.userName = '',
  });

  final String id;
  final String number;
  final String poId;
  final String supplierId;
  final String supplierName;
  final int at;
  final List<PoLine> lines; // qty = jumlah diterima, unitPrice = harga aktual
  final String invoiceNo;
  final String userName;

  int get total => lines.fold(0, (s, l) => s + l.total);

  factory GoodsReceipt.fromMap(Map<String, dynamic> m) => GoodsReceipt(
    id: m['id'] as String,
    number: m['number'] as String? ?? '',
    poId: m['poId'] as String? ?? '',
    supplierId: m['supplierId'] as String? ?? '',
    supplierName: m['supplierName'] as String? ?? '',
    at: (m['at'] as num?)?.toInt() ?? 0,
    lines: _lines(m['lines']),
    invoiceNo: m['invoiceNo'] as String? ?? '',
    userName: m['userName'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'poId': poId,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'at': at,
    'lines': [for (final l in lines) l.toMap()],
    'invoiceNo': invoiceNo,
    'userName': userName,
    'total': total,
  };
}

class SupplierPayment {
  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    required this.at,
    this.note = '',
    this.fromDrawer = false,
    this.userName = '',
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final int amount;
  final int at;
  final String note;
  final bool fromDrawer;
  final String userName;

  factory SupplierPayment.fromMap(Map<String, dynamic> m) => SupplierPayment(
    id: m['id'] as String,
    supplierId: m['supplierId'] as String? ?? '',
    supplierName: m['supplierName'] as String? ?? '',
    amount: (m['amount'] as num?)?.toInt() ?? 0,
    at: (m['at'] as num?)?.toInt() ?? 0,
    note: m['note'] as String? ?? '',
    fromDrawer: m['fromDrawer'] as bool? ?? false,
    userName: m['userName'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'amount': amount,
    'at': at,
    'note': note,
    'fromDrawer': fromDrawer,
    'userName': userName,
  };
}
