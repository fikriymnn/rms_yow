import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_repository.dart';
import 'reservation.dart';

class ReservationRepository extends LocalFirstRepository<Reservation> {
  ReservationRepository(super.ref);
  @override
  String get collection => 'reservations';
  @override
  Reservation fromMap(Map<String, dynamic> m) => Reservation.fromMap(m);
  @override
  Map<String, dynamic> toMap(Reservation r) => r.toMap();
  @override
  String idOf(Reservation r) => r.id;
}

final reservationRepositoryProvider = Provider<ReservationRepository>(
  (ref) => ReservationRepository(ref),
);

final reservationsProvider = StreamProvider<List<Reservation>>(
  (ref) => ref
      .watch(reservationRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => a.at.compareTo(b.at))),
);

/// Berdetak tiap menit agar indikator "hari ini" tersegarkan sendiri.
final minuteTickProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()),
);
