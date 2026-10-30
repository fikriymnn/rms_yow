import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/features/attendance/attendance_admin_page.dart';
import 'package:rms_yow/features/attendance/consent.dart';

import '../../core/api/api_client.dart';
import '../../core/form_dialog.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../admin/outlets_admin_page.dart';
import '../admin/users_admin_page.dart';
import '../roles/roles_admin_page.dart';
import 'auth_providers.dart';
import 'outlet_picker_page.dart';

String _initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  void _toast(BuildContext c, String m) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final r = await formDialog(
      context,
      'Ganti password',
      ['Password lama', 'Password baru (min. 8 karakter)'],
      obscure: {0, 1},
    );
    if (r == null) return;
    if (r[1].length < 8) {
      _toast(context, 'Password baru minimal 8 karakter');
      return;
    }
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/change-password',
            data: {'old_password': r[0], 'new_password': r[1]},
          );
      await ref
          .read(sessionProvider.notifier)
          .expire(); // server mencabut semua sesi
      _toast(context, 'Password diganti. Silakan login ulang.');
    } catch (e) {
      _toast(context, '$e');
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref, int pending) async {
    if (pending > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ada data belum terkirim'),
          content: Text(
            '$pending data belum terkirim ke server. Data tidak hilang dan '
            'akan terkirim setelah Anda login lagi di outlet ini. Tetap keluar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(sessionProvider.notifier).logout();
  }

  Widget _heroChip(IconData? icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _actionTile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final t = toneColors(danger ? Tone.danger : Tone.info);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: t.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();
    final outlet = ref.watch(activeOutletProvider);
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final rejected = ref.read(syncControllerProvider.notifier).rejected;
    final u = session.user;
    final isOwner = u.isOwner;
    final showPrivacy = !kIsWeb && !isOwner;

    final (syncLabel, syncTone) = switch (sync) {
      SyncState.idle => ('Tersinkron', Tone.success),
      SyncState.syncing => ('Menyinkronkan…', Tone.info),
      SyncState.offline => ('Offline', Tone.warning),
      SyncState.error => ('Gagal sinkron', Tone.danger),
    };

    final hero = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.inkSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              _initials(u.name),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '@${u.username}',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _heroChip(Icons.badge_outlined, u.roleLabel),
                    _heroChip(Icons.storefront_outlined, outlet?.name ?? '-'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final outletCard = SectionCard(
      title: 'Outlet & server',
      child: Column(
        children: [
          _infoRow(
            Icons.storefront_outlined,
            'Outlet aktif',
            outlet?.name ?? '-',
            trailing: isOwner
                ? TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OutletPickerPage(canPop: true),
                      ),
                    ),
                    child: const Text('Ganti'),
                  )
                : null,
          ),
          _infoRow(Icons.dns_outlined, 'Server', session.baseUrl),
        ],
      ),
    );

    final syncCard = SectionCard(
      title: 'Sinkronisasi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusPill(syncLabel, tone: syncTone),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pending == 0
                      ? 'Semua data terkirim'
                      : '$pending data belum terkirim',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: pending == 0
                        ? AppColors.muted
                        : const Color(0xFFB45309),
                    fontWeight: pending == 0
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).syncNow(),
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sinkronkan'),
              ),
            ],
          ),
          if (rejected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.roseSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(),
                  collapsedShape: const RoundedRectangleBorder(),
                  leading: const Icon(Icons.block, color: AppColors.danger),
                  title: Text(
                    '${rejected.length} data ditolak server',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9F1239),
                    ),
                  ),
                  children: [
                    for (final r in rejected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            r,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF9F1239),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final adminCard =
        (isOwner || u.canAny(const ['users.read', 'attendance.read_all']))
        ? SectionCard(
            title: 'Pengelolaan',
            child: Column(
              children: [
                if (isOwner)
                  _actionTile(
                    Icons.store_mall_directory_outlined,
                    'Kelola outlet',
                    'Alamat, lokasi, dan radius absensi',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OutletsAdminPage(),
                      ),
                    ),
                  ),
                if (isOwner)
                  _actionTile(
                    Icons.admin_panel_settings_outlined,
                    'Master role',
                    'Buat role dan atur hak akses tiap fitur',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RolesAdminPage()),
                    ),
                  ),
                if (u.can('users.read'))
                  _actionTile(
                    Icons.people_outline,
                    'Kelola pengguna',
                    'Tambah, ubah, dan nonaktifkan akun',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsersAdminPage()),
                    ),
                  ),
                if (u.can('attendance.read_all'))
                  _actionTile(
                    Icons.fact_check_outlined,
                    'Tinjauan absensi',
                    'Foto, jarak, koreksi, dan rekap jam',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceAdminPage(),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : null;

    final securityCard = SectionCard(
      title: 'Keamanan & privasi',
      child: Column(
        children: [
          _actionTile(
            Icons.lock_outline,
            'Ganti password',
            'Anda akan diminta login ulang',
            () => _changePassword(context, ref),
          ),
          if (showPrivacy)
            _actionTile(
              Icons.privacy_tip_outlined,
              'Cabut persetujuan data absensi',
              'Hapus foto wajah dan koordinat lokasi Anda',
              () async {
                final n = await revokeConsent(context, ref);
                if (n != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Persetujuan dicabut. $n foto dihapus.'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );

    final logout = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: Color(0xFFFCA5A5)),
        minimumSize: const Size(0, 50),
      ),
      onPressed: () => _logout(context, ref, pending),
      icon: const Icon(Icons.logout),
      label: const Text('Keluar'),
    );

    Widget stack(List<Widget> cards) => Column(
      children: [
        for (final c in cards)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
      ],
    );

    final left = [outletCard, syncCard];
    final right = [if (adminCard != null) adminCard, securityCard];

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              hero,
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stack(left)),
                    const SizedBox(width: 12),
                    Expanded(child: stack(right)),
                  ],
                )
              else
                stack([...left, ...right]),
              const SizedBox(height: 4),
              logout,
            ],
          );
        },
      ),
    );
  }
}
