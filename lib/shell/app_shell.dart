import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/form_factor.dart';
import '../core/sync/sync_controller.dart';
import '../core/theme/app_colors.dart';
import '../features/auth/auth_providers.dart';
import 'package:google_fonts/google_fonts.dart';

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

Widget _badged(Widget icon, int n) =>
    n > 0 ? Badge(label: Text(_badgeText(n)), child: icon) : icon;

/// Cangkang aplikasi: bilah bawah (HP), sidebar ramping (Tab), sidebar penuh (Web/Desktop).
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
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(28),
                  ),
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

class _Content extends StatelessWidget {
  const _Content({required this.child, required this.offline, this.maxWidth});
  final Widget child;
  final bool offline;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final body = maxWidth == null
        ? child
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: child,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        if (offline) const _OfflineBar(),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.roseSoft,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off, size: 16, color: Color(0xFF9F1239)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Offline: perubahan tersimpan di perangkat dan dikirim saat tersambung',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9F1239),
            ),
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
  final ranked = [...all]
    ..sort((a, b) => items[a].rank.compareTo(items[b].rank));
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
    final pos = bar.indexOf(selectedIndex);
    final barSelected = more.contains(selectedIndex)
        ? bar.length
        : (pos < 0 ? 0 : pos);

    return Scaffold(
      body: content,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: barSelected,
          onDestinationSelected: (i) {
            if (i < bar.length) {
              onSelect(bar[i]);
            } else {
              _openMore(context, more);
            }
          },
          destinations: [
            for (final i in bar)
              NavigationDestination(
                icon: _badged(Icon(items[i].icon), items[i].badge),
                label: items[i].label,
              ),
            if (more.isNotEmpty)
              NavigationDestination(
                icon: _badged(const Icon(Icons.apps_rounded), moreBadge),
                label: 'Lainnya',
              ),
          ],
        ),
      ),
    );
  }

  void _openMore(BuildContext context, List<int> more) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              for (final i in more)
                _MoreTile(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final ShellItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink;
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _badged(Icon(item.icon, size: 26, color: color), item.badge),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Tab dan Web

String _initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
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
          nav.add(
            last == null
                ? const SizedBox(height: 4)
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
          );
        } else {
          nav.add(
            Padding(
              padding: EdgeInsets.fromLTRB(22, last == null ? 4 : 18, 22, 6),
              child: Text(
                it.group.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
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
      width: compact ? 92 : 268,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 0 : 20,
                20,
                compact ? 0 : 20,
                12,
              ),
              child: _Brand(compact: compact, subtitle: outletLabel),
            ),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: nav),
            ),
            _syncTile(ref, sync),
            const SizedBox(height: 4),
            if (user != null) _userTile(ref, user),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _syncTile(WidgetRef ref, SyncState s) {
    final (icon, label, color) = switch (s) {
      SyncState.idle => (
        Icons.cloud_done_outlined,
        'Tersinkron',
        const Color(0xFF6EE7B7),
      ),
      SyncState.syncing => (
        Icons.sync,
        'Menyinkronkan…',
        const Color(0xFFFDE68A),
      ),
      SyncState.offline => (
        Icons.cloud_off,
        'Offline',
        const Color(0xFFFDA4AF),
      ),
      SyncState.error => (
        Icons.error_outline,
        'Gagal sinkron',
        const Color(0xFFFDA4AF),
      ),
    };
    void sync() => ref.read(syncControllerProvider.notifier).syncNow();
    if (compact) {
      return Tooltip(
        message: '$label (ketuk untuk sinkron)',
        child: IconButton(
          onPressed: sync,
          icon: Icon(icon, color: color),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: sync,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userTile(WidgetRef ref, AppUser user) {
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: Text(
        _initials(user.name),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
    return PopupMenuButton<String>(
      tooltip: user.name,
      onSelected: (v) {
        if (v == 'logout') ref.read(sessionProvider.notifier).logout();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Keluar'),
            ],
          ),
        ),
      ],
      child: compact
          ? avatar
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          user.roleLabel,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_vert, color: Colors.white38, size: 18),
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
    final logo = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFFA78BFA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.rose,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 2),
            ),
          ),
        ),
      ],
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
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              Text(
                subtitle ?? 'Restaurant Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
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
    final fg = selected ? Colors.white : Colors.white70;
    final radius = BorderRadius.circular(compact ? 14 : 12);
    final Widget inner = compact
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _badged(Icon(item.icon, size: 24, color: fg), item.badge),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 22, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _badgeText(item.badge),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        elevation: selected ? 3 : 0,
        shadowColor: AppColors.primary.withValues(alpha: .5),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: Colors.white10,
          onTap: onTap,
          child: inner,
        ),
      ),
    );
  }
}
