import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
    final ok = await tts.isLanguageAvailable('id-ID');
    await tts.setLanguage(ok == true || ok == 1 ? 'id-ID' : 'id');
    await tts.setSpeechRate(0.5);
    await tts.awaitSpeakCompletion(true);
    await Future<void>.delayed(const Duration(milliseconds: 2600)); // tunggu bunyi notifikasi
    await tts.speak(text);
  } catch (_) {
    /* mesin suara tidak tersedia: cukup bunyi notifikasi */
  }
}
