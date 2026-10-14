enum ReservationStatus {
  booked('Dipesan'),
  seated('Sudah duduk'),
  cancelled('Dibatalkan'),
  noShow('Tidak datang');

  const ReservationStatus(this.label);
  final String label;
}

class Reservation {
  const Reservation({
    required this.id,
    required this.name,
    required this.at,
    this.phone = '',
    this.partySize = 2,
    this.durationMin = 90,
    this.tableId,
    this.note = '',
    this.status = ReservationStatus.booked,
    this.createdBy = '',
    this.seatedAt,
  });

  final String id;
  final String name;
  final int at; // waktu mulai (epoch ms)
  final String phone;
  final int partySize;
  final int durationMin;
  final String? tableId;
  final String note;
  final ReservationStatus status;
  final String createdBy;
  final int? seatedAt;

  int get endAt => at + durationMin * 60000;
  bool overlaps(Reservation o) => at < o.endAt && o.at < endAt;

  Reservation copyWith({ReservationStatus? status, int? seatedAt}) =>
      Reservation(
        id: id,
        name: name,
        at: at,
        phone: phone,
        partySize: partySize,
        durationMin: durationMin,
        tableId: tableId,
        note: note,
        status: status ?? this.status,
        createdBy: createdBy,
        seatedAt: seatedAt ?? this.seatedAt,
      );

  factory Reservation.fromMap(Map<String, dynamic> m) => Reservation(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    at: (m['at'] as num?)?.toInt() ?? 0,
    phone: m['phone'] as String? ?? '',
    partySize: (m['partySize'] as num?)?.toInt() ?? 2,
    durationMin: (m['durationMin'] as num?)?.toInt() ?? 90,
    tableId: m['tableId'] as String?,
    note: m['note'] as String? ?? '',
    status: ReservationStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => ReservationStatus.booked,
    ),
    createdBy: m['createdBy'] as String? ?? '',
    seatedAt: (m['seatedAt'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'at': at,
    'phone': phone,
    'partySize': partySize,
    'durationMin': durationMin,
    'tableId': tableId,
    'note': note,
    'status': status.name,
    'createdBy': createdBy,
    'seatedAt': seatedAt,
  };
}
