import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import '../../core/sync/sync_controller.dart';
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
  final user = ref.watch(appUserProvider).value;
  // pelayan dkk. tidak boleh membaca isi shift: pakai status laci yang ditulis server
  if (user != null && !user.can('shifts.read')) {
    final st = ref.watch(shiftStatusProvider).value;
    if (st == null || st['open'] != true || st['shiftId'] == null) return null;
    return Shift(
      id: st['shiftId'] as String,
      cashierId: '',
      cashierName: st['cashierName'] as String? ?? '',
      openedAt: (st['openedAt'] as num?)?.toInt() ?? 0,
      openingCash: 0, // tidak diketahui (bukan haknya)
    );
  }
  final open = (ref.watch(shiftsProvider).value ?? <Shift>[])
      .where((s) => s.status == ShiftStatus.open)
      .toList();
  return open.isEmpty
      ? null
      : open.last; // daftar urut terbaru -> terakhir = tertua
});

/// Status laci kas outlet (koleksi `shift_status`, ditulis server): `open`, `shiftId`,
/// `cashierName`, `openedAt`. Dibaca oleh role yang tidak boleh melihat isi shift.
final shiftStatusProvider = StreamProvider<Map<String, dynamic>?>(
  (ref) => ref
      .watch(databaseProvider)
      .watchCollection('shift_status')
      .map((rows) => rows.isEmpty ? null : jsonDecode(rows.first.json) as Map<String, dynamic>),
);

/// Tunggu data user & shift termuat (aman dipanggil tepat setelah restart).
Future<Shift?> resolveCurrentShift(WidgetRef ref) async {
  final u = await ref.read(appUserProvider.future);
  if (u != null && !u.can('shifts.read')) {
    await ref.read(shiftStatusProvider.future);
  } else {
    await ref.read(shiftsProvider.future);
  }
  return ref.read(currentShiftProvider);
}
