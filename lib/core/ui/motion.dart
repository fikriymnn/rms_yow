/// Gerak & animasi bersama: dialog yang membesar halus, loader bermerek, kerangka
/// berkilau saat memuat, kemunculan bertahap, angka yang menghitung naik.
///
/// Prinsip: singkat (160–320 ms), easeOutCubic, tidak memantul berlebihan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ---------------------------------------------------------------- durasi

abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}

// ---------------------------------------------------------------- dialog

/// Pengganti `showDialog`: kotak dialog muncul dari 94% + pudar, latar meredup.
/// Parameter sama dengan `showDialog` yang dipakai di aplikasi ini.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: useRootNavigator).context,
  );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? const Color(0x73171717),
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: Motion.base,
    pageBuilder: (ctx, _, _) => themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (ctx, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.curve, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(a),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------- loader

/// Loader bermerek: tiga batang (maroon, hitam, sage) naik-turun bergantian.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.label, this.size = 28, this.onDark = false});
  final String? label;
  final double size;
  final bool onDark;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      widget.onDark ? Colors.white : AppColors.ink,
      widget.onDark ? AppColors.sageOnInk : AppColors.sage,
    ];
    final s = widget.size;
    final bars = AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: s * 0.14),
            Container(
              width: s * 0.22,
              height: s * (0.35 + 0.65 * _wave(_c.value, i)),
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(s * 0.11),
              ),
            ),
          ],
        ],
      ),
    );
    final loader = Semantics(
      label: widget.label ?? 'Memuat',
      child: SizedBox(height: s, child: bars),
    );
    if (widget.label == null) return loader;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        loader,
        const SizedBox(height: 14),
        Text(
          widget.label!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.onDark ? AppColors.onInkMuted : AppColors.muted,
          ),
        ),
      ],
    );
  }

  /// 0..1, tiap batang tertinggal sepertiga siklus.
  static double _wave(double t, int i) {
    final p = (t - i / 3) % 1.0;
    return (math.sin(p * 2 * math.pi - math.pi / 2) + 1) / 2;
  }
}

/// Layar penuh saat memuat (dipakai di awal aplikasi).
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(child: AppLoader(size: 34, label: label)),
  );
}

// ---------------------------------------------------------------- kerangka (skeleton)

/// Kilau bergerak di atas anak-anaknya (pakai bersama [SkeletonBox]).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final dx = rect.width * (2.4 * _c.value - 1.2);
        return LinearGradient(
          colors: [AppColors.sunken, Color(0xFFF8F5F0), AppColors.sunken],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: _Slide(dx),
        ).createShader(rect);
      },
      child: child,
    ),
  );
}

class _Slide extends GradientTransform {
  const _Slide(this.dx);
  final double dx;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Kotak abu hangat sebagai pengganti konten yang sedang dimuat.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.sunken,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Kerangka daftar: baris kartu dengan ikon, dua garis teks, dan angka di kanan.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.padding = const EdgeInsets.all(16)});
  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        // kilau hanya di kotak abu, bukan di latar kartu putih
        child: Shimmer(
          child: Row(
          children: [
            const SkeletonBox(width: 40, height: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: i.isEven ? 0.7 : 0.5,
                    child: const SkeletonBox(height: 12),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: i.isEven ? 0.4 : 0.6,
                    child: const SkeletonBox(height: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonBox(width: 56, height: 14),
          ],
          ),
        ),
      ),
  );
}

// ---------------------------------------------------------------- kemunculan

/// Pudar + naik sedikit saat pertama muncul. [index] memberi jeda bertahap (30 ms/item, maks 10).
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = Motion.slow,
  });
  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.curve);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 30 * math.min(widget.index, 10));
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _a.value,
      child: Transform.translate(
        offset: Offset(0, widget.offset * (1 - _a.value)),
        child: child,
      ),
    ),
  );
}

// ---------------------------------------------------------------- angka

/// Angka yang menghitung naik ke [value] (mis. penjualan hari ini).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });
  final num value;
  final String Function(num v) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: duration,
    curve: Curves.easeOutQuart,
    builder: (_, v, _) => Text(format(value is int ? v.round() : v), style: style),
  );
}

// ---------------------------------------------------------------- tekan

/// Mengecil sedikit saat ditekan (kartu, tombol besar, tile meja).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}

/// Titik status yang berdenyut pelan (mis. "Online", pesanan baru).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, Color? color, this.size = 8}) : _color = color;
  final Color? _color; // null = warna aksen tema (bisa berubah)
  Color get color => _color ?? AppColors.sage;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * (1 + 1.4 * _c.value),
              height: s * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}
