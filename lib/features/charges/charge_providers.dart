import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import 'charge_models.dart';

class ChargeRepository extends LocalFirstRepository<Charge> {
  ChargeRepository(super.ref);
  @override
  String get collection => 'charges';
  @override
  Charge fromMap(Map<String, dynamic> m) => Charge.fromMap(m);
  @override
  Map<String, dynamic> toMap(Charge c) => c.toMap();
  @override
  String idOf(Charge c) => c.id;
}

final chargeRepositoryProvider = Provider<ChargeRepository>(
  (ref) => ChargeRepository(ref),
);

/// Semua biaya (aktif dan nonaktif): service dulu, lalu pajak, urut nama.
final chargesProvider = StreamProvider<List<Charge>>(
  (ref) => ref.watch(chargeRepositoryProvider).watchAll().map((l) {
    final list = [...l];
    list.sort((a, b) {
      final k = a.kind.index.compareTo(b.kind.index);
      return k != 0 ? -k : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }),
);

/// Tarif yang berlaku untuk order baru / order yang belum dibayar.
final chargeLinesProvider = Provider<List<ChargeLine>>(
  (ref) => [
    for (final c in ref.watch(chargesProvider).value ?? const <Charge>[])
      if (c.active) c.toLine(),
  ],
);
