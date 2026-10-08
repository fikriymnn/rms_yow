import 'dart:math';

const kTaxPercent = 10; // PB1, nanti pindah ke Settings
const kServicePercent = 0;

enum OrderType { dineIn, takeaway }

enum OrderStatus { open, paid, voided }

enum KitchenStatus { newItem, preparing, ready, served }

enum PayMethod { cash, qris, card, other }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

class OrderItem {
  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.qty = 1,
    this.note = '',
    this.kitchen = KitchenStatus.newItem,
  });

  final String menuItemId;
  final String name;
  final int price;
  final int qty;
  final String note;
  final KitchenStatus kitchen;

  int get total => price * qty;

  OrderItem copyWith({int? qty, String? note, KitchenStatus? kitchen}) =>
      OrderItem(
        menuItemId: menuItemId,
        name: name,
        price: price,
        qty: qty ?? this.qty,
        note: note ?? this.note,
        kitchen: kitchen ?? this.kitchen,
      );

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    menuItemId: m['menuItemId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    price: (m['price'] as num?)?.toInt() ?? 0,
    qty: (m['qty'] as num?)?.toInt() ?? 1,
    note: m['note'] as String? ?? '',
    kitchen: _byName(KitchenStatus.values, m['kitchen'], KitchenStatus.newItem),
  );

  Map<String, dynamic> toMap() => {
    'menuItemId': menuItemId,
    'name': name,
    'price': price,
    'qty': qty,
    'note': note,
    'kitchen': kitchen.name,
  };
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

  int get subtotal => items.fold(0, (s, i) => s + i.total);
  int get _base => max(0, subtotal - discount);
  int get tax => (_base * kTaxPercent / 100).round();
  int get service => (_base * kServicePercent / 100).round();
  int get total => _base + tax + service;

  Order copyWith({
    List<OrderItem>? items,
    OrderStatus? status,
    int? discount,
    PayMethod? payMethod,
    int? paidAmount,
    int? paidAt,
  }) => Order(
    id: id,
    number: number,
    type: type,
    tableId: tableId,
    createdAt: createdAt,
    createdBy: createdBy,
    items: items ?? this.items,
    status: status ?? this.status,
    discount: discount ?? this.discount,
    payMethod: payMethod ?? this.payMethod,
    paidAmount: paidAmount ?? this.paidAmount,
    paidAt: paidAt ?? this.paidAt,
  );

  factory Order.fromMap(Map<String, dynamic> m) => Order(
    id: m['id'] as String,
    number: m['number'] as String? ?? '',
    type: _byName(OrderType.values, m['type'], OrderType.dineIn),
    tableId: m['tableId'] as String?,
    items: (m['items'] as List? ?? [])
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    status: _byName(OrderStatus.values, m['status'], OrderStatus.open),
    discount: (m['discount'] as num?)?.toInt() ?? 0,
    payMethod: m['payMethod'] == null
        ? null
        : _byName(PayMethod.values, m['payMethod'], PayMethod.other),
    paidAmount: (m['paidAmount'] as num?)?.toInt() ?? 0,
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    createdBy: m['createdBy'] as String? ?? '',
    paidAt: (m['paidAt'] as num?)?.toInt(),
  );

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
  };
}
