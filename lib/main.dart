import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/notifications/push_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // data nama bulan/hari bahasa Indonesia untuk DateFormat(..., 'id_ID') (mis. "21 Nov 2026")
  await initializeDateFormatting('id_ID');
  // push saat aplikasi tertutup: membacakan pengumuman pesanan (harus didaftarkan sebelum runApp)
  if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  runApp(const ProviderScope(child: RmsApp()));
}
