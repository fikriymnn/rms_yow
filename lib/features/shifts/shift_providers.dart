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

/// Shift yang sedang terbuka milik user yang login.
final currentShiftProvider = Provider<Shift?>((ref) {
  final uid = ref.watch(appUserProvider).value?.uid;
  final list = ref.watch(shiftsProvider).value ?? <Shift>[];
  return list
      .where((s) => s.status == ShiftStatus.open && s.cashierId == uid)
      .firstOrNull;
});
