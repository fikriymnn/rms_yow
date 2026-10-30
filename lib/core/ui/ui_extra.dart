import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Baris "label ... nilai" untuk rincian.
class KvRow extends StatelessWidget {
  const KvRow(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
    this.color,
    this.indent = 0,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(indent, 4, 0, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: bold ? 14.5 : 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: bold ? 15.5 : 13.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

/// Bilah navigasi tanggal (sebelumnya, pilih tanggal, berikutnya).
class DateBar extends StatelessWidget {
  const DateBar({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    this.onToday,
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext; // null = tombol berikutnya nonaktif
  final VoidCallback onPick;
  final VoidCallback? onToday; // null = tombol "Hari ini" disembunyikan

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Sebelumnya',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onToday != null)
          TextButton(onPressed: onToday, child: const Text('Hari ini')),
        IconButton(
          tooltip: 'Berikutnya',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    ),
  );
}
