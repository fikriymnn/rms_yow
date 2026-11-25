import 'package:flutter/material.dart';

import 'app_palettes.dart';

/// Warna aplikasi yang sedang aktif. Nilainya mengikuti tema klien ([AppPalette]) dan bisa
/// berubah saat owner mengganti tema, jadi JANGAN dipakai di ekspresi `const`.
/// Ganti tema lewat [AppColors.apply] lalu bangun ulang tampilan (lihat app_theme_provider.dart).
abstract final class AppColors {
  static String paletteKey = AppPalette.kovalen.key;

  static Color primary = AppPalette.kovalen.primary;
  static Color primaryDeep = AppPalette.kovalen.primaryDeep;
  static Color primarySoft = AppPalette.kovalen.primarySoft;
  static Color rose = AppPalette.kovalen.rose;
  static Color roseSoft = AppPalette.kovalen.roseSoft;
  static Color ink = AppPalette.kovalen.ink;
  static Color inkSoft = AppPalette.kovalen.inkSoft;
  static Color inkLine = AppPalette.kovalen.inkLine;
  static Color onInkMuted = AppPalette.kovalen.onInkMuted;
  static Color sage = AppPalette.kovalen.sage;
  static Color sageSoft = AppPalette.kovalen.sageSoft;
  static Color sageInk = AppPalette.kovalen.sageInk;
  static Color sageOnInk = AppPalette.kovalen.sageOnInk;
  static Color bg = AppPalette.kovalen.bg;
  static Color surface = AppPalette.kovalen.surface;
  static Color surfaceAlt = AppPalette.kovalen.surfaceAlt;
  static Color sunken = AppPalette.kovalen.sunken;
  static Color muted = AppPalette.kovalen.muted;
  static Color faint = AppPalette.kovalen.faint;
  static Color border = AppPalette.kovalen.border;
  static Color divider = AppPalette.kovalen.divider;

  // ---- status (sama di semua tema) ----
  static Color get success => sageInk;
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFC0262D);

  /// Warna utama sebagai 'AARRGGBB' (untuk file Excel).
  static String get primaryHex => primary.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

  static void apply(AppPalette p) {
    paletteKey = p.key;
    primary = p.primary;
    primaryDeep = p.primaryDeep;
    primarySoft = p.primarySoft;
    rose = p.rose;
    roseSoft = p.roseSoft;
    ink = p.ink;
    inkSoft = p.inkSoft;
    inkLine = p.inkLine;
    onInkMuted = p.onInkMuted;
    sage = p.sage;
    sageSoft = p.sageSoft;
    sageInk = p.sageInk;
    sageOnInk = p.sageOnInk;
    bg = p.bg;
    surface = p.surface;
    surfaceAlt = p.surfaceAlt;
    sunken = p.sunken;
    muted = p.muted;
    faint = p.faint;
    border = p.border;
    divider = p.divider;
  }
}
