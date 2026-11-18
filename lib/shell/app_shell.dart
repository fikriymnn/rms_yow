import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/layout/form_factor.dart';
import '../core/sync/sync_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/ui/motion.dart';
import '../features/auth/auth_providers.dart';
import 'app_bar.dart';

class ShellItem {
  const ShellItem({
    required this.label,
    required this.icon,
    required this.group,
    this.badge = 0,
    this.rank = 50,
  });
  final String label;
  final IconData icon;
  final String group;
  final int badge;
  final int rank; // prioritas di bilah bawah HP (kecil = lebih penting)
}

String _badgeText(int n) => n > 99 ? '99+' : '$n';

TextStyle _jk(double size, FontWeight w, Color c, {double? ls}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);

/// Lencana angka kecil (maroon) di pojok ikon.
Widget _badged(Widget icon, int n, {Color ring = AppColors.surface}) => n <= 0
    ? icon
    : Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -6,
            right: -9,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: ring, width: 2),
              ),
              child: Text(_badgeText(n), style: _jk(10, FontWeight.w800, Colors.white)),
            ),
          ),
        ],
      );

/// Cangkang aplikasi: bilah bawah (HP), rail hitam (Tab), sidebar hitam (Web/Desktop).
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
    this.outletLabel,
  });

  final List<ShellItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;
  final String? outletLabel; // mis. nama outlet; opsional

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(syncControllerProvider) == SyncState.offline;
    return LayoutBuilder(
      builder: (context, c) {
        final ff = formFactorOf(c.maxWidth);
        final content = _Content(
          maxWidth: ff == FormFactor.desktop ? 1480 : null,
          offline: offline,
          child: child,
        );
        if (ff == FormFactor.phone) {
          return _PhoneShell(
            items: items,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            content: content,
          );
        }
        return Scaffold(
          backgroundColor: AppColors.ink,
          body: Row(
            children: [
              _Sidebar(
                compact: ff == FormFactor.tablet,
                items: items,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                outletLabel: outletLabel,
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
                  child: ColoredBox(color: AppColors.bg, child: content),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Isi tab aktif: ganti tab = pudar + geser naik tipis.
class _Content extends StatelessWidget {
  const _Content({required this.child, required this.offline, this.maxWidth});
  final Widget child;
  final bool offline;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final switched = AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a),
          child: c,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: ShellScope(key: child.key, child: child),
    );
    final body = maxWidth == null
        ? switched
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: switched,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          child: offline ? const _OfflineBar() : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.ink,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.onInkMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Offline. Perubahan disimpan di perangkat dan dikirim saat tersambung.',
            textAlign: TextAlign.center,
            style: _jk(12, FontWeight.w600, const Color(0xFFE9E4DD)),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- HP

(List<int>, List<int>) _split(List<ShellItem> items) {
  final all = [for (var i = 0; i < items.length; i++) i];
  if (items.length <= 5) return (all, <int>[]);
  final ranked = [...all]..sort((a, b) => items[a].rank.compareTo(items[b].rank));
  final bar = ranked.take(4).toList()..sort(); // pertahankan urutan asli
  return (
    bar,
    [
      for (final i in all)
        if (!bar.contains(i)) i,
    ],
  );
}

class _PhoneShell extends StatelessWidget {
  const _PhoneShell({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.content,
  });
  final List<ShellItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final (bar, more) = _split(items);
    final moreBadge = more.fold<int>(0, (s, i) => s + items[i].badge);
    final inMore = more.contains(selectedIndex);
    return Scaffold(
      body: content,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                for (final i in bar)
                  Expanded(
                    child: _BarItem(
                      icon: items[i].icon,
                      label: items[i].label,
                      badge: items[i].badge,
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
                if (more.isNotEmpty)
                  Expanded(
                    child: _BarItem(
                      icon: Icons.grid_view_rounded,
                      label: inMore ? items[selectedIndex].label : 'Lainnya',
                      badge: moreBadge,
                      selected: inMore,
                      onTap: () => _openMore(context, more),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMore(BuildContext context, List<int> more) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('Menu lainnya', style: _jk(17, FontWeight.w800, AppColors.ink, ls: -0.2)),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  for (var k = 0; k < more.length; k++)
                    Entrance(
                      index: k,
                      child: _MoreTile(
                        item: items[more[k]],
                        selected: more[k] == selectedIndex,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(more[k]);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primary : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.curve,
              width: selected ? 56 : 40,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: _badged(Icon(icon, size: 23, color: fg), badge)),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: _jk(11, selected ? FontWeight.w800 : FontWeight.w600, fg),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item, required this.selected, required this.onTap});
  final ShellItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _badged(
              Icon(item.icon, size: 24, color: fg),
              item.badge,
              ring: selected ? AppColors.primary : AppColors.bg,
            ),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _jk(13, FontWeight.w700, fg),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Tab dan Web

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.compact,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.outletLabel,
  });
  final bool compact;
  final List<ShellItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String? outletLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final sync = ref.watch(syncControllerProvider);

    final nav = <Widget>[];
    String? last;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.group != last) {
        if (compact) {
          if (last != null) {
            nav.add(
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                child: Divider(color: AppColors.inkLine, height: 1),
              ),
            );
          }
        } else {
          nav.add(
            Padding(
              padding: EdgeInsets.fromLTRB(24, last == null ? 4 : 20, 24, 8),
              child: Text(
                it.group.toUpperCase(),
                style: _jk(11, FontWeight.w800, const Color(0xFF7D7670), ls: 1.3),
              ),
            ),
          );
        }
        last = it.group;
      }
      nav.add(
        _NavTile(
          item: it,
          selected: i == selectedIndex,
          compact: compact,
          onTap: () => onSelect(i),
        ),
      );
    }

    return SizedBox(
      width: compact ? 96 : 256,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 0 : 22, 20, compact ? 0 : 22, 18),
              child: _Brand(compact: compact, subtitle: outletLabel),
            ),
            Expanded(child: ListView(padding: EdgeInsets.zero, children: nav)),
            _syncTile(ref, sync),
            const SizedBox(height: 6),
            if (user != null) _userTile(ref, user),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _syncTile(WidgetRef ref, SyncState s) {
    final (label, color, live) = switch (s) {
      SyncState.idle => ('Tersinkron', AppColors.sageOnInk, false),
      SyncState.syncing => ('Menyinkronkan…', const Color(0xFFE8C77A), true),
      SyncState.offline => ('Offline', const Color(0xFFE59AA6), false),
      SyncState.error => ('Gagal sinkron', const Color(0xFFE59AA6), false),
    };
    void sync() => ref.read(syncControllerProvider.notifier).syncNow();
    final dot = live
        ? PulseDot(color: color, size: 7)
        : SizedBox(
            width: 16.8,
            height: 16.8,
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          );
    return Tooltip(
      message: '$label (ketuk untuk sinkron)',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: sync,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 22, vertical: 8),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              dot,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  compact ? (s == SyncState.idle ? 'Online' : label) : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _jk(compact ? 11 : 13, FontWeight.w700, const Color(0xFFBDB6AE)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userTile(WidgetRef ref, AppUser user) {
    final avatar = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(_initials(user.name), style: _jk(14, FontWeight.w800, const Color(0xFFF6F3EE))),
    );
    return PopupMenuButton<String>(
      tooltip: user.name,
      position: PopupMenuPosition.over,
      onSelected: (v) {
        if (v == 'logout') ref.read(sessionProvider.notifier).logout();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: _jk(14, FontWeight.w700, AppColors.ink)),
              Text(user.roleLabel, style: _jk(12, FontWeight.w500, AppColors.muted)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Keluar'),
            ],
          ),
        ),
      ],
      child: compact
          ? avatar
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _jk(14, FontWeight.w700, Colors.white),
                        ),
                        Text(user.roleLabel, style: _jk(12, FontWeight.w500, AppColors.onInkMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more_rounded, color: Color(0xFF7D7670), size: 18),
                ],
              ),
            ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact, this.subtitle});
  final bool compact;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    // logo RMS (K Kovalen + sendok-garpu), versi untuk latar gelap
    final logo = Image.asset(
      'assets/brand/rms-symbol-dark.png',
      width: 44,
      height: 44,
      filterQuality: FilterQuality.medium,
    );
    if (compact) return Center(child: logo);
    return Row(
      children: [
        logo,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RMS',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                subtitle ?? 'Restaurant Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _jk(12, FontWeight.w500, AppColors.onInkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });
  final ShellItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : const Color(0xFFB3ACA4);
    final radius = BorderRadius.circular(16);
    final ring = selected ? AppColors.primary : AppColors.ink;
    final Widget inner = compact
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _badged(Icon(item.icon, size: 23, color: fg), item.badge, ring: ring),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _jk(11, selected ? FontWeight.w800 : FontWeight.w600, fg),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 21, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: _jk(14, selected ? FontWeight.w800 : FontWeight.w600, fg),
                  ),
                ),
                if (item.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _badgeText(item.badge),
                      style: _jk(11, FontWeight.w800, selected ? AppColors.primary : Colors.white),
                    ),
                  ),
              ],
            ),
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 2),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            hoverColor: const Color(0x14FFFFFF),
            splashColor: const Color(0x1FFFFFFF),
            onTap: onTap,
            child: inner,
          ),
        ),
      ),
    );
  }
}
