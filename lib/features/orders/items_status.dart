import 'order_models.dart';

/// Status masak satu item order. Doc id = id item.
///
/// Setiap perubahan status mencatat waktu & nama petugas ([preparingAt], [readyAt], [servedAt])
/// untuk riwayat dan KPI dapur. Dokumen lama tanpa waktu tetap terbaca.
class ItemStatus {
  const ItemStatus({
    required this.id,
    required this.orderId,
    required this.status,
    this.preparingAt,
    this.readyAt,
    this.servedAt,
    this.preparingBy = '',
    this.readyBy = '',
    this.servedBy = '',
  });
  final String id;
  final String orderId;
  final KitchenStatus status;
  final int? preparingAt;
  final int? readyAt;
  final int? servedAt;
  final String preparingBy;
  final String readyBy;
  final String servedBy;

  /// Status baru dengan waktu & petugas tahap itu. Waktu tahap sebelumnya dipertahankan.
  ItemStatus advance(KitchenStatus to, {required int at, required String by}) => ItemStatus(
    id: id,
    orderId: orderId,
    status: to,
    preparingAt: to == KitchenStatus.preparing ? at : preparingAt,
    readyAt: to == KitchenStatus.ready ? at : readyAt,
    servedAt: to == KitchenStatus.served ? at : servedAt,
    preparingBy: to == KitchenStatus.preparing ? by : preparingBy,
    readyBy: to == KitchenStatus.ready ? by : readyBy,
    servedBy: to == KitchenStatus.served ? by : servedBy,
  );

  factory ItemStatus.fromMap(Map<String, dynamic> m) => ItemStatus(
    id: m['id'] as String,
    orderId: m['orderId'] as String? ?? '',
    status: KitchenStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => KitchenStatus.newItem,
    ),
    preparingAt: (m['preparingAt'] as num?)?.toInt(),
    readyAt: (m['readyAt'] as num?)?.toInt(),
    servedAt: (m['servedAt'] as num?)?.toInt(),
    preparingBy: m['preparingBy'] as String? ?? '',
    readyBy: m['readyBy'] as String? ?? '',
    servedBy: m['servedBy'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'orderId': orderId,
    'status': status.name,
    if (preparingAt != null) 'preparingAt': preparingAt,
    if (readyAt != null) 'readyAt': readyAt,
    if (servedAt != null) 'servedAt': servedAt,
    if (preparingBy.isNotEmpty) 'preparingBy': preparingBy,
    if (readyBy.isNotEmpty) 'readyBy': readyBy,
    if (servedBy.isNotEmpty) 'servedBy': servedBy,
  };
}
