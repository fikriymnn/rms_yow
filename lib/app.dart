import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:rms_yow/features/attendance/attendance_page.dart';
import 'package:rms_yow/features/attendance/attendance_providers.dart';
import 'package:rms_yow/features/audit/audit_providers.dart';
import 'package:rms_yow/features/finance/finance_providers.dart';
import 'package:rms_yow/features/inventory/inventory_page.dart';
import 'package:rms_yow/features/inventory/inventory_providers.dart'
    show
        ingredientsProvider,
        recipesProvider,
        stockMovesProvider,
        stockAggProvider;
import 'package:rms_yow/features/menu/menu_providers.dart';
import 'package:rms_yow/features/orders/order_providers.dart';
import 'package:rms_yow/features/printing/printer_settings.dart';
import 'package:rms_yow/features/purchasing/purchasing_providers.dart';
import 'package:rms_yow/features/reports/reports_page.dart';
import 'package:rms_yow/features/reservations/reservation_providers.dart';
import 'package:rms_yow/features/shifts/shift_page.dart';
import 'package:rms_yow/features/shifts/shift_providers.dart';
import 'package:rms_yow/features/tables/table_providers.dart';

import 'core/sync/sync_controller.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/login_page.dart';
import 'features/finance/finance_page.dart';
import 'features/menu/menu_page.dart';
import 'features/tables/tables_page.dart';
import 'features/kds/kds_page.dart';
import 'features/auth/account_page.dart';
import 'features/auth/outlet_picker_page.dart';

/// Koleksi yang di-mirror ke lokal. Tambah di sini tiap modul baru.

class RmsApp extends ConsumerWidget {
  const RmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final outlet = ref.watch(activeOutletProvider);
    return MaterialApp(
      title: 'RMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: session.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (s) {
          if (s == null) return const LoginPage();
          if (outlet == null)
            return const OutletPickerPage(); // owner belum memilih outlet
          return const HomeShell();
        },
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
    // Muat data inti sejak awal, jangan menunggu tab dibuka.
    for (final p in <ProviderListenable<Object?>>[
      appUserProvider,
      shiftsProvider,
      currentShiftProvider,
      printerSettingsProvider,
      menuItemsProvider,
      tablesProvider,
      ordersProvider,
      itemStatusProvider,
      auditLogsProvider,
      ingredientsProvider,
      recipesProvider,
      stockAggProvider,
      expensesProvider,
      suppliersProvider,
      purchaseOrdersProvider,
      receiptsProvider,
      supplierPaymentsProvider,
      reservationsProvider,
      employeesProvider,
      attendanceProvider,
    ]) {
      ref.listenManual(p, (_, __) {});
    }
    ref.listenManual<String?>(activeOutletIdProvider, (prev, next) {
      if (next != null && next != prev) {
        ref.read(syncControllerProvider.notifier).start();
      }
    });
    Future.microtask(() => ref.read(syncControllerProvider.notifier).start());
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
      _Dest('Dapur', Icons.soup_kitchen, const KdsPage(), {
        AppRole.owner,
        AppRole.manager,
        AppRole.kitchen,
        AppRole.waiter,
      }),
      _Dest('Kas', Icons.point_of_sale, const ShiftPage(), {
        AppRole.owner,
        AppRole.manager,
        AppRole.cashier,
      }),
      _Dest('Laporan', Icons.bar_chart, const ReportsPage(), {
        AppRole.owner,
        AppRole.manager,
      }),
      _Dest('Stok', Icons.inventory_2_outlined, const InventoryPage(), {
        AppRole.owner,
        AppRole.manager,
        AppRole.warehouse,
      }),
      _Dest(
        'Keuangan',
        Icons.account_balance_wallet_outlined,
        const FinancePage(),
        {AppRole.owner, AppRole.manager},
      ),
      _Dest('Absensi', Icons.access_time, const AttendancePage(), {
        ...AppRole.values,
      }),
      _Dest('Akun', Icons.person_outline, const AccountPage(), {
        ...AppRole.values,
      }),
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
          : _bottomBar(dests),
    );
  }

  Widget _bottomBar(List<_Dest> dests) {
    const maxBar = 5;
    if (dests.length <= maxBar) {
      return NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in dests)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      );
    }
    final shown = dests.take(maxBar - 1).toList();
    final more = dests.skip(maxBar - 1).toList();
    return NavigationBar(
      selectedIndex: _index < shown.length ? _index : shown.length,
      onDestinationSelected: (i) async {
        if (i < shown.length) {
          setState(() => _index = i);
          return;
        }
        final picked = await showModalBottomSheet<int>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < more.length; k++)
                  ListTile(
                    leading: Icon(more[k].icon),
                    title: Text(more[k].label),
                    selected: _index == shown.length + k,
                    onTap: () => Navigator.pop(ctx, shown.length + k),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) setState(() => _index = picked);
      },
      destinations: [
        for (final d in shown)
          NavigationDestination(icon: Icon(d.icon), label: d.label),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'Lainnya',
        ),
      ],
    );
  }
}
