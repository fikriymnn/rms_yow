String durationText(int minutes) =>
    '${minutes ~/ 60}j ${(minutes % 60).toString().padLeft(2, '0')}m';

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
      hasOutPhoto = m['has_out_photo'] as bool? ?? false;

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
  };
}
