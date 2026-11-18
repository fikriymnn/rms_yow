import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/layout/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/ui/motion.dart';

/// Kerangka halaman masuk.
/// HP: blok hitam dengan chevron Kovalen + kartu form yang menumpang di bawahnya.
/// Tab/Web: panel merek hitam di kiri, form di kanan.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ff = formFactorOf(c.maxWidth);
        final card = Entrance(
          offset: 24,
          child: _FormCard(title: title, subtitle: subtitle, child: child),
        );
        if (ff == FormFactor.phone) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Stack(
              children: [
                Container(
                  height: 290,
                  color: AppColors.ink,
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: _Chevron(width: 170, height: 250, opacity: 1),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Logo(),
                            const SizedBox(height: 28),
                            card,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Row(
            children: [
              Expanded(
                flex: ff == FormFactor.desktop ? 5 : 4,
                child: const _BrandPanel(),
              ),
              Expanded(
                flex: ff == FormFactor.desktop ? 4 : 5,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: card,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Chevron khas logo Kovalen (bentuk "<" tebal) dalam maroon.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.width, required this.height, this.opacity = 1});
  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, height),
      painter: _ChevronPainter(AppColors.primary.withValues(alpha: opacity)),
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // bentuk asli 760 x 1100: M520 0 H760 L310 550 L760 1100 H520 L70 550 Z
    final sx = size.width / 760, sy = size.height / 1100;
    final p = Path()
      ..moveTo(520 * sx, 0)
      ..lineTo(760 * sx, 0)
      ..lineTo(310 * sx, 550 * sy)
      ..lineTo(760 * sx, 1100 * sy)
      ..lineTo(520 * sx, 1100 * sy)
      ..lineTo(70 * sx, 550 * sy)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // logo RMS (K Kovalen + sendok-garpu), versi untuk latar gelap
      Image.asset(
        'assets/brand/rms-symbol-dark.png',
        width: 50,
        height: 50,
        filterQuality: FilterQuality.medium,
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RMS',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'BY KOVALEN TEKNOLOGI',
            style: GoogleFonts.montserrat(
              color: AppColors.sageOnInk,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    ],
  );
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x14171717), blurRadius: 30, offset: Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.45, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    Widget point(String no, String text) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              no,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.sageOnInk,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD9D3CB),
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: AppColors.ink,
      child: Stack(
        children: [
          const Positioned(
            right: -60,
            bottom: -40,
            child: _Chevron(width: 300, height: 434),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 56, 56, 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Logo(),
                const Spacer(),
                Text(
                  'Satu sistem untuk\nseluruh restoran Anda.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF6F3EE),
                    fontSize: 38,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    'Kasir, dapur, stok, absensi, dan laporan. Tetap berjalan saat internet putus.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.onInkMuted,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      point('01', 'Pesanan langsung sampai ke layar dapur'),
                      point('02', 'Stok dan pembelian terkontrol per outlet'),
                      point('03', 'Persetujuan bertingkat dengan jejak audit'),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
