import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../shell/app_bar.dart';
import '../attendance/attendance_admin_page.dart';
import '../auth/auth_providers.dart';
import '../help/help_page.dart';
import '../payroll/payroll_page.dart';
import '../roles/roles_admin_page.dart';
import 'outlets_admin_page.dart';
import 'users_admin_page.dart';

/// Izin yang membuka menu Data Master (owner selalu bisa).
const kMasterDataPerms = ['users.read', 'attendance.read_all', 'payroll.manage'];

bool canOpenMasterData(AppUser u) => u.isOwner || u.canAny(kMasterDataPerms);

class _Entry {
  const _Entry(this.icon, this.title, this.subtitle, this.page);
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}

/// Data Master: pengelolaan outlet, role, pengguna, penggajian, dan tinjauan absensi.
class MasterDataPage extends ConsumerWidget {
  const MasterDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(appUserProvider).value;
    if (u == null) return const SizedBox.shrink();

    final groups = <(String, List<_Entry>)>[
      (
        'Outlet & akses',
        [
          if (u.isOwner)
            const _Entry(
              Icons.store_mall_directory_outlined,
              'Outlet',
              'Alamat, lokasi, dan radius absensi',
              OutletsAdminPage(),
            ),
          if (u.isOwner)
            const _Entry(
              Icons.admin_panel_settings_outlined,
              'Role & hak akses',
              'Buat role dan atur akses tiap fitur',
              RolesAdminPage(),
            ),
          if (u.can('users.read'))
            const _Entry(
              Icons.people_outline_rounded,
              'Pengguna',
              'Tambah, ubah, dan nonaktifkan akun',
              UsersAdminPage(),
            ),
        ],
      ),
      (
        'Tim',
        [
          if (u.can('payroll.manage'))
            const _Entry(
              Icons.payments_outlined,
              'Penggajian',
              'Atur gaji karyawan dan terbitkan slip',
              PayrollPage(),
            ),
          if (u.can('attendance.read_all'))
            const _Entry(
              Icons.fact_check_outlined,
              'Tinjauan absensi',
              'Foto, jarak, koreksi, lembur, rekap jam',
              AttendanceAdminPage(),
            ),
        ],
      ),
    ].where((g) => g.$2.isNotEmpty).toList();

    var k = 0;
    return Scaffold(
      appBar: RmsAppBar(
        title: const Text('Data Master'),
        actions: [
          IconButton(
            tooltip: 'Panduan',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const HelpPage()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                  child: Text(
                    g.$1.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.faint,
                    ),
                  ),
                ),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 84,
                  ),
                  children: [
                    for (final e in g.$2) Entrance(index: k++, child: _Tile(e)),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.e);
  final _Entry e;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => e.page)),
    child: Semantics(
      button: true,
      label: e.title,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(e.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          ],
        ),
      ),
    ),
  );
}
