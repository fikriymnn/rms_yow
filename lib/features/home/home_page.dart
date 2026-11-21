import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/features/tables/tables_providers.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../approvals/approval_providers.dart';
import '../approvals/approvals_page.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_page.dart';
import '../inventory/inventory_providers.dart';
import '../kds/kds_page.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../proposals/proposal_providers.dart';
import '../proposals/proposals_page.dart';
import '../reservations/reservation.dart';
import '../reservations/reservation_providers.dart';
import '../shifts/shift_page.dart';
import '../shifts/shift_providers.dart';
import '../tables/dining_table.dart';
import 'home_stats.dart';
import 'package:rms_yow/shell/app_bar.dart';

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _bulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _age(int minutes) =>
    minutes < 60 ? '$minutes mnt' : '${minutes ~/ 60} j ${minutes % 60} mnt';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // umur pesanan dan batas "hari ini" ikut berjalan
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    if (user == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final isManager = user.can('finance.read');
    final canKitchen = user.can('kitchen.read'); // modul KDS

    final orders = ref.watch(ordersProvider).value ?? <Order>[];
    final stats = computeHomeStats(orders, now);
    final open = orders.where((o) => o.status == OrderStatus.open).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tableNames = {
      for (final t in ref.watch(tablesProvider).value ?? <DiningTable>[])
        t.id: t.name,
    };

    final levels = ref.watch(stockLevelsProvider);
    final low =
        [
          for (final i
              in ref.watch(ingredientsProvider).value ?? <Ingredient>[])
            if (i.minStock > 0 && (levels[i.id] ?? 0) <= i.minStock) i,
        ]..sort(
          (a, b) => ((levels[a.id] ?? 0) / a.minStock).compareTo(
            (levels[b.id] ?? 0) / b.minStock,
          ),
        );

    final approvals = ref.watch(approvalCountsProvider).value?.inbox ?? 0;
    // usulan menu: hanya bila modulnya aktif (izin dicabut otomatis saat modul dimatikan)
    final canDecideProposals = user.can('proposals.decide');
    final proposals = canDecideProposals ? ref.watch(pendingProposalsCountProvider) : 0;
    final shift = ref.watch(currentShiftProvider);

    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
    final bookings = (ref.watch(reservationsProvider).value ?? <Reservation>[])
        .where(
          (r) =>
              r.status == ReservationStatus.booked &&
              r.at >= dayStart &&
              r.at < dayEnd,
        )
        .length;

    // ---- aksi cepat (sesuai izin) ----
    final actions = <_QuickAction>[
      if (user.can('kitchen.read'))
        _QuickAction(Icons.soup_kitchen_outlined, 'Dapur', () => _open(const KdsPage())),
      if (user.can('shifts.read'))
        _QuickAction(Icons.point_of_sale_rounded, 'Kas', () => _open(const ShiftPage())),
      if (user.can('stock.read'))
        _QuickAction(Icons.inventory_2_outlined, 'Stok', () => _open(const InventoryPage())),
      if (user.can('approvals.read'))
        _QuickAction(Icons.task_alt_rounded, 'Persetujuan', () => _open(const ApprovalsPage())),
      if (canDecideProposals)
        _QuickAction(Icons.lightbulb_outline_rounded, 'Usulan', () => _open(const ProposalsPage())),
    ].take(4).toList();

    // ---- perlu tindakan ----
    String oldestOpen() {
      if (open.isEmpty) return '';
      final o = open.last; // terlama
      final m = ((nowMs - o.createdAt) / 60000).floor().clamp(0, 99999);
      return 'Terlama ${_age(m)} · ${_where(o, tableNames)}';
    }

    final todo = <_Todo>[
      if (canKitchen || user.can('orders.create'))
        _Todo(
          open.length,
          'Pesanan aktif',
          open.isEmpty ? 'Belum ada pesanan aktif' : oldestOpen(),
          AppColors.primary,
          canKitchen ? () => _open(const KdsPage()) : null,
        ),
      if (user.can('approvals.read'))
        _Todo(
          approvals,
          'Menunggu persetujuan',
          approvals == 0 ? 'Tidak ada pengajuan' : 'Ketuk untuk meninjau',
          AppColors.ink,
          () => _open(const ApprovalsPage()),
        ),
      if (user.can('stock.read'))
        _Todo(
          low.length,
          'Stok menipis',
          low.isEmpty
              ? 'Semua stok aman'
              : low.take(2).map((i) => i.name).join(', ') +
                    (low.length > 2 ? ', +${low.length - 2}' : ''),
          AppColors.sageInk,
          () => _open(const InventoryPage()),
        ),
      if (canDecideProposals)
        _Todo(
          proposals,
          'Usulan menu',
          proposals == 0 ? 'Tidak ada usulan baru' : 'Menunggu keputusan Anda',
          AppColors.ink,
          () => _open(const ProposalsPage()),
        ),
      if (isManager && user.can('reservations.read') && bookings > 0)
        _Todo(bookings, 'Reservasi hari ini', 'Sudah dipesan tamu', AppColors.ink, null),
    ];

    final outlet = ref.watch(activeOutletProvider);
    final hero = isManager
        ? _SalesHero(stats: stats, now: now)
        : _Greeting(name: user.name, now: now, shiftOpen: shift != null);

    final left = <Widget>[
      hero,
      if (actions.isNotEmpty) _QuickActions(actions),
      if (todo.isNotEmpty) _TodoCard(todo),
    ];
    final right = <Widget>[
      if (isManager && stats.top.isNotEmpty) _BestSellers(stats.top),
      if (open.isNotEmpty)
        SectionCard(
          title: 'Pesanan aktif',
          trailing: canKitchen
              ? TextButton(
                  onPressed: () => _open(const KdsPage()),
                  child: const Text('Lihat dapur'),
                )
              : null,
          child: Column(
            children: [
              for (final o in open.take(5))
                _ActiveOrderRow(order: o, tableNames: tableNames, nowMs: nowMs),
            ],
          ),
        ),
      if (low.isNotEmpty)
        SectionCard(
          title: 'Stok menipis',
          trailing: TextButton(
            onPressed: () => _open(const InventoryPage()),
            child: const Text('Lihat stok'),
          ),
          child: Column(
            children: [
              for (final i in low.take(5))
                _LowStockRow(ingredient: i, level: levels[i.id] ?? 0),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: RmsAppBar(
        title: _OutletTitle(
          outlet: outlet?.name ?? 'Beranda',
          shift: shift == null ? 'Kas belum dibuka' : 'Kas dibuka · ${shift.cashierName}',
          live: shift != null,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          var i = 0;
          Widget gap(Widget w) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Entrance(index: i++, child: w),
          );
          if (c.maxWidth < 900) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              children: [for (final w in [...left, ...right]) gap(w)],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: Column(children: [for (final w in left) gap(w)])),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: Column(children: [for (final w in right) gap(w)])),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _where(Order o, Map<String, String> tableNames) {
  final name = tableNames[o.tableId] ?? '';
  return o.type == OrderType.takeaway
      ? 'Bawa pulang'
      : name.isEmpty
      ? 'Makan di tempat'
      : (name.toLowerCase().startsWith('meja') ? name : 'Meja $name');
}

// ---------------------------------------------------------------- appbar

class _OutletTitle extends StatelessWidget {
  const _OutletTitle({required this.outlet, required this.shift, required this.live});
  final String outlet;
  final String shift;
  final bool live;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        outlet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 1),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: live ? AppColors.sage : AppColors.faint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              shift,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------- hero

/// Kartu hitam penjualan hari ini + batang 7 hari (hari ini berwarna sage).
class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.stats, required this.now});
  final HomeStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final delta = stats.deltaPct;
    final up = (delta ?? 0) >= 0;
    final caption = [
      if (delta != null) '${up ? '▲' : '▼'} ${delta.abs()}% dari kemarin',
      '${stats.todayCount} transaksi',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Penjualan bersih · ${_hari[now.weekday - 1]}, ${now.day} ${_bulan[now.month - 1]}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.onInkMuted,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCount(
              value: stats.todayTotal,
              format: (v) => rupiah.format(v),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: const Color(0xFFF6F3EE),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: delta == null
                  ? AppColors.onInkMuted
                  : (up ? AppColors.sageOnInk : const Color(0xFFE59AA6)),
            ),
          ),
          const SizedBox(height: 16),
          _WeekBars(stats),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.now, required this.shiftOpen});
  final String name;
  final DateTime now;
  final bool shiftOpen;

  @override
  Widget build(BuildContext context) {
    final h = now.hour;
    final sapaan = h < 11
        ? 'pagi'
        : h < 15
        ? 'siang'
        : h < 18
        ? 'sore'
        : 'malam';
    final tanggal = '${_hari[now.weekday - 1]}, ${now.day} ${_bulan[now.month - 1]} ${now.year}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tanggal,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.onInkMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selamat $sapaan,\n$name',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: const Color(0xFFF6F3EE),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: shiftOpen ? AppColors.sageOnInk : AppColors.onInkMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                shiftOpen ? 'Kas sudah dibuka' : 'Kas belum dibuka',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: shiftOpen ? AppColors.sageOnInk : AppColors.onInkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- aksi cepat

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions(this.actions);
  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            onTap: actions[i].onTap,
            child: Semantics(
              button: true,
              label: actions[i].label,
              child: Container(
                height: 82,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: i == 0 ? null : Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      actions[i].icon,
                      size: 22,
                      color: i == 0 ? Colors.white : AppColors.ink,
                    ),
                    Text(
                      actions[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

// ---------------------------------------------------------------- perlu tindakan

class _Todo {
  const _Todo(this.n, this.title, this.sub, this.color, this.onTap);
  final int n;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback? onTap;
}

class _TodoCard extends StatelessWidget {
  const _TodoCard(this.items);
  final List<_Todo> items;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((t) => t.n > 0).length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Perlu tindakan',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(
                  pending == 0 ? 'Semua beres' : '$pending hal',
                  tone: pending == 0 ? Tone.success : Tone.info,
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 18, endIndent: 18),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      child: AnimatedCount(
                        value: items[i].n,
                        format: (v) => '$v',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: items[i].n == 0 ? AppColors.border : items[i].color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].title,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            items[i].sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (items[i].onTap != null)
                      const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- terlaris

class _BestSellers extends StatelessWidget {
  const _BestSellers(this.items);
  final List<({String name, int qty})> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(
          'Terlaris hari ini',
          style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: i >= items.length
                  ? const SizedBox.shrink()
                  : Container(
                      height: 104,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${i + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: i == 0 ? AppColors.primary : AppColors.sageInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              items[i].name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${items[i].qty} porsi',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    ],
  );
}

class _WeekBars extends StatelessWidget {
  const _WeekBars(this.stats);
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final maxV = stats.totals.fold<int>(0, (m, v) => v > m ? v : m);
    const barArea = 64.0;
    return SizedBox(
      height: barArea + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < stats.days.length; i++)
            Expanded(
              child: Tooltip(
                message: rupiah.format(stats.totals[i]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxV == 0
                            ? 4
                            : (stats.totals[i] / maxV * barArea).clamp(4.0, barArea).toDouble(),
                      ),
                      duration: Duration(milliseconds: 420 + 40 * i),
                      curve: Curves.easeOutCubic,
                      builder: (_, h, _) => Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == 6 ? AppColors.sageOnInk : AppColors.inkLine,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hariPendek[stats.days[i].weekday - 1],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: i == 6 ? FontWeight.w800 : FontWeight.w600,
                        color: i == 6 ? const Color(0xFFF6F3EE) : const Color(0xFF8C857E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveOrderRow extends StatelessWidget {
  const _ActiveOrderRow({
    required this.order,
    required this.tableNames,
    required this.nowMs,
  });
  final Order order;
  final Map<String, String> tableNames;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final where = _where(order, tableNames);
    final minutes = ((nowMs - order.createdAt) / 60000).floor().clamp(0, 99999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$where • ${order.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${order.items.length} item • ${rupiah.format(order.total)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(
            _age(minutes),
            tone: minutes > 20 ? Tone.danger : Tone.neutral,
          ),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.ingredient, required this.level});
  final Ingredient ingredient;
  final double level;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Sisa ${qtyText(level)} ${ingredient.unit} • minimum ${qtyText(ingredient.minStock)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        StatusPill(
          level <= 0 ? 'Habis' : 'Menipis',
          tone: level <= 0 ? Tone.danger : Tone.warning,
        ),
      ],
    ),
  );
}
