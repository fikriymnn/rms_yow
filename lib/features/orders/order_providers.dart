import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/features/orders/items_status.dart';

import '../../core/sync/local_first_repository.dart';
import 'order_models.dart';

class OrderRepository extends LocalFirstRepository<Order> {
  OrderRepository(super.ref);
  @override
  String get collection => 'orders';
  @override
  Order fromMap(Map<String, dynamic> m) => Order.fromMap(m);
  @override
  Map<String, dynamic> toMap(Order o) => o.toMap();
  @override
  String idOf(Order o) => o.id;
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref),
);

final ordersProvider = StreamProvider<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).watchAll(),
);

final openOrdersProvider = Provider<List<Order>>(
  (ref) => (ref.watch(ordersProvider).value ?? [])
      .where((o) => o.status == OrderStatus.open)
      .toList(),
);

class ItemStatusRepository extends LocalFirstRepository<ItemStatus> {
  ItemStatusRepository(super.ref);
  @override
  String get collection => 'item_status';
  @override
  ItemStatus fromMap(Map<String, dynamic> m) => ItemStatus.fromMap(m);
  @override
  Map<String, dynamic> toMap(ItemStatus s) => s.toMap();
  @override
  String idOf(ItemStatus s) => s.id;
}

final itemStatusRepositoryProvider = Provider<ItemStatusRepository>(
  (ref) => ItemStatusRepository(ref),
);

/// itemId -> status. Item tanpa dokumen dianggap `newItem`.
final itemStatusProvider = StreamProvider<Map<String, KitchenStatus>>(
  (ref) => ref
      .watch(itemStatusRepositoryProvider)
      .watchAll()
      .map((l) => {for (final s in l) s.id: s.status}),
);
