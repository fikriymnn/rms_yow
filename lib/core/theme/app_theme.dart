import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Gaya teks dasar aplikasi (Plus Jakarta Sans, dibundel di assets/google_fonts).
TextStyle appText(double size, FontWeight weight, [Color? color]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color);

/// Angka rupiah/jumlah: lebar digit seragam agar kolom rapi.
const tabular = [FontFeature.tabularFigures()];

/// Transisi halaman: pudar + geser naik sedikit (masuk), pudar ke belakang (keluar).
class _RmsPageTransitions extends PageTransitionsBuilder {
  const _RmsPageTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final behind = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(behind),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

abstract final class AppTheme {
  static TextStyle _t(double size, FontWeight weight, [Color? color]) =>
      appText(size, weight, color);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.sunken,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.sage,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.sageSoft,
      onTertiaryContainer: AppColors.sageInk,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surfaceAlt,
      surfaceContainer: AppColors.bg,
      surfaceContainerHigh: const Color(0xFFF1EDE7),
      surfaceContainerHighest: AppColors.sunken,
      outline: const Color(0xFFD6CEC2),
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFBE3E1),
      onErrorContainer: const Color(0xFF7A1A1C),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.bg,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    ).textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    TextStyle? w(TextStyle? s, FontWeight weight, {double? letterSpacing}) => s == null
        ? null
        : GoogleFonts.plusJakartaSans(
            textStyle: s,
            fontWeight: weight,
            letterSpacing: letterSpacing,
          );
    final textTheme = jakarta.copyWith(
      displaySmall: w(jakarta.displaySmall, FontWeight.w800, letterSpacing: -1),
      headlineLarge: w(jakarta.headlineLarge, FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: w(jakarta.headlineMedium, FontWeight.w800, letterSpacing: -0.6),
      headlineSmall: w(jakarta.headlineSmall, FontWeight.w800, letterSpacing: -0.4),
      titleLarge: w(jakarta.titleLarge, FontWeight.w800, letterSpacing: -0.3),
      titleMedium: w(jakarta.titleMedium, FontWeight.w700, letterSpacing: -0.1),
      titleSmall: w(jakarta.titleSmall, FontWeight.w700),
      labelLarge: w(jakarta.labelLarge, FontWeight.w700),
      bodySmall: jakarta.bodySmall?.copyWith(color: AppColors.muted),
    );

    const r14 = BorderRadius.all(Radius.circular(14));
    OutlineInputBorder outline(Color c, [double width = 1]) => OutlineInputBorder(
      borderRadius: r14,
      borderSide: BorderSide(color: c, width: width),
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final buttonText = _t(15, FontWeight.w700);
    const transitions = _RmsPageTransitions();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.divider,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: transitions,
          TargetPlatform.iOS: transitions,
          TargetPlatform.windows: transitions,
          TargetPlatform.macOS: transitions,
          TargetPlatform.linux: transitions,
          TargetPlatform.fuchsia: transitions,
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: 16,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: _t(20, FontWeight.w800, AppColors.ink).copyWith(letterSpacing: -0.3),
        actionsPadding: const EdgeInsets.only(right: 8),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: _t(19, FontWeight.w800, AppColors.ink).copyWith(letterSpacing: -0.3),
        contentTextStyle: _t(14.5, FontWeight.w400, const Color(0xFF3F3A35)),
        barrierColor: const Color(0x73171717),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x73171717),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        dragHandleSize: Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 23,
            color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return _t(
            11.5,
            selected ? FontWeight.w800 : FontWeight.w600,
            selected ? AppColors.primary : AppColors.muted,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.muted,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: AppColors.primary),
          borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
        ),
        dividerColor: AppColors.border,
        labelStyle: _t(14, FontWeight.w800),
        unselectedLabelStyle: _t(14, FontWeight.w600),
        overlayColor: const WidgetStatePropertyAll(Color(0x0F7D0B1E)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        checkmarkColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelStyle: _t(13, FontWeight.w600, AppColors.ink),
        secondaryLabelStyle: _t(13, FontWeight.w800, AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: outline(AppColors.border),
        enabledBorder: outline(AppColors.border),
        focusedBorder: outline(AppColors.ink, 1.6),
        errorBorder: outline(AppColors.danger),
        focusedErrorBorder: outline(AppColors.danger, 1.6),
        labelStyle: _t(14, FontWeight.w500, AppColors.muted),
        floatingLabelStyle: _t(14, FontWeight.w700, AppColors.ink),
        hintStyle: _t(14, FontWeight.w400, AppColors.faint),
        prefixIconColor: AppColors.faint,
        suffixIconColor: AppColors.faint,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sunken,
          disabledForegroundColor: AppColors.faint,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: buttonShape,
          textStyle: buttonText,
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Color(0x1FFFFFFF)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(64, 50),
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
        extendedTextStyle: _t(14.5, FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.ink,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          textStyle: WidgetStatePropertyAll(_t(13.5, FontWeight.w700)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.faint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.sunken,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent,
        ),
        side: const BorderSide(color: Color(0xFFBFB6AA), width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.faint,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: _t(15, FontWeight.w600, AppColors.ink),
        subtitleTextStyle: _t(13, FontWeight.w400, AppColors.muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        elevation: 0,
        contentTextStyle: _t(14, FontWeight.w500, Colors.white),
        actionTextColor: AppColors.sageOnInk,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: _t(12.5, FontWeight.w600, Colors.white),
        waitDuration: const Duration(milliseconds: 400),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.primary,
        textColor: Colors.white,
        textStyle: _t(10.5, FontWeight.w800),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x33171717),
        textStyle: _t(14, FontWeight.w600, AppColors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        todayBorder: const BorderSide(color: AppColors.primary),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
