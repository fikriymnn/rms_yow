import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_palettes.dart';

/// Terapkan tema warna klien. Dipanggil dari RmsApp setiap build (murah bila tema sama).
///
/// Warna di [AppColors] diganti, lalu seluruh tampilan dibangun ulang (seperti hot reload)
/// tanpa menghapus state: perangkat lain yang sedang dipakai tidak kehilangan pesanan yang
/// sedang diketik saat owner mengganti tema.
void applyClientTheme(String? key) {
  final p = AppPalette.byKey(key);
  if (p.key == AppColors.paletteKey) return;
  AppColors.apply(p);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.reassembleApplication();
  });
}
