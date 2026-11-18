import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/layout/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/ui/motion.dart';
import '../features/auth/auth_providers.dart';
import '../features/notifications/notification_providers.dart';
import '../features/notifications/notification_router.dart';
import '../features/notifications/notifications_page.dart';

/// Penanda bahwa sebuah halaman adalah tab utama di dalam cangkang aplikasi.
/// [RmsAppBar] memakai ini untuk menampilkan lonceng notifikasi hanya di halaman utama
/// (halaman yang dibuka lewat Navigator.push berada di luar cakupan ini).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required super.child});

  static bool inShell(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>() != null;

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// AppBar aplikasi. Sama dengan [AppBar], ditambah lonceng notifikasi otomatis
/// di ujung kanan bila halaman ini tab utama.
class RmsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RmsAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.systemOverlayStyle,
    this.shape,
    this.showBell,
  });

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final ShapeBorder? shape;

  /// null = otomatis (tampil di tab utama).
  final bool? showBell;

  static const height = 64.0;

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final bell = showBell ?? ShellScope.inShell(context);
    return AppBar(
      title: title,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: height,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      systemOverlayStyle: systemOverlayStyle,
      shape: shape,
      actions: [
        ...?actions,
        if (bell) ...[const SizedBox(width: 4), const NotificationBell()],
        const SizedBox(width: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------- lonceng

/// Tombol lonceng dengan jumlah belum dibaca. Bergoyang singkat saat ada notifikasi baru.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});
  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    ref.listenManual<int>(unreadNotificationsProvider, (prev, next) {
      if (prev != null && next > prev && mounted) _shake.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    if (user == null || !user.can('notifications.read')) return const SizedBox.shrink();
    final n = ref.watch(unreadNotificationsProvider);
    final label = n == 0 ? 'Notifikasi' : 'Notifikasi, $n belum dibaca';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: 'Notifikasi',
        child: Pressable(
          onTap: () => showNotificationPanel(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) => Transform.rotate(
                    // ayunan lonceng: makin kecil hingga diam
                    angle: 0.32 * (1 - _shake.value) * math.sin(_shake.value * 6 * math.pi),
                    alignment: const Alignment(0, -0.8),
                    child: child,
                  ),
                  child: Icon(
                    n > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                    size: 22,
                    color: AppColors.ink,
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: AnimatedScale(
                    scale: n > 0 ? 1 : 0,
                    duration: Motion.base,
                    curve: Curves.easeOutBack,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Text(
                        n > 99 ? '99+' : '$n',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- panel

/// Panel notifikasi: turun dari atas di HP, melayang di kanan atas di tablet/desktop.
Future<void> showNotificationPanel(BuildContext context) {
  final phone = context.formFactor == FormFactor.phone;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x6B171717),
    transitionDuration: Motion.slow,
    pageBuilder: (ctx, _, _) => SafeArea(
      bottom: false,
      child: Align(
        alignment: phone ? Alignment.topCenter : Alignment.topRight,
        child: Padding(
          padding: phone ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 8, 16, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: phone ? double.infinity : 420,
              maxHeight: MediaQuery.sizeOf(ctx).height * (phone ? 0.86 : 0.8),
            ),
            child: _NotificationPanel(phone: phone),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.curve, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: Offset(0, phone ? -0.12 : -0.04), end: Offset.zero).animate(a),
          child: child,
        ),
      );
    },
  );
}

class _NotificationPanel extends ConsumerStatefulWidget {
  const _NotificationPanel({required this.phone});
  final bool phone;
  @override
  ConsumerState<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends ConsumerState<_NotificationPanel> {
  final _fresh = <String>{}; // belum dibaca saat panel dibuka: tetap ditandai selama terbuka
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<AppNotification>>>(
      notificationsListProvider,
      (_, next) {
        final ids = [
          for (final n in next.value ?? <AppNotification>[])
            if (!n.read) n.id,
        ];
        if (ids.isEmpty) return;
        _fresh.addAll(ids);
        // listener pertama berjalan di initState: setState ditunda ke microtask
        Future.microtask(() {
          if (mounted) setState(() {});
        });
        markNotificationsRead(ref, all: true); // panel dibuka = dibaca
      },
      fireImmediately: true,
    );
  }

  static const _filters = [
    ('all', 'Semua'),
    ('order', 'Pesanan'),
    ('approval', 'Persetujuan'),
    ('proposal', 'Usulan'),
  ];

  bool _match(AppNotification n) => switch (_filter) {
    'all' => true,
    'order' => n.type == 'order' || n.type == 'order_ready',
    _ => n.type == _filter,
  };

  void _open(AppNotification n) {
    final nav = Navigator.of(context);
    final page = notificationPage(NotificationTap(n.type, n.refId));
    nav.pop();
    if (page != null) nav.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _all() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsListProvider);
    final radius = widget.phone
        ? const BorderRadius.vertical(bottom: Radius.circular(28))
        : BorderRadius.circular(24);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      elevation: 18,
      shadowColor: const Color(0x55171717),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifikasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Tutup',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(44, 44),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      label: f.$2,
                      selected: _filter == f.$1,
                      onTap: () => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: async.when(
              loading: () => const SizedBox(height: 260, child: SkeletonList(count: 4)),
              error: (_, _) => const _PanelMessage(
                icon: Icons.cloud_off_rounded,
                text: 'Notifikasi tidak bisa dimuat. Periksa koneksi lalu coba lagi.',
              ),
              data: (all) {
                final list = all.where(_match).take(20).toList();
                if (list.isEmpty) {
                  return const _PanelMessage(
                    icon: Icons.notifications_off_outlined,
                    text: 'Belum ada notifikasi di sini.',
                  );
                }
                final fresh = [for (final n in list) if (_fresh.contains(n.id)) n];
                final old = [for (final n in list) if (!_fresh.contains(n.id)) n];
                var i = 0;
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 4),
                  children: [
                    if (fresh.isNotEmpty) const _GroupLabel('BARU'),
                    for (final n in fresh)
                      Entrance(index: i++, child: _NotifRow(n: n, fresh: true, onTap: () => _open(n))),
                    if (old.isNotEmpty) _GroupLabel(fresh.isEmpty ? 'TERAKHIR' : 'SEBELUMNYA'),
                    for (final n in old)
                      Entrance(index: i++, child: _NotifRow(n: n, fresh: false, onTap: () => _open(n))),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: OutlinedButton(onPressed: _all, child: const Text('Lihat semua notifikasi')),
          ),
          if (widget.phone)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Motion.fast,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? AppColors.ink : AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF57514B),
        ),
      ),
    ),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
    child: Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: AppColors.faint,
      ),
    ),
  );
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 30, color: AppColors.faint),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}

