import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_controller.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/login_page.dart';
import 'features/menu/menu_page.dart';
import 'features/tables/tables_page.dart';

/// Koleksi yang di-mirror ke lokal. Tambah di sini tiap modul baru.
const syncedCollections = ['menu_items', 'tables', 'orders'];

class RmsApp extends ConsumerWidget {
  const RmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'RMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: auth.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (user) => user == null ? const LoginPage() : const HomeShell(),
      ),
    );
  }
}

class _Dest {
  const _Dest(this.label, this.icon, this.page, this.roles);
  final String label;
  final IconData icon;
  final Widget page;
  final Set<AppRole> roles;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(syncControllerProvider.notifier).start(syncedCollections),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final sync = ref.watch(syncControllerProvider);
    if (userAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (userAsync.hasError) {
      return Scaffold(
        body: Center(child: Text('Gagal memuat akun: ${userAsync.error}')),
      );
    }
    final user = userAsync.value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Akun belum punya role. Hubungi owner.')),
      );
    }

    final all = <_Dest>[
      _Dest('Meja', Icons.table_restaurant, const TablesPage(), {
        AppRole.owner,
        AppRole.manager,
        AppRole.cashier,
        AppRole.waiter,
      }),
      _Dest('Menu', Icons.restaurant_menu, const MenuPage(), {
        AppRole.owner,
        AppRole.manager,
        AppRole.cashier,
        AppRole.waiter,
      }),
      // TODO: KDS, Laporan
    ];
    final dests = all.where((d) => d.roles.contains(user.role)).toList();
    final wide = MediaQuery.sizeOf(context).width >= 800; // web / tablet

    final badge = Chip(
      avatar: Icon(switch (sync) {
        SyncState.idle => Icons.cloud_done,
        SyncState.syncing => Icons.sync,
        SyncState.offline => Icons.cloud_off,
        SyncState.error => Icons.error_outline,
      }, size: 18),
      label: Text(sync.name),
    );

    return Scaffold(
      body: Row(
        children: [
          if (wide && dests.length >= 2)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              trailing: Padding(padding: const EdgeInsets.all(8), child: badge),
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          Expanded(child: dests[_index].page),
        ],
      ),
      bottomNavigationBar: (wide || dests.length < 2)
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in dests)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}
