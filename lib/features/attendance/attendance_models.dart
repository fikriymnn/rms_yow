String durationText(int minutes) =>
    '${minutes ~/ 60}j ${(minutes % 60).toString().padLeft(2, '0')}m';

String minText(int m) {
  if (m < 60) return '$m menit';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h jam' : '$h jam $r menit';
}

/// Ketepatan waktu satu catatan (null = outlet belum punya jadwal hari itu).
String? punctualityText(AttendanceRecord r, {required bool out}) {
  if (!out) {
    return switch (r.inStatus) {
      'late' => 'Terlambat ${minText(r.lateMin)}',
      'on_time' => 'Tepat waktu',
      _ => null,
    };
  }
  return switch (r.outStatus) {
    'early' => 'Pulang lebih awal ${minText(r.earlyOutMin)}',
    'overtime' => 'Lembur ${minText(r.overtimeMin)}',
    'on_time' => 'Tepat waktu',
    _ => null,
  };
}

class AttendanceRecord {
  AttendanceRecord.fromJson(Map<String, dynamic> m)
    : id = m['id'] as String,
      userId = m['user_id'] as String,
      userName = m['user_name'] as String? ?? '',
      clockInAt = (m['clock_in_at'] as num).toInt(),
      clockOutAt = (m['clock_out_at'] as num?)?.toInt(),
      minutes = (m['minutes'] as num?)?.toInt(),
      inDistanceM = (m['in_distance_m'] as num?)?.toInt(),
      outDistanceM = (m['out_distance_m'] as num?)?.toInt(),
      inFlags = [for (final f in (m['in_flags'] as List? ?? [])) '$f'],
      outFlags = [for (final f in (m['out_flags'] as List? ?? [])) '$f'],
      reviewStatus = m['review_status'] as String? ?? 'pending',
      reviewNote = m['review_note'] as String? ?? '',
      edited = m['edited'] as bool? ?? false,
      stale = m['stale'] as bool? ?? false,
      hasInPhoto = m['has_in_photo'] as bool? ?? false,
      hasOutPhoto = m['has_out_photo'] as bool? ?? false,
      viaKiosk = m['via_kiosk'] as bool? ?? false,
      schedInAt = (m['sched_in_at'] as num?)?.toInt(),
      schedOutAt = (m['sched_out_at'] as num?)?.toInt(),
      inStatus = m['in_status'] as String?,
      lateMin = (m['late_min'] as num?)?.toInt() ?? 0,
      outStatus = m['out_status'] as String?,
      earlyOutMin = (m['early_out_min'] as num?)?.toInt() ?? 0,
      overtimeMin = (m['overtime_min'] as num?)?.toInt() ?? 0,
      overtimeStatus = m['overtime_status'] as String?,
      overtimeApprovedMin = (m['overtime_approved_min'] as num?)?.toInt() ?? 0,
      overtimeBonus = (m['overtime_bonus'] as num?)?.toInt(),
      overtimeNote = m['overtime_note'] as String? ?? '';

  final String id;
  final String userId;
  final String userName;
  final int clockInAt;
  final int? clockOutAt;
  final int? minutes;
  final int? inDistanceM;
  final int? outDistanceM;
  final List<String> inFlags;
  final List<String> outFlags;
  final String reviewStatus;
  final String reviewNote;
  final bool edited;
  final bool stale;
  final bool hasInPhoto;
  final bool hasOutPhoto;
  final bool viaKiosk; // dikirim dari tablet kiosk, bukan HP sendiri
  final int? schedInAt; // jadwal masuk yang berlaku (null = tidak dinilai)
  final int? schedOutAt;
  final String? inStatus; // on_time | late
  final int lateMin;
  final String? outStatus; // on_time | early | overtime
  final int earlyOutMin;
  final int overtimeMin;

  /// Keputusan lembur: null (belum ditinjau) | approved | rejected.
  final String? overtimeStatus;
  final int overtimeApprovedMin;

  /// Nominal bonus lembur; null untuk karyawan sendiri (baru terlihat di slip gaji).
  final int? overtimeBonus;
  final String overtimeNote;
}

/// Karyawan pada daftar kiosk.
class KioskStaff {
  KioskStaff.fromJson(Map<String, dynamic> m)
    : id = m['id'] as String,
      name = m['name'] as String? ?? '',
      position = m['position'] as String? ?? '',
      roleName = m['role_name'] as String? ?? '',
      hasPin = m['has_pin'] as bool? ?? false,
      consentOk = m['consent_ok'] as bool? ?? false,
      clockedIn = m['clocked_in'] as bool? ?? false;

  final String id;
  final String name;
  final String position;
  final String roleName;
  final bool hasPin;
  final bool consentOk;
  final bool clockedIn;
}

class MeData {
  MeData.fromJson(Map<String, dynamic> m)
    : open = m['open'] == null
          ? null
          : AttendanceRecord.fromJson(m['open'] as Map<String, dynamic>),
      recent = [
        for (final r in (m['recent'] as List? ?? []))
          AttendanceRecord.fromJson(r as Map<String, dynamic>),
      ],
      consentVersion = m['consent'] is Map
          ? ((m['consent'] as Map)['version'] as num?)?.toInt()
          : null;

  final AttendanceRecord? open;
  final List<AttendanceRecord> recent;
  final int? consentVersion;
}

/// Satu kejadian absen yang menunggu dikirim (disimpan lokal sampai server menerimanya).
class QueueItem {
  const QueueItem({
    required this.eventId,
    required this.kind,
    required this.clientTime,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.mocked,
    required this.liveness,
    required this.photoB64,
    this.status = 'pending', // pending | rejected
    this.error = '',
    this.userId, // terisi bila dikirim lewat kiosk (karyawan yang absen)
    this.userName = '',
    this.ticket = '',
  });

  final String eventId;
  final String kind; // in | out
  final int clientTime;
  final double lat;
  final double lng;
  final double accuracy;
  final bool mocked;
  final bool liveness;
  final String photoB64;
  final String status;
  final String error;
  final String? userId;
  final String userName;
  final String ticket; // tiket PIN dari server (hanya kiosk)

  QueueItem copyWith({String? status, String? error}) => QueueItem(
    eventId: eventId,
    kind: kind,
    clientTime: clientTime,
    lat: lat,
    lng: lng,
    accuracy: accuracy,
    mocked: mocked,
    liveness: liveness,
    photoB64: photoB64,
    status: status ?? this.status,
    error: error ?? this.error,
    userId: userId,
    userName: userName,
    ticket: ticket,
  );

  factory QueueItem.fromJson(Map<String, dynamic> m) => QueueItem(
    eventId: m['eventId'] as String,
    kind: m['kind'] as String,
    clientTime: (m['clientTime'] as num).toInt(),
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    accuracy: (m['accuracy'] as num).toDouble(),
    mocked: m['mocked'] as bool? ?? false,
    liveness: m['liveness'] as bool? ?? false,
    photoB64: m['photoB64'] as String? ?? '',
    status: m['status'] as String? ?? 'pending',
    error: m['error'] as String? ?? '',
    userId: m['userId'] as String?,
    userName: m['userName'] as String? ?? '',
    ticket: m['ticket'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'kind': kind,
    'clientTime': clientTime,
    'lat': lat,
    'lng': lng,
    'accuracy': accuracy,
    'mocked': mocked,
    'liveness': liveness,
    'photoB64': photoB64,
    'status': status,
    'error': error,
    'userId': userId,
    'userName': userName,
    'ticket': ticket,
  };
}
