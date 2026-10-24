import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// google_fonts memuat satu berkas per bobot, jadi bobot diminta lewat GoogleFonts.inter
  /// (bukan copyWith(fontWeight)) agar tidak menjadi "bold palsu".
  static TextStyle _t(double size, FontWeight weight, [Color? color]) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.rose,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.roseSoft,
      onSecondaryContainer: const Color(0xFF881337),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.bg,
      surfaceContainer: const Color(0xFFF3F4F6),
      surfaceContainerHigh: const Color(0xFFEEF0F4),
      surfaceContainerHighest: const Color(0xFFE5E7EB),
      outline: const Color(0xFFD1D5DB),
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF7F1D1D),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    ).textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    final inter = GoogleFonts.interTextTheme(base);
    TextStyle? bold(TextStyle? s, FontWeight w, {double? letterSpacing}) =>
        s == null
        ? null
        : GoogleFonts.inter(
            textStyle: s,
            fontWeight: w,
            letterSpacing: letterSpacing,
          );
    final textTheme = inter.copyWith(
      headlineLarge: bold(inter.headlineLarge, FontWeight.w800),
      headlineMedium: bold(inter.headlineMedium, FontWeight.w800),
      headlineSmall: bold(inter.headlineSmall, FontWeight.w700),
      titleLarge: bold(inter.titleLarge, FontWeight.w700, letterSpacing: -0.2),
      titleMedium: bold(inter.titleMedium, FontWeight.w600),
      titleSmall: bold(inter.titleSmall, FontWeight.w600),
      labelLarge: bold(inter.labelLarge, FontWeight.w600),
      bodySmall: inter.bodySmall?.copyWith(color: AppColors.muted),
    );

    const r12 = BorderRadius.all(Radius.circular(12));
    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: r12,
      borderSide: BorderSide(color: c, width: w),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttonText = _t(15, FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bg,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        titleTextStyle: _t(18, FontWeight.w700, AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return _t(
            12,
            selected ? FontWeight.w700 : FontWeight.w500,
            selected ? AppColors.primary : AppColors.muted,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: _t(14, FontWeight.w700),
        unselectedLabelStyle: _t(14, FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        checkmarkColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: _t(13, FontWeight.w600, AppColors.ink),
        secondaryLabelStyle: _t(13, FontWeight.w700, AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: outline(AppColors.border),
        enabledBorder: outline(AppColors.border),
        focusedBorder: outline(AppColors.primary, 2),
        errorBorder: outline(AppColors.danger),
        focusedErrorBorder: outline(AppColors.danger, 2),
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.primarySoft
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.ink,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: _t(14, FontWeight.w400, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.rose,
        textColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
