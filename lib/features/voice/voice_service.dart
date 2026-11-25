import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

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
    this.engine,
    this.voiceName,
    this.voiceLocale,
    this.pitch = 1.0,
  });

  final bool newOrder; // "Pesanan untuk meja 4 sudah dibuat"
  final bool ready; // "Pesanan meja 4 siap diantar"
  final double rate; // kecepatan bicara (0.3 lambat – 0.7 cepat; 0.5 normal di Android)
  final int repeat; // diucapkan 1 atau 2 kali
  final bool keepAwake; // layar tetap menyala selama aplikasi terbuka (tablet dapur / kasir)
  final String? engine; // mesin TTS (mis. com.google.android.tts, com.samsung.SMT); null = bawaan HP
  final String? voiceName; // suara terpilih; null = suara bawaan bahasa Indonesia
  final String? voiceLocale;
  final double pitch; // tinggi nada (0.8 rendah – 1.2 tinggi)

  bool get any => newOrder || ready;

  VoiceSettings copyWith({
    bool? newOrder,
    bool? ready,
    double? rate,
    int? repeat,
    bool? keepAwake,
    double? pitch,
  }) => VoiceSettings(
    newOrder: newOrder ?? this.newOrder,
    ready: ready ?? this.ready,
    rate: rate ?? this.rate,
    repeat: repeat ?? this.repeat,
    keepAwake: keepAwake ?? this.keepAwake,
    engine: engine,
    voiceName: voiceName,
    voiceLocale: voiceLocale,
    pitch: pitch ?? this.pitch,
  );

  /// Ganti mesin / suara (null = bawaan).
  VoiceSettings withVoice({String? engine, String? name, String? locale}) => VoiceSettings(
    newOrder: newOrder,
    ready: ready,
    rate: rate,
    repeat: repeat,
    keepAwake: keepAwake,
    engine: engine,
    voiceName: name,
    voiceLocale: locale,
    pitch: pitch,
  );

  Map<String, dynamic> toMap() => {
    'newOrder': newOrder,
    'ready': ready,
    'rate': rate,
    'repeat': repeat,
    'keepAwake': keepAwake,
    'engine': engine,
    'voiceName': voiceName,
    'voiceLocale': voiceLocale,
    'pitch': pitch,
  };
}

const _key = 'voice_settings';

/// Berkas kecil berisi mesin & suara terpilih, dibaca handler push saat aplikasi tertutup
/// (isolate latar belakang tidak memakai database aplikasi).
Future<File?> voiceFile() async {
  if (kIsWeb) return null;
  try {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/voice.json');
  } catch (_) {
    return null;
  }
}

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
      engine: m?['engine'] as String?,
      voiceName: m?['voiceName'] as String?,
      voiceLocale: m?['voiceLocale'] as String?,
      pitch: (m?['pitch'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Future<void> save(VoiceSettings s) async {
    final prev = state.value;
    state = AsyncData(s);
    await ref.read(metaDbProvider).putMeta(_key, s.toMap());
    try {
      await (await voiceFile())?.writeAsString(jsonEncode(s.toMap()));
    } catch (_) {}
    if (prev?.engine != s.engine || prev?.voiceName != s.voiceName) {
      await ref.read(voiceServiceProvider).reset();
    }
  }
}

final voiceSettingsProvider = AsyncNotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);

/// Satu pilihan suara bahasa Indonesia dari mesin TTS di HP.
class VoiceOption {
  const VoiceOption({required this.name, required this.locale, required this.label, required this.online});
  final String name;
  final String locale;
  final String label; // nama ramah, mis. "Suara C · online"
  final bool online; // butuh internet (biasanya lebih natural)
}

bool _isIndonesian(String locale) {
  final l = locale.toLowerCase().replaceAll('_', '-');
  return l.startsWith('id') || l.startsWith('in-') || l == 'in' || l.startsWith('ind');
}

/// Nama ramah dari nama suara Google ("id-id-x-idc-network" -> "Suara C · online").
String _labelOf(String name, bool online, int index) {
  final m = RegExp(r'-x-id([a-z])', caseSensitive: false).firstMatch(name);
  final letter = m != null ? m.group(1)!.toUpperCase() : '${index + 1}';
  return 'Suara $letter · ${online ? 'online (lebih natural)' : 'offline'}';
}

/// Nada yang diputar sebelum kalimat (sama dengan bunyi notifikasi push).
enum Chime {
  newOrder('sounds/pesanan_baru.ogg'),
  ready('sounds/pesanan_siap.ogg');

  const Chime(this.asset);
  final String asset;
}

typedef _Item = ({String text, Chime? chime});

/// Mesin text-to-speech bahasa Indonesia. Pengumuman diantre: nada notifikasi diputar sampai
/// selesai, BARU kalimatnya dibacakan.
class VoiceService {
  VoiceService(this._ref);
  final Ref _ref;
  final _tts = FlutterTts();
  final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final _queue = Queue<_Item>();
  bool _ready = false;
  bool _speaking = false;
  bool? _indonesian;

