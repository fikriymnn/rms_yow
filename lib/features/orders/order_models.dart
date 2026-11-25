import 'dart:math';

import '../charges/charge_models.dart';

/// Hanya cadangan untuk order lama yang tidak menyimpan pajaknya.
/// Tarif sekarang berasal dari master data (features/charges).
const kTaxPercent = 10;
const kServicePercent = 0;

enum OrderType { dineIn, takeaway }

enum OrderStatus { open, paid, voided, refunded }

enum KitchenStatus { newItem, preparing, ready, served }

enum PayMethod { cash, qris, card, other, online }

/// Label tampilan metode bayar. `online` = dibayar lewat aplikasi pesan-antar.
extension PayMethodLabel on PayMethod {
  String get label => switch (this) {
    PayMethod.cash => 'Tunai',
    PayMethod.qris => 'QRIS',
    PayMethod.card => 'Kartu',
    PayMethod.other => 'Lainnya',
    PayMethod.online => 'Aplikasi online',
  };
}

/// Asal pesanan: datang langsung atau aplikasi pesan-antar (untuk filter laporan & cek silang).
enum OrderSource {
  walkin('Langsung'),
  gofood('GoFood'),
  grabfood('GrabFood'),
  shopeefood('ShopeeFood');

  const OrderSource(this.label);
  final String label;
  bool get isOnline => this != OrderSource.walkin;
}

String? _text(Object? v) {
  final s = v is String ? v.trim() : '';
  return s.isEmpty ? null : s;
}

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

