import 'order_models.dart';

/// Status masak satu item order. Doc id = id item.
class ItemStatus {
  const ItemStatus({
    required this.id,
    required this.orderId,
    required this.status,
  });
  final String id;
  final String orderId;
  final KitchenStatus status;

  factory ItemStatus.fromMap(Map<String, dynamic> m) => ItemStatus(
    id: m['id'] as String,
    orderId: m['orderId'] as String? ?? '',
    status: KitchenStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => KitchenStatus.newItem,
    ),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'orderId': orderId,
    'status': status.name,
  };
}
