import 'dart:async';

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
import 'package:rms_yow/features/printing/receipt_template.dart';
import 'package:rms_yow/features/purchasing/purchasing_providers.dart';
import 'package:rms_yow/features/reports/reports_page.dart';
import 'package:rms_yow/features/reservations/reservation_providers.dart';
import 'package:rms_yow/features/shifts/shift_page.dart';
import 'package:rms_yow/features/shifts/shift_providers.dart';
import 'package:rms_yow/features/tables/tables_providers.dart';
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
import 'features/notifications/mark_read_on_open.dart';
import 'core/theme/app_theme.dart';
import 'shell/app_shell.dart';
import 'features/attendance/kiosk_page.dart';
import 'features/pos/pos_page.dart';
import 'features/update/update_service.dart';
import 'features/update/update_ui.dart';
import 'features/client/client_models.dart';
import 'features/client/client_pages.dart';
import 'features/client/client_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';

/// Koleksi yang di-mirror ke lokal. Tambah di sini tiap modul baru.

class RmsApp extends ConsumerWidget {
  const RmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider);
    final blocked = ref.watch(clientBlockProvider);
    final session = ref.watch(sessionProvider);
    final outlet = ref.watch(activeOutletProvider);
    // versi aplikasi di bawah batas minimum server: wajib diperbarui dulu
    final forced = ref.watch(mandatoryUpdateProvider).value;
    return MaterialApp(
      title: 'RMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      // urutan: update wajib -> aktivasi perangkat klien -> langganan -> login RMS
      home: forced != null
          ? UpdateRequiredPage(info: forced)
          : client.isLoading && !client.hasValue
          ? const AppLoadingScreen()
          : client.value == null
          ? const ClientLoginPage()
          : blocked != BlockReason.none
          ? const SubscriptionPage()
          : session.when(
              loading: () => const Scaffold(
                body: Center(child: AppLoader()),
              ),
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
    this.perm, {
    required this.group,
    this.rank = 50,
  });
  final String label;
  final IconData icon;
  final Widget page;
  final String? perm;
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
  Timer? _profileTimer;
  bool _updateOffered = false;

  @override
  void initState() {
    super.initState();
    // Muat data inti sejak awal, jangan menunggu tab dibuka.
    for (final p in <ProviderListenable<Object?>>[
      appUserProvider,
      shiftsProvider,
      currentShiftProvider,
      printerSettingsProvider,
      receiptTemplateProvider,
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
    // tawarkan pembaruan sekali per sesi aplikasi
    ref.listenManual(latestUpdateProvider, (_, next) async {
      final info = next.value;
      if (info == null || _updateOffered || !mounted) return;
      final v = await ref.read(appVersionProvider.future);
      if (!mounted || !info.isNewerThan(v.build)) return;
      _updateOffered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showUpdateDialog(
            context,
            info,
            mandatory: info.isMandatoryFor(v.build),
          );
        }
      });
    }, fireImmediately: true);
    // Izin diubah owner di Master role -> segarkan tiap menit; bila berubah,
    // unduh ulang data agar koleksi yang baru boleh dibaca ikut terunduh.
    _profileTimer = Timer.periodic(
      const Duration(seconds: 60),
      (t) {
        ref.read(sessionProvider.notifier).refreshProfile();
        // status langganan klien tiap 10 menit
        if (t.tick % 10 == 0) ref.read(clientProvider.notifier).refreshStatus();
      },
    );
    ref.listenManual<String?>(
      appUserProvider.select((a) => a.value?.permSignature),
      (prev, next) {
        if (prev != null && next != null && prev != next) {
          ref.read(syncControllerProvider.notifier).start();
        }
      },
    );
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
    _profileTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).refreshProfile();
      ref.read(clientProvider.notifier).refreshStatus();
      ref.read(syncControllerProvider.notifier).syncSoon();
      ref.invalidate(approvalCountsProvider);
      ref.invalidate(latestUpdateProvider);
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
    if (user.can('attendance.kiosk')) return const KioskPage();
    // outlet foodcourt: tanpa meja; kasir langsung memesan dan membayar
    final foodcourt = ref.watch(activeOutletProvider)?.isFoodcourt ?? false;

    // perm = izin yang membuka tab ini (null = semua pengguna). Daftar izinnya
    // diatur owner di Master role; tab muncul bila role memegang izin tersebut.
    final all = <_Dest>[
      _Dest(
        'Beranda',
        Icons.home_outlined,
        const HomePage(),
        'dashboard.read',
        group: 'Operasional',
        rank: 5,
      ),
      if (foodcourt)
        const _Dest(
          'Order',
          Icons.shopping_bag_outlined,
          PosPage(foodcourt: true),
          'orders.create',
          group: 'Operasional',
          rank: 10,
        )
      else
        _Dest(
          'Meja',
          Icons.table_restaurant_outlined,
          const TablesPage(),
          'orders.create',
          group: 'Operasional',
          rank: 10,
        ),
      _Dest(
        'Menu',
        Icons.restaurant_menu,
        const MenuPage(),
        'menu.read',
        group: 'Operasional',
        rank: 13,
      ),
      _Dest(
        'Dapur',
        Icons.soup_kitchen_outlined,
        const KdsPage(),
        'kitchen.read',
        group: 'Operasional',
        rank: 11,
      ),
      _Dest(
        'Kas',
        Icons.point_of_sale,
        const ShiftPage(),
        'shifts.read',
        group: 'Operasional',
        rank: 12,
      ),
      _Dest(
        'Laporan',
        Icons.bar_chart_rounded,
        const ReportsPage(),
        'reports.read',
        group: 'Manajemen',
        rank: 16,
      ),
      _Dest(
        'Keuangan',
        Icons.account_balance_wallet_outlined,
        const FinancePage(),
        'finance.read',
        group: 'Manajemen',
        rank: 17,
      ),
      _Dest(
        'Stok',
        Icons.inventory_2_outlined,
        const InventoryPage(),
        'stock.read',
        group: 'Manajemen',
        rank: 14,
      ),
      _Dest(
        'Persetujuan',
        Icons.task_alt,
        const ApprovalsPage(),
        'approvals.read',
        group: 'Manajemen',
        rank: 15,
      ),
      _Dest(
        'Usulan',
        Icons.lightbulb_outline,
        const ProposalsPage(),
        'proposals.read',
        group: 'Manajemen',
        rank: 18,
      ),
      if (!kIsWeb)
        _Dest(
          'Absensi',
          Icons.fingerprint,
          const ClockPage(),
          'attendance.clock',
          group: 'Tim',
          rank: 20,
        ),
      // Notifikasi tidak lagi jadi tab: lonceng di appbar setiap halaman utama.
      _Dest(
        'Akun',
        Icons.person_outline_rounded,
        const AccountPage(),
        null,
        group: 'Akun',
        rank: 25,
      ),
    ];
    final dests = all
        .where((d) => d.perm == null || user.can(d.perm!))
        .toList();
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
