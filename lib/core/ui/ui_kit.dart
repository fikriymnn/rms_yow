import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum Tone { neutral, success, warning, danger, info }

({Color fg, Color bg}) toneColors(Tone t) => switch (t) {
  Tone.success => (fg: const Color(0xFF047857), bg: const Color(0xFFD1FAE5)),
  Tone.warning => (fg: const Color(0xFFB45309), bg: const Color(0xFFFEF3C7)),
  Tone.danger => (fg: const Color(0xFFB91C1C), bg: const Color(0xFFFEE2E2)),
  Tone.info => (fg: AppColors.primary, bg: AppColors.primarySoft),
  Tone.neutral => (fg: AppColors.muted, bg: const Color(0xFFF3F4F6)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.fg,
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: c.fg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: GoogleFonts.inter(
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
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
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

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: const Color(0xFFC4B5FD)),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 2),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

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
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}
