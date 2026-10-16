import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/form_dialog.dart';
import '../../core/sync/sync_controller.dart';
import 'auth_providers.dart';
import 'outlet_picker_page.dart';
import '../admin/outlets_admin_page.dart';
import '../admin/users_admin_page.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();
    final outlet = ref.watch(activeOutletProvider);
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final rejected = ref.read(syncControllerProvider.notifier).rejected;
    final u = session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(u.name),
            subtitle: Text('${u.username} • ${u.role.name}'),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(outlet?.name ?? '-'),
            subtitle: const Text('Outlet aktif'),
            trailing: u.role == AppRole.owner
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
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(session.baseUrl),
            subtitle: const Text('Server'),
          ),
          ListTile(
            leading: Icon(switch (sync) {
              SyncState.idle => Icons.cloud_done_outlined,
              SyncState.syncing => Icons.sync,
              SyncState.offline => Icons.cloud_off_outlined,
              SyncState.error => Icons.error_outline,
            }),
            title: Text('Sinkronisasi: ${sync.name}'),
            subtitle: Text(
              pending == 0
                  ? 'Semua data terkirim'
                  : '$pending data belum terkirim',
            ),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(syncControllerProvider.notifier).syncNow(),
              child: const Text('Sinkronkan'),
            ),
          ),
          if (rejected.isNotEmpty)
            ExpansionTile(
              leading: Icon(
                Icons.block,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text('${rejected.length} data ditolak server'),
              children: [
                for (final r in rejected) ListTile(dense: true, title: Text(r)),
              ],
            ),
          if (u.role == AppRole.owner)
            ListTile(
              leading: const Icon(Icons.store_mall_directory_outlined),
              title: const Text('Kelola outlet'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OutletsAdminPage()),
              ),
            ),
          if (u.isManager)
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Kelola pengguna'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersAdminPage()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Ganti password'),
            onTap: () => _changePassword(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () => _logout(context, ref, pending),
          ),
        ],
      ),
    );
  }
}