/// Warna & ikon per jenis notifikasi.
({IconData icon, Color fg, Color bg}) notificationStyle(String type) => switch (type) {
  'order' => (icon: Icons.soup_kitchen_outlined, fg: AppColors.primary, bg: AppColors.primarySoft),
  'order_ready' => (icon: Icons.room_service_outlined, fg: AppColors.sageInk, bg: AppColors.sageSoft),
  'proposal' => (icon: Icons.lightbulb_outline_rounded, fg: Colors.white, bg: AppColors.ink),
  _ => (icon: Icons.task_alt_rounded, fg: Colors.white, bg: AppColors.ink),
};

String notificationAgo(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt';
  if (d.inHours < 24) return '${d.inHours} jam';
  if (d.inDays == 1) return 'Kemarin';
  return DateFormat('d MMM').format(DateTime.fromMillisecondsSinceEpoch(ms));
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.n, required this.fresh, required this.onTap});
  final AppNotification n;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = notificationStyle(n.type);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 11, 20, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(st.icon, size: 19, color: st.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: fresh ? FontWeight.w700 : FontWeight.w600,
                      color: fresh ? AppColors.ink : const Color(0xFF57514B),
                    ),
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.4,
                        color: fresh ? AppColors.muted : AppColors.faint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  notificationAgo(n.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.faint,
                  ),
                ),
                if (fresh) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
