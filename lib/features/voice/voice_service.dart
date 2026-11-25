import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/db/meta_db.dart';
import '../auth/auth_providers.dart';

/// Pengaturan pengumuman suara. Disimpan PER PERANGKAT (bukan per akun), karena satu akun
/// bisa dipakai bersama di beberapa perangkat (mis. foodcourt dengan akun owner).
class VoiceSettings {
  const VoiceSettings({
    required this.newOrder,
    required this.ready,
    this.rate = 0.5,
    this.repeat = 1,
    this.keepAwake = false,
  });

  final bool newOrder; // "Pesanan untuk meja 4 sudah dibuat"
  final bool ready; // "Pesanan meja 4 siap diantar"
  final double rate; // kecepatan bicara (0.3 lambat – 0.7 cepat; 0.5 normal di Android)
  final int repeat; // diucapkan 1 atau 2 kali
  final bool keepAwake; // layar tetap menyala selama aplikasi terbuka (tablet dapur / kasir)

  bool get any => newOrder || ready;

  VoiceSettings copyWith({bool? newOrder, bool? ready, double? rate, int? repeat, bool? keepAwake}) =>
      VoiceSettings(
        newOrder: newOrder ?? this.newOrder,
        ready: ready ?? this.ready,
        rate: rate ?? this.rate,
        repeat: repeat ?? this.repeat,
        keepAwake: keepAwake ?? this.keepAwake,
      );

  Map<String, dynamic> toMap() => {
    'newOrder': newOrder,
    'ready': ready,
    'rate': rate,
    'repeat': repeat,
    'keepAwake': keepAwake,
  };
}

const _key = 'voice_settings';

class VoiceSettingsNotifier extends AsyncNotifier<VoiceSettings> {
  @override
  Future<VoiceSettings> build() async {
    // hanya dibangun ulang bila izin berubah (profil disegarkan tiap menit)
    ref.watch(appUserProvider.select((a) => a.value?.permSignature));
    final u = ref.read(appUserProvider).value;
    final m = await ref.read(metaDbProvider).getMeta(_key);
    // belum pernah diatur di perangkat ini: ikuti role (dapur -> pesanan baru, pelayan -> siap)
    return VoiceSettings(
      newOrder: m?['newOrder'] as bool? ?? (u?.can('kitchen.notify') ?? false),
      ready: m?['ready'] as bool? ?? (u?.can('orders.notify_ready') ?? false),
      rate: (m?['rate'] as num?)?.toDouble() ?? 0.5,
      repeat: (m?['repeat'] as num?)?.toInt() ?? 1,
      keepAwake: m?['keepAwake'] as bool? ?? false,
    );
  }

  Future<void> save(VoiceSettings s) async {
    state = AsyncData(s);
    await ref.read(metaDbProvider).putMeta(_key, s.toMap());
  }
}

final voiceSettingsProvider = AsyncNotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);

/// Mesin text-to-speech bahasa Indonesia. Kalimat diantre dan diucapkan satu per satu.
class VoiceService {
  VoiceService(this._ref);
  final Ref _ref;
  final _tts = FlutterTts();
  final _queue = Queue<String>();
  bool _ready = false;
  bool _speaking = false;
  bool? _indonesian;

  /// Apakah suara bahasa Indonesia terpasang di perangkat (null = belum dicek / tidak diketahui).
  bool? get hasIndonesian => _indonesian;

  Future<void> _init() async {
    if (_ready) return;
    try {
      final ok = await _tts.isLanguageAvailable('id-ID');
      _indonesian = ok == true || ok == 1;
      await _tts.setLanguage(_indonesian! ? 'id-ID' : 'id');
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      /* mesin TTS tidak tersedia: speak() nanti diam-diam gagal */
    }
    _ready = true;
  }

  Future<bool> checkIndonesian() async {
    try {
      final ok = await _tts.isLanguageAvailable('id-ID');
      _indonesian = ok == true || ok == 1;
    } catch (_) {
      _indonesian = false;
    }
    return _indonesian!;
  }

  /// Ucapkan [text] (diantre bila sedang bicara). [once] = sekali saja, abaikan pengaturan ulang.
  void say(String text, {bool once = false}) {
    final s = _ref.read(voiceSettingsProvider).value;
    final times = once ? 1 : (s?.repeat ?? 1).clamp(1, 2);
    for (var i = 0; i < times; i++) {
      _queue.add(text);
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_speaking) return;
    _speaking = true;
    try {
      await _init();
      while (_queue.isNotEmpty) {
        final text = _queue.removeFirst();
        final rate = _ref.read(voiceSettingsProvider).value?.rate ?? 0.5;
        try {
          await _tts.setSpeechRate(rate);
          await _tts.speak(text);
        } catch (_) {
          _queue.clear(); // mesin suara gagal: buang antrean agar tidak menumpuk
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } finally {
      _speaking = false;
    }
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService(ref));
