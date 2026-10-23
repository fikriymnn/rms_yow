import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import '../auth/auth_providers.dart';
import 'shift.dart';

class ShiftRepository extends LocalFirstRepository<Shift> {
  ShiftRepository(super.ref);
  @override
  String get collection => 'shifts';
  @override
  Shift fromMap(Map<String, dynamic> m) => Shift.fromMap(m);
  @override
  Map<String, dynamic> toMap(Shift s) => s.toMap();
  @override
  String idOf(Shift s) => s.id;
}

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(ref),
);

final shiftsProvider = StreamProvider<List<Shift>>(
  (ref) => ref
      .watch(shiftRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.openedAt.compareTo(a.openedAt))),
);

/// Shift (laci kas) yang sedang terbuka di outlet ini. Satu laci per outlet, dipakai bersama
/// oleh semua yang boleh menerima pembayaran. Jika ada dobel (dibuka bersamaan saat offline),
/// yang tertua dipakai.
final currentShiftProvider = Provider<Shift?>((ref) {
  final open = (ref.watch(shiftsProvider).value ?? <Shift>[])
      .where((s) => s.status == ShiftStatus.open)
      .toList();
  return open.isEmpty
      ? null
      : open.last; // daftar urut terbaru -> terakhir = tertua
});

/// Tunggu data user & shift termuat (aman dipanggil tepat setelah restart).
Future<Shift?> resolveCurrentShift(WidgetRef ref) async {
  await ref.read(appUserProvider.future);
  await ref.read(shiftsProvider.future);
  return ref.read(currentShiftProvider);
}
