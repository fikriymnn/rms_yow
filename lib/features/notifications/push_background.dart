import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../voice/voice_service.dart';

/// Push diterima saat aplikasi di latar belakang / tertutup.
///
/// Notifikasinya sendiri ditampilkan sistem dengan bunyi kanal (pesanan_baru / pesanan_siap).
/// Bila server menyertakan `speak` (perangkat ini menyalakan pengumuman suara), kalimatnya
/// dibacakan setelah bunyi selesai, mis. "Pesanan untuk meja 4 sudah dibuat".
///
/// Catatan: sebagian HP dengan penghemat baterai agresif bisa menahan proses ini; bunyi kanal
/// tetap terdengar sebagai cadangan.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final text = (message.data['speak'] ?? '').toString().trim();
  if (text.isEmpty) return;
  try {
    final tts = FlutterTts();
    // mesin, suara, kecepatan & nada yang dipilih di Akun → Notifikasi suara
    final v = await readVoiceFile();
    if (v?['engine'] is String) await tts.setEngine(v!['engine'] as String);
    final ok = await tts.isLanguageAvailable('id-ID');
    await tts.setLanguage(ok == true || ok == 1 ? 'id-ID' : 'id');
    if (v?['voiceName'] is String) {
      await tts.setVoice({'name': v!['voiceName'] as String, 'locale': (v['voiceLocale'] as String?) ?? 'id-ID'});
    }
    await tts.setSpeechRate((v?['rate'] as num?)?.toDouble() ?? 0.5);
    await tts.setPitch((v?['pitch'] as num?)?.toDouble() ?? 1.0);
    await tts.awaitSpeakCompletion(true);
    // tunggu nada notifikasi (kanal pesanan_baru ±3,1 dtk / pesanan_siap ±3,4 dtk) selesai dulu
    final wait = message.data['type'] == 'order_ready' ? 3700 : 3400;
    await Future<void>.delayed(Duration(milliseconds: wait));
    await tts.speak(text);
  } catch (_) {
    /* mesin suara tidak tersedia: cukup bunyi notifikasi */
  }
}