  /// Apakah suara bahasa Indonesia terpasang di perangkat (null = belum dicek / tidak diketahui).
  bool? get hasIndonesian => _indonesian;

  /// Terapkan mesin & suara terpilih pada pengucapan berikutnya.
  Future<void> reset() async {
    _ready = false;
  }

  Future<void> _init() async {
    if (_ready) return;
    final s = _ref.read(voiceSettingsProvider).value;
    try {
      if (s?.engine != null) await _tts.setEngine(s!.engine!);
      final ok = await _tts.isLanguageAvailable('id-ID');
      _indonesian = ok == true || ok == 1;
      await _tts.setLanguage(_indonesian! ? 'id-ID' : 'id');
      if (s?.voiceName != null) {
        await _tts.setVoice({'name': s!.voiceName!, 'locale': s.voiceLocale ?? 'id-ID'});
      }
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

  /// Mesin TTS yang terpasang (Android), mis. Google, Samsung.
  Future<List<String>> engines() async {
    if (kIsWeb) return const [];
    try {
      final e = await _tts.getEngines;
      return [for (final x in (e as List? ?? const [])) '$x'];
    } catch (_) {
      return const [];
    }
  }

  /// Daftar suara bahasa Indonesia pada [engine] (null = mesin aktif).
  Future<List<VoiceOption>> indonesianVoices({String? engine}) async {
    try {
      if (engine != null) await _tts.setEngine(engine);
      _ready = false; // mesin mungkin berganti
      final raw = await _tts.getVoices;
      final list = <VoiceOption>[];
      for (final v in (raw as List? ?? const [])) {
        if (v is! Map) continue;
        final name = '${v['name'] ?? ''}';
        final locale = '${v['locale'] ?? ''}';
        if (name.isEmpty || !_isIndonesian(locale)) continue;
        final net = '${v['network_required'] ?? ''}' == '1' ||
            '${v['network_required'] ?? ''}' == 'true' ||
            name.toLowerCase().contains('network');
        list.add(VoiceOption(name: name, locale: locale, label: '', online: net));
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      return [
        for (var i = 0; i < list.length; i++)
          VoiceOption(
            name: list[i].name,
            locale: list[i].locale,
            label: _labelOf(list[i].name, list[i].online, i),
            online: list[i].online,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Dengarkan contoh dengan suara tertentu (tanpa menyimpan pilihan).
  Future<void> preview(String text, {String? engine, VoiceOption? voice}) async {
    try {
      await _tts.stop();
      if (engine != null) await _tts.setEngine(engine);
      await _tts.setLanguage('id-ID');
      if (voice != null) await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      final s = _ref.read(voiceSettingsProvider).value;
      await _tts.setSpeechRate(s?.rate ?? 0.5);
      await _tts.setPitch(s?.pitch ?? 1.0);
      await _tts.speak(text);
    } catch (_) {}
    _ready = false; // pengumuman berikutnya memakai pilihan tersimpan lagi
  }

  /// Ucapkan [text] (diantre bila sedang bicara). [chime] = nada notifikasi dulu, lalu kalimat.
  /// [once] = sekali saja, abaikan pengaturan "ulangi 2 kali".
  void say(String text, {Chime? chime, bool once = false}) {
    final s = _ref.read(voiceSettingsProvider).value;
    final times = once ? 1 : (s?.repeat ?? 1).clamp(1, 2);
    for (var i = 0; i < times; i++) {
      // nada hanya di awal; pengulangan langsung kalimatnya
      _queue.add((text: text, chime: i == 0 ? chime : null));
    }
    unawaited(_drain());
  }

  /// Putar nada dan tunggu sampai selesai (maks. 6 detik).
  Future<void> _playChime(Chime c) async {
    try {
      final done = _player.onPlayerComplete.first;
      await _player.play(AssetSource(c.asset));
      await done.timeout(const Duration(seconds: 6));
    } catch (_) {
      /* nada gagal diputar: lanjut ke kalimat */
    }
  }

  Future<void> _drain() async {
    if (_speaking) return;
    _speaking = true;
    try {
      await _init();
      while (_queue.isNotEmpty) {
        final item = _queue.removeFirst();
        final s = _ref.read(voiceSettingsProvider).value;
        if (item.chime != null) {
          await _playChime(item.chime!);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        try {
          await _tts.setSpeechRate(s?.rate ?? 0.5);
          await _tts.setPitch(s?.pitch ?? 1.0);
          await _tts.speak(item.text);
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

/// Nama ramah mesin TTS.
String engineLabel(String pkg) => switch (pkg) {
  'com.google.android.tts' => 'Google',
  'com.samsung.SMT' => 'Samsung',
  'com.svox.pico' => 'Pico',
  _ when pkg.toLowerCase().contains('vocalizer') => 'Vocalizer',
  _ when pkg.toLowerCase().contains('acapela') => 'Acapela',
  _ => pkg.split('.').last,
};

/// Dipakai handler push di latar belakang.
Future<Map<String, dynamic>?> readVoiceFile() async {
  try {
    final f = await voiceFile();
    if (f == null || !await f.exists()) return null;
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
