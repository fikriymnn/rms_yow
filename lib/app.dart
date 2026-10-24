import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:rms_yow/features/attendance/clock_page.dart';
import 'package:rms_yow/features/audit/audit_providers.dart';
import 'package:rms_yow/features/auth/force_password_page.dart';
import 'package:rms_yow/features/finance/finance_providers.dart';
import 'package:rms_yow/features/home/home_page.dart';
import 'package:rms_yow/features/inventory/inventory_page.dart';
import 'package:rms_yow/features/inventory/inventory_providers.dart'
    show ingredientsProvider, recipesProvider, stockAggProvider;
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
import 'features/proposals/proposal_providers.dart';
import 'features/proposals/proposals_page.dart';
import 'features/approvals/approval_providers.dart';
import 'features/approvals/approvals_page.dart';
import 'features/notifications/notification_providers.dart';
import 'features/notifications/notification_router.dart';
import 'features/notifications/notification_service.dart';
import 'features/notifications/notifications_page.dart';
import 'features/notifications/mark_read_on_open.dart';
import 'core/theme/app_theme.dart';
import 'shell/app_shell.dart';

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
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: session.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (s) {
          if (s == null) return const LoginPage();
          if (s.user.mustChangePassword) return const ForcePasswordPage();
          if (outlet == null)
            return const OutletPickerPage(); // owner belum memilih outlet
          return const HomeShell();
        },
      ),
    );
  }
}

class _Dest {
  const _Dest(
    this.label,
    this.icon,
    this.page,
    this.roles, {
    required this.group,
    this.rank = 50,
  });
  final String label;
  final IconData icon;
  final Widget page;
  final Set<AppRole> roles;
  final String group;
  final int rank; // prioritas di bilah bawah HP
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
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
      proposalsProvider,
    ]) {
      ref.listenManual(p, (_, __) {});
    }
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<String?>(activeOutletIdProvider, (prev, next) {
      if (next != null && next != prev) {
        ref.read(syncControllerProvider.notifier).start();
      }
    });
    Future.microtask(() {
      ref.read(syncControllerProvider.notifier).start();
      ref.read(notificationServiceProvider).start();
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumeTap(ref.read(notificationTapProvider)),
    );
  }

  void _consumeTap(NotificationTap? tap) {
    if (tap == null || !mounted) return;
    ref.read(notificationTapProvider.notifier).set(null);
    openNotificationTarget(context, tap);
  }

  void _select(int i) {
    setState(() => _index = i);
    ref
        .read(syncControllerProvider.notifier)
        .syncNow(); // membuka tab = data terbaru
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).syncSoon();
      ref.invalidate(approvalCountsProvider);
      ref.read(unreadNotificationsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationTap?>(
      notificationTapProvider,
      (_, tap) => _consumeTap(tap),
    );
    final user = ref.watch(appUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Akun belum punya role. Hubungi owner.')),
      );
    }

    final all = <_Dest>[
      _Dest(
        'Dashboard',
        Icons.space_dashboard_outlined,
        const HomePage(),
        {AppRole.owner, AppRole.manager, AppRole.head_chef},
        group: 'Operasional',
        rank: 5,
      ),
      _Dest(
        'Meja',
        Icons.table_restaurant_outlined,
        const TablesPage(),
        {AppRole.owner, AppRole.manager, AppRole.cashier, AppRole.waiter},
        group: 'Operasional',
        rank: 10,
      ),
      _Dest(
        'Menu',
        Icons.restaurant_menu,
        const MenuPage(),
        {
          AppRole.owner,
          AppRole.manager,
          AppRole.head_chef,
          AppRole.cashier,
          AppRole.waiter,
        },
        group: 'Operasional',
        rank: 13,
      ),
      _Dest(
        'Dapur',
        Icons.soup_kitchen_outlined,
        const KdsPage(),
        {
          AppRole.owner,
          AppRole.manager,
          AppRole.head_chef,
          AppRole.kitchen,
          AppRole.waiter,
        },
        group: 'Operasional',
        rank: 11,
      ),
      _Dest(
        'Kas',
        Icons.point_of_sale,
        const ShiftPage(),
        {AppRole.owner, AppRole.manager, AppRole.cashier},
        group: 'Operasional',
        rank: 12,
      ),
      _Dest(
        'Laporan',
        Icons.bar_chart_rounded,
        const ReportsPage(),
        {AppRole.owner, AppRole.manager},
        group: 'Manajemen',
        rank: 16,
      ),
      _Dest(
        'Keuangan',
        Icons.account_balance_wallet_outlined,
        const FinancePage(),
        {AppRole.owner, AppRole.manager},
        group: 'Manajemen',
        rank: 17,
      ),
      _Dest(
        'Stok',
        Icons.inventory_2_outlined,
        const InventoryPage(),
        {AppRole.owner, AppRole.manager, AppRole.head_chef, AppRole.warehouse},
        group: 'Manajemen',
        rank: 14,
      ),
      _Dest(
        'Persetujuan',
        Icons.task_alt,
        const ApprovalsPage(),
        {AppRole.owner, AppRole.manager, AppRole.head_chef, AppRole.warehouse},
        group: 'Manajemen',
        rank: 15,
      ),
      _Dest(
        'Usulan',
        Icons.lightbulb_outline,
        const ProposalsPage(),
        {AppRole.owner, AppRole.head_chef},
        group: 'Manajemen',
        rank: 18,
      ),
      if (!kIsWeb)
        _Dest(
          'Absensi',
          Icons.fingerprint,
          const ClockPage(),
          {
            AppRole.manager,
            AppRole.head_chef,
            AppRole.cashier,
            AppRole.waiter,
            AppRole.kitchen,
            AppRole.warehouse,
          },
          group: 'Tim',
          rank: 20,
        ),
      _Dest(
        'Notifikasi',
        Icons.notifications_none_rounded,
        const NotificationsPage(),
        {
          AppRole.owner,
          AppRole.manager,
          AppRole.head_chef,
          AppRole.kitchen,
          AppRole.warehouse,
        },
        group: 'Akun',
        rank: 30,
      ),
      _Dest(
        'Akun',
        Icons.person_outline_rounded,
        const AccountPage(),
        {...AppRole.values},
        group: 'Akun',
        rank: 25,
      ),
    ];
    final dests = all.where((d) => d.roles.contains(user.role)).toList();
    if (_index >= dests.length) _index = 0;

    return AppShell(
      selectedIndex: _index,
      onSelect: _select,
      items: [
        for (final d in dests)
          ShellItem(
            label: d.label,
            icon: d.icon,
            group: d.group,
            rank: d.rank,
            badge: _count(d),
          ),
      ],
      child: _pageOf(dests[_index]),
    );
  }

  int _count(_Dest d) => switch (d.label) {
    'Usulan' => ref.watch(pendingProposalsCountProvider),
    'Persetujuan' => ref.watch(approvalCountsProvider).value?.inbox ?? 0,
    'Notifikasi' => ref.watch(unreadNotificationsProvider),
    _ => 0,
  };

  /// Membuka tab = datanya dianggap dilihat. Key mencegah state terbawa antar tab.
  Widget _pageOf(_Dest d) => KeyedSubtree(
    key: ValueKey(d.label),
    child: switch (d.label) {
      'Dapur' => MarkReadOnOpen(type: 'order', child: d.page),
      'Persetujuan' => MarkReadOnOpen(type: 'approval', child: d.page),
      'Usulan' => MarkReadOnOpen(type: 'proposal', child: d.page),
      _ => d.page,
    },
  );
}
