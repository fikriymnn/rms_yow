enum ShiftStatus { open, closed }

class Shift {
  const Shift({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.openedAt,
    required this.openingCash,
    this.status = ShiftStatus.open,
    this.closedAt,
    this.closingCash,
    this.expectedCash,
    this.cashSales,
    this.otherSales,
    this.orderCount,
    this.salesByMethod,
    this.refundCash,
    this.refundOther,
  });

  final String id;
  final String cashierId;
  final String cashierName;
  final int openedAt;
  final int openingCash;
  final ShiftStatus status;
  final int? closedAt;
  final int? closingCash; // uang fisik yang dihitung saat tutup
  final int? expectedCash; // modal awal + penjualan tunai
  final int? cashSales;
  final int? otherSales;
  final int? orderCount;
  final Map<String, int>? salesByMethod;
  final int? refundCash;
  final int? refundOther;

  int? get difference => (closingCash == null || expectedCash == null)
      ? null
      : closingCash! - expectedCash!;

  Shift copyWith({
    ShiftStatus? status,
    int? closedAt,
    int? closingCash,
    int? expectedCash,
    int? cashSales,
    int? otherSales,
    int? orderCount,
    Map<String, int>? salesByMethod,
    int? refundCash,
    int? refundOther,
  }) => Shift(
    id: id,
    cashierId: cashierId,
    cashierName: cashierName,
    openedAt: openedAt,
    openingCash: openingCash,
    status: status ?? this.status,
    closedAt: closedAt ?? this.closedAt,
    closingCash: closingCash ?? this.closingCash,
    expectedCash: expectedCash ?? this.expectedCash,
    cashSales: cashSales ?? this.cashSales,
    otherSales: otherSales ?? this.otherSales,
    orderCount: orderCount ?? this.orderCount,
    salesByMethod: salesByMethod ?? this.salesByMethod,
    refundCash: refundCash ?? this.refundCash,
    refundOther: refundOther ?? this.refundOther,
  );

  factory Shift.fromMap(Map<String, dynamic> m) => Shift(
    id: m['id'] as String,
    cashierId: m['cashierId'] as String? ?? '',
    cashierName: m['cashierName'] as String? ?? '',
    openedAt: (m['openedAt'] as num?)?.toInt() ?? 0,
    openingCash: (m['openingCash'] as num?)?.toInt() ?? 0,
    status: ShiftStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => ShiftStatus.open,
    ),
    closedAt: (m['closedAt'] as num?)?.toInt(),
    closingCash: (m['closingCash'] as num?)?.toInt(),
    expectedCash: (m['expectedCash'] as num?)?.toInt(),
    cashSales: (m['cashSales'] as num?)?.toInt(),
    otherSales: (m['otherSales'] as num?)?.toInt(),
    orderCount: (m['orderCount'] as num?)?.toInt(),
    salesByMethod: (m['salesByMethod'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
    refundCash: (m['refundCash'] as num?)?.toInt(),
    refundOther: (m['refundOther'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'cashierId': cashierId,
    'cashierName': cashierName,
    'openedAt': openedAt,
    'openingCash': openingCash,
    'status': status.name,
    'closedAt': closedAt,
    'closingCash': closingCash,
    'expectedCash': expectedCash,
    'cashSales': cashSales,
    'otherSales': otherSales,
    'orderCount': orderCount,
    'salesByMethod': salesByMethod,
    'refundCash': refundCash,
    'refundOther': refundOther,
  };
}
