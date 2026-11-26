import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum Tone { neutral, success, warning, danger, info }

/// Bayangan lembut untuk kartu (kedalaman halus, tidak berat).
const kSoftShadow = [
  BoxShadow(color: Color(0x0D171717), blurRadius: 14, offset: Offset(0, 4)),
];

({Color fg, Color bg}) toneColors(Tone t) => switch (t) {
  Tone.success => (fg: AppColors.sageInk, bg: AppColors.sageSoft),
  Tone.warning => (fg: const Color(0xFF8A5A12), bg: const Color(0xFFF7EBD6)),
  Tone.danger => (fg: const Color(0xFFA3161F), bg: const Color(0xFFFBE3E1)),
  Tone.info => (fg: AppColors.primary, bg: AppColors.primarySoft),
  Tone.neutral => (fg: AppColors.muted, bg: AppColors.divider),
};

/// Lencana status kecil, mis. "12 mnt", "Habis", "Disetujui".
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.tone = Tone.neutral});
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c.fg,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Kartu angka ringkas dengan ikon berwarna.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.captionTone = Tone.neutral,
    this.tone = Tone.info,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Tone captionTone;
  final Tone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    final cap = toneColors(captionTone);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: kSoftShadow,
      ),
      child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: c.fg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: captionTone == Tone.neutral
                        ? AppColors.muted
                        : cap.fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Kartu berjudul untuk mengelompokkan isi.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
      boxShadow: kSoftShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// Keadaan kosong yang ramah: ikon, judul, penjelasan singkat, dan (opsional) tombol
/// langkah berikutnya, mis. "Tambah meja pertama".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final content = _content();
      if (!c.maxHeight.isFinite) return content;
      // ruang sempit (mis. keyboard terbuka saat mencari): bisa digulir, tidak overflow
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: content,
        ),
      );
    },
  );

  Widget _content() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Pita informasi/peringatan dengan ikon, teks yang membungkus, dan tombol opsional.
class InfoBanner extends StatelessWidget {
  const InfoBanner(
    this.text, {
    super.key,
    this.tone = Tone.info,
    this.icon,
    this.title,
    this.actionLabel,
    this.onAction,
  });
  final String text;
  final String? title;
  final Tone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _icon =>
      icon ??
      switch (tone) {
        Tone.success => Icons.check_circle_outline_rounded,
        Tone.warning => Icons.warning_amber_rounded,
        Tone.danger => Icons.error_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    final action = actionLabel != null && onAction != null
        ? TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: c.fg,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(actionLabel!),
          )
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(_icon, size: 20, color: c.fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      title!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.fg,
                      ),
                    ),
                  ),
                Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: c.fg,
                  ),
                ),
                if (action != null)
                  Align(alignment: Alignment.centerLeft, child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul bagian di dalam halaman (huruf tebal + keterangan opsional + aksi di kanan).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing, this.padding});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

/// Deretan tombol yang menyesuaikan lebar: berdampingan bila muat, bertumpuk penuh
/// bila sempit (HP kecil) - tidak pernah overflow.
class ButtonRow extends StatelessWidget {
  const ButtonRow({
    super.key,
    required this.children,
    this.spacing = 10,
    this.minButtonWidth = 150,
  });
  final List<Widget> children;
  final double spacing;
  final double minButtonWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final n = children.length;
      if (n == 0) return const SizedBox.shrink();
      if (!c.maxWidth.isFinite) {
        // lebar tak terbatas (mis. di dalam Row lain): tanpa Expanded
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              children[i],
            ],
          ],
        );
      }
      final fits = c.maxWidth >= n * minButtonWidth + (n - 1) * spacing;
      if (fits) {
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      }
      // sempit: tombol utama (terakhir) di atas, sisanya di bawahnya
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = n - 1; i >= 0; i--) ...[
            if (i < n - 1) SizedBox(height: spacing * 0.8),
            children[i],
          ],
        ],
      );
    },
  );
}

/// Bilah aksi yang menempel di bawah layar (mis. "Simpan", "Kirim"). Pakai sebagai
/// `bottomNavigationBar` Scaffold agar tombol utama selalu terlihat tanpa menggulir.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children, this.top});
  final List<Widget> children;

  /// Baris info di atas tombol (mis. total, status simpan).
  final Widget? top;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (top != null) ...[top!, const SizedBox(height: 10)],
            ButtonRow(children: children),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet standar: bisa digulir, tinggi maks 90% layar, ikut naik saat keyboard
/// muncul, dan diberi judul. Isi [builder] cukup Column biasa (jangan pakai Expanded).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool scrollable = true,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final body = Padding(padding: padding, child: Builder(builder: builder));
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.ink,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.35,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(child: SafeArea(top: false, child: body))
                    : SafeArea(top: false, child: body),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Satu pilihan pada [showChoiceSheet]: ikon + judul + keterangan.
class SheetChoice<T> {
  const SheetChoice({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
  });
  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final bool enabled;
}

/// Menu pilihan berlabel jelas (pengganti menu titik-tiga): mudah diketuk dan dibaca.
Future<T?> showChoiceSheet<T>({
  required BuildContext context,
  required List<SheetChoice<T>> choices,
  String? title,
  String? subtitle,
}) {
  return showAppSheet<T>(
    context: context,
    title: title,
    subtitle: subtitle,
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ch in choices)
          ListTile(
            enabled: ch.enabled,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ch.destructive ? toneColors(Tone.danger).bg : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                ch.icon,
                size: 21,
                color: ch.destructive ? toneColors(Tone.danger).fg : AppColors.primary,
              ),
            ),
            title: Text(
              ch.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ch.destructive ? toneColors(Tone.danger).fg : AppColors.ink,
              ),
            ),
            subtitle: ch.subtitle == null ? null : Text(ch.subtitle!),
            onTap: () => Navigator.pop(ctx, ch.value),
          ),
      ],
    ),
  );
}

/// Skala teks perangkat (dibatasi aplikasi ke 0.85-1.2). Untuk tinggi tile tetap:
/// `mainAxisExtent: 112 * textScaleOf(context)`.
double textScaleOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) / 100;

/// Kisi adaptif: jumlah kolom menyesuaikan lebar yang tersedia (HP, Tab, Web).
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.maxColumns = 4,
    this.spacing = 12,
  });
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final fit = ((c.maxWidth + spacing) / (minTileWidth + spacing)).floor();
      final cols = math.max(
        1,
        math.min(fit, math.min(maxColumns, children.length)),
      );
      // dibulatkan ke bawah: selisih pecahan piksel bisa membuat tile terakhir turun baris
      final w = ((c.maxWidth - spacing * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}
