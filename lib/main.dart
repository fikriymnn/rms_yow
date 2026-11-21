import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // data nama bulan/hari bahasa Indonesia untuk DateFormat(..., 'id_ID') (mis. "21 Nov 2026")
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: RmsApp()));
}
