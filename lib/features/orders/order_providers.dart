import 'package:flutter_riverpod/flutter_riverpod.dart';

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