class OrderItem {
  const OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    this.qty = 1,
    this.note = '',
    this.addedAt,
  });

  final String id;
  final String menuItemId;
  final String name;
  final int price;
  final int qty;
  final String note;

  /// Waktu item masuk pesanan (untuk KPI dapur). Item lama: null -> pakai waktu pesanan.
  final int? addedAt;

  int get total => price * qty;

  OrderItem copyWith({int? qty, String? note}) => OrderItem(
    id: id,
    menuItemId: menuItemId,
    name: name,
    price: price,
    qty: qty ?? this.qty,
    note: note ?? this.note,
    addedAt: addedAt,
  );

  factory OrderItem.fromMap(Map<String, dynamic> m, {String fallbackId = ''}) =>
      OrderItem(
        id: m['id'] as String? ?? fallbackId,
        menuItemId: m['menuItemId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        note: m['note'] as String? ?? '',
        addedAt: (m['addedAt'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'menuItemId': menuItemId,
    'name': name,
    'price': price,
    'qty': qty,
    'note': note,
    if (addedAt != null) 'addedAt': addedAt,
  };
}

/// Satu biaya pada order beserta nominal hasil hitungnya.
class AppliedCharge {
  const AppliedCharge(this.line, this.amount);
  final ChargeLine line;
  final int amount;
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.type,
    required this.createdAt,
    this.tableId,
    this.items = const [],
    this.status = OrderStatus.open,
    this.discount = 0,
    this.payMethod,
    this.paidAmount = 0,
    this.createdBy = '',
    this.paidAt,
    this.shiftId,
    this.refundedAt,
    this.refundShiftId,
    this.refundReason,
    this.paidBy,
    this.paidByName,
    this.charges = const [],
    this.queueNo,
    this.source = OrderSource.walkin,
    this.externalNo,
  });

  final String id;
  final String number;
  final OrderType type;
  final String? tableId;
  final List<OrderItem> items;
  final OrderStatus status;
  final int discount;
  final PayMethod? payMethod;
  final int paidAmount;
  final int createdAt;
  final String createdBy;
  final int? paidAt;
  final String? shiftId;
  final int? refundedAt;
  final String? refundShiftId;
  final String? refundReason;
  final String? paidBy;
  final String? paidByName;
  final List<ChargeLine> charges; // salinan tarif pajak / service
  final String? queueNo;
  final OrderSource source;
  final String? externalNo; // nomor pesanan di aplikasi online (GoFood dsb.)

  int get subtotal => items.fold(0, (s, i) => s + i.total);
  int get _base => max(0, subtotal - discount);

  /// Service dihitung dulu. Pajak dihitung atas dasar yang sama, atau atas
  /// dasar + service bila opsi "atas subtotal + service" aktif.
  List<AppliedCharge> get appliedCharges {
    final b = _base;
    final out = <AppliedCharge>[];
    var serviceTotal = 0;
    for (final c in charges) {
      if (c.kind != ChargeKind.service) continue;
      final a = c.fixedAmount ?? (b * c.percent / 100).round();
      serviceTotal += a;
      out.add(AppliedCharge(c, a));
    }
    for (final c in charges) {
      if (c.kind != ChargeKind.tax) continue;
      final dasar = b + (c.onService ? serviceTotal : 0);
      out.add(
        AppliedCharge(c, c.fixedAmount ?? (dasar * c.percent / 100).round()),
      );
    }
    return out;
  }

  int get tax => appliedCharges
      .where((a) => a.line.kind == ChargeKind.tax)
      .fold(0, (s, a) => s + a.amount);
  int get service => appliedCharges
      .where((a) => a.line.kind == ChargeKind.service)
      .fold(0, (s, a) => s + a.amount);
  int get total => _base + tax + service;

  Order copyWith({
    List<OrderItem>? items,
    OrderStatus? status,
    int? discount,
    PayMethod? payMethod,
    int? paidAmount,
    int? paidAt,
    String? shiftId,
    int? refundedAt,
    String? refundShiftId,
    String? refundReason,
    String? paidBy,
    String? paidByName,
    List<ChargeLine>? charges,
    String? queueNo,
    OrderType? type,
    OrderSource? source,
    String? externalNo,
  }) => Order(
    id: id,
    number: number,
    type: type ?? this.type,
    tableId: tableId,
    createdAt: createdAt,
    createdBy: createdBy,
    items: items ?? this.items,
    status: status ?? this.status,
    discount: discount ?? this.discount,
    payMethod: payMethod ?? this.payMethod,
    paidAmount: paidAmount ?? this.paidAmount,
    paidAt: paidAt ?? this.paidAt,
    shiftId: shiftId ?? this.shiftId,
    refundedAt: refundedAt ?? this.refundedAt,
    refundShiftId: refundShiftId ?? this.refundShiftId,
    refundReason: refundReason ?? this.refundReason,
    paidBy: paidBy ?? this.paidBy,
    paidByName: paidByName ?? this.paidByName,
    charges: charges ?? this.charges,
    queueNo: queueNo ?? this.queueNo,
    source: source ?? this.source,
    externalNo: externalNo ?? this.externalNo,
  );

  factory Order.fromMap(Map<String, dynamic> m) {
    final items = [
      for (final (i, e) in (m['items'] as List? ?? []).indexed)
        OrderItem.fromMap(
          Map<String, dynamic>.from(e as Map),
          fallbackId: '${m['id']}-$i',
        ),
    ];
    final discount = (m['discount'] as num?)?.toInt() ?? 0;
    return Order(
      id: m['id'] as String,
      number: m['number'] as String? ?? '',
      type: _byName(OrderType.values, m['type'], OrderType.dineIn),
      tableId: m['tableId'] as String?,
      items: items,
      status: _byName(OrderStatus.values, m['status'], OrderStatus.open),
      discount: discount,
      payMethod: m['payMethod'] == null
          ? null
          : _byName(PayMethod.values, m['payMethod'], PayMethod.other),
      paidAmount: (m['paidAmount'] as num?)?.toInt() ?? 0,
      createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      createdBy: m['createdBy'] as String? ?? '',
      paidAt: (m['paidAt'] as num?)?.toInt(),
      shiftId: m['shiftId'] as String?,
      refundedAt: (m['refundedAt'] as num?)?.toInt(),
      refundShiftId: m['refundShiftId'] as String?,
      refundReason: m['refundReason'] as String?,
      paidBy: m['paidBy'] as String?,
      paidByName: m['paidByName'] as String?,
      charges: _chargesFrom(m, items, discount),
      queueNo: _text(m['queueNo']),
      source: _byName(OrderSource.values, m['source'], OrderSource.walkin),
      externalNo: _text(m['externalNo']),
    );
  }

  /// Order baru menyimpan salinan tarifnya. Order lama (sebelum master data)
  /// memakai nominal pajak / service yang tersimpan, supaya totalnya tidak berubah.
  static List<ChargeLine> _chargesFrom(
    Map<String, dynamic> m,
    List<OrderItem> items,
    int discount,
  ) {
    final raw = m['charges'];
    if (raw is List) {
      return [
        for (final e in raw)
          ChargeLine.fromMap(Map<String, dynamic>.from(e as Map)),
      ];
    }
    final base = max(0, items.fold<int>(0, (s, i) => s + i.total) - discount);
    final tax =
        (m['tax'] as num?)?.toInt() ?? (base * kTaxPercent / 100).round();
    final service =
        (m['service'] as num?)?.toInt() ??
        (base * kServicePercent / 100).round();
    double pct(int a) =>
        base > 0 ? double.parse((a * 100 / base).toStringAsFixed(2)) : 0;
    return [
      if (service > 0)
        ChargeLine(
          id: 'legacy-service',
          name: 'Service',
          kind: ChargeKind.service,
          percent: pct(service),
          fixedAmount: service,
        ),
      if (tax > 0)
        ChargeLine(
          id: 'legacy-tax',
          name: 'Pajak',
          kind: ChargeKind.tax,
          percent: pct(tax),
          fixedAmount: tax,
        ),
    ];
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'type': type.name,
    'tableId': tableId,
    'items': items.map((e) => e.toMap()).toList(),
    'status': status.name,
    'discount': discount,
    'payMethod': payMethod?.name,
    'paidAmount': paidAmount,
    'createdAt': createdAt,
    'createdBy': createdBy,
    'paidAt': paidAt,
    // total disimpan agar laporan tidak perlu menghitung ulang
    'subtotal': subtotal,
    'tax': tax,
    'service': service,
    'total': total,
    'charges': [for (final a in appliedCharges) a.line.toMap(a.amount)],
    'queueNo': queueNo,
    'source': source.name,
    if (externalNo != null) 'externalNo': externalNo,
    'shiftId': shiftId,
    'refundedAt': refundedAt,
    'refundShiftId': refundShiftId,
    'refundReason': refundReason,
    'paidBy': paidBy,
    'paidByName': paidByName,
  };
}

extension KitchenLabel on KitchenStatus {
  String get label => switch (this) {
    KitchenStatus.newItem => 'Baru',
    KitchenStatus.preparing => 'Diproses',
    KitchenStatus.ready => 'Siap',
    KitchenStatus.served => 'Diantar',
  };
}
