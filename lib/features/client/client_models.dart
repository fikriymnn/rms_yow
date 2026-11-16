/// Status langganan klien (dari server /client/status).
class Subscription {
  const Subscription({
    required this.state,
    required this.allowed,
    required this.validUntil,
    required this.graceUntil,
    required this.serverTime,
  });

  /// active | grace | expired | suspended
  final String state;
  final bool allowed;
  final int validUntil;
  final int graceUntil;
  final int serverTime;

  /// Langganan berlaku selamanya (kupon/pengaturan khusus dari CS).
  bool get lifetime => validUntil >= 253402300799000;

  bool get suspended => state == 'suspended';
  bool get inGrace => state == 'grace';

  factory Subscription.fromJson(Map<String, dynamic> m) => Subscription(
    state: m['state'] as String? ?? 'expired',
    allowed: m['allowed'] as bool? ?? false,
    validUntil: (m['valid_until'] as num?)?.toInt() ?? 0,
    graceUntil: (m['grace_until'] as num?)?.toInt() ?? 0,
    serverTime: (m['server_time'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'state': state,
    'allowed': allowed,
    'valid_until': validUntil,
    'grace_until': graceUntil,
    'server_time': serverTime,
  };
}

class ClientInfo {
  const ClientInfo({
    required this.code,
    required this.name,
    required this.subscription,
    this.features,
    this.releaseChannel = 'stable',
  });
  final String code;
  final String name;

  /// null = semua modul disewa.
  final List<String>? features;
  final String releaseChannel;
  final Subscription subscription;

  bool hasModule(String key) => features == null || features!.contains(key);

  factory ClientInfo.fromJson(Map<String, dynamic> m) => ClientInfo(
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    features: (m['features'] as List<dynamic>?)?.cast<String>(),
    releaseChannel: m['release_channel'] as String? ?? 'stable',
    subscription: Subscription.fromJson(
      Map<String, dynamic>.from(m['subscription'] as Map? ?? const {}),
    ),
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'features': features,
    'release_channel': releaseChannel,
    'subscription': subscription.toJson(),
  };
}

/// Perangkat yang sudah diaktivasi untuk satu klien (disimpan di perangkat).
class ClientState {
  const ClientState({
    required this.baseUrl,
    required this.deviceId,
    required this.deviceToken,
    required this.info,
    required this.checkedAt,
    this.blockedByServer = false,
  });
  final String baseUrl;
  final String deviceId;

  /// Dikirim sebagai header X-Device-Token saat login RMS dan cek status.
  final String deviceToken;
  final ClientInfo info;

  /// Jam perangkat saat status terakhir berhasil diambil dari server.
  final int checkedAt;

  /// Server menjawab 402 (langganan habis) sejak status terakhir.
  final bool blockedByServer;

  ClientState copyWith({ClientInfo? info, int? checkedAt, bool? blockedByServer}) =>
      ClientState(
        baseUrl: baseUrl,
        deviceId: deviceId,
        deviceToken: deviceToken,
        info: info ?? this.info,
        checkedAt: checkedAt ?? this.checkedAt,
        blockedByServer: blockedByServer ?? this.blockedByServer,
      );

  factory ClientState.fromJson(Map<String, dynamic> m) => ClientState(
    baseUrl: m['base_url'] as String,
    deviceId: m['device_id'] as String,
    deviceToken: m['device_token'] as String,
    info: ClientInfo.fromJson(Map<String, dynamic>.from(m['info'] as Map)),
    checkedAt: (m['checked_at'] as num?)?.toInt() ?? 0,
    blockedByServer: m['blocked_by_server'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'base_url': baseUrl,
    'device_id': deviceId,
    'device_token': deviceToken,
    'info': info.toJson(),
    'checked_at': checkedAt,
    'blocked_by_server': blockedByServer,
  };
}

enum BlockReason { none, expired, suspended, offlineTooLong }
