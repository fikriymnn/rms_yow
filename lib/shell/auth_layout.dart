import 'package:flutter/material.dart';

import '../core/layout/form_factor.dart';
import '../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kerangka halaman masuk: HP = header gelap + kartu form; Tab/Web = panel merek + form.
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
        final card = _FormCard(title: title, subtitle: subtitle, child: child);
        if (ff == FormFactor.phone) {
          return Scaffold(
            body: Stack(
              children: [
                Container(
                  height: 300,
                  decoration: const BoxDecoration(gradient: _gradient),
                ),
                Positioned(
                  top: -50,
                  right: -40,
                  child: _glow(AppColors.primary, 190, .45),
                ),
                Positioned(
                  top: 130,
                  left: -50,
                  child: _glow(AppColors.rose, 120, .28),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _Logo(),
                            const SizedBox(height: 24),
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

const _gradient = LinearGradient(
  colors: [AppColors.ink, AppColors.inkSoft],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

Widget _glow(Color color, double size, double alpha) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: color.withValues(alpha: alpha),
  ),
);

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFA78BFA)],
          ),
        ),
        child: const Icon(Icons.restaurant, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Text(
        'RMS',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
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
    final th = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: th.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: th.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 20),
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
    Widget bullet(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFC4B5FD), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: const BoxDecoration(gradient: _gradient),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _glow(AppColors.primary, 320, .35),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _glow(AppColors.rose, 240, .22),
          ),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Logo(),
                const SizedBox(height: 40),
                Text(
                  'Kelola restoran Anda\ndengan lebih cerdas.',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dari kasir sampai laporan, tetap berjalan meski internet putus.',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 28),
                bullet(
                  Icons.soup_kitchen_outlined,
                  'Pesanan langsung sampai ke dapur',
                ),
                bullet(
                  Icons.inventory_2_outlined,
                  'Stok dan pembelian terkontrol',
                ),
                bullet(
                  Icons.verified_user_outlined,
                  'Persetujuan bertingkat dan jejak audit',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
