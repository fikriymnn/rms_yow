import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'order_models.dart';
import 'order_providers.dart';

/// Nomor antrian / atas nama yang masih dipakai: pesanan 24 jam terakhir yang sudah dibayar dan
/// masih punya item belum selesai (belum "diantar / diambil").
/// Kunci = nomor dalam huruf kecil, nilai = nomor order (untuk pesan peringatan).
final activeQueueNumbersProvider = Provider<Map<String, String>>((ref) {
  final orders = ref.watch(ordersProvider).value ?? const <Order>[];
  final status =
      ref.watch(itemStatusProvider).value ?? const <String, KitchenStatus>{};
  final cutoff = DateTime.now()
      .subtract(const Duration(hours: 24))
      .millisecondsSinceEpoch;
  return {
    for (final o in orders)
      if (o.status == OrderStatus.paid &&
          (o.queueNo ?? o.customerName) != null &&
          o.createdAt >= cutoff &&
          o.items.any(
            (i) =>
                (status[i.id] ?? KitchenStatus.newItem) != KitchenStatus.served,
          ))
        (o.queueNo ?? o.customerName)!.toLowerCase(): o.number,
  };
});
