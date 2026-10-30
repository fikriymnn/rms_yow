import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/features/tables/tables_providers.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
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

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}jt';
  if (n >= 1000) return '${(n / 1000).round()}rb';
  return '$n';
}

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
    final isOwner = user.isOwner;

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
    final proposals = isOwner ? ref.watch(pendingProposalsCountProvider) : 0;
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

    final delta = stats.deltaPct;
    final tiles = <Widget>[
      if (isManager)
        StatTile(
          icon: Icons.payments_outlined,
          label: 'Penjualan bersih hari ini',
          value: rupiah.format(stats.todayTotal),
          caption: delta == null
              ? 'Belum ada data kemarin'
              : '${delta >= 0 ? '▲' : '▼'} ${delta.abs()}% dari kemarin',
          captionTone: delta == null
              ? Tone.neutral
              : (delta >= 0 ? Tone.success : Tone.danger),
        ),
      if (isManager)
        StatTile(
          icon: Icons.receipt_long_outlined,
          label: 'Transaksi',
          value: '${stats.todayCount}',
          caption: stats.todayCount == 0
              ? null
              : 'Rata-rata ${rupiah.format(stats.average)}',
        ),
      StatTile(
        icon: Icons.soup_kitchen_outlined,
        label: 'Pesanan aktif',
        value: '${open.length}',
        tone: open.isEmpty ? Tone.neutral : Tone.warning,
        onTap: () => _open(const KdsPage()),
      ),
      StatTile(
        icon: Icons.inventory_2_outlined,
        label: 'Stok menipis',
        value: '${low.length}',
        tone: low.isEmpty ? Tone.success : Tone.danger,
        onTap: () => _open(const InventoryPage()),
      ),
      StatTile(
        icon: Icons.task_alt,
        label: 'Menunggu persetujuan',
        value: '$approvals',
        tone: approvals > 0 ? Tone.warning : Tone.neutral,
        onTap: () => _open(const ApprovalsPage()),
      ),
      if (isOwner)
        StatTile(
          icon: Icons.lightbulb_outline,
          label: 'Usulan menu',
          value: '$proposals',
          tone: proposals > 0 ? Tone.warning : Tone.neutral,
          onTap: () => _open(const ProposalsPage()),
        ),
      if (isManager)
        StatTile(
          icon: Icons.event_seat_outlined,
          label: 'Reservasi hari ini',
          value: '$bookings',
        ),
      if (isManager)
        StatTile(
          icon: Icons.point_of_sale,
          label: 'Shift kas',
          value: shift == null ? 'Belum dibuka' : 'Terbuka',
          tone: shift == null ? Tone.neutral : Tone.success,
          caption: shift == null ? null : shift.cashierName,
          onTap: () => _open(const ShiftPage()),
        ),
    ];

    final cards = <Widget>[
      if (isManager)
        SectionCard(
          title: 'Penjualan 7 hari terakhir',
          child: _WeekBars(stats),
        ),
      if (isManager)
        SectionCard(
          title: 'Menu terlaris hari ini',
          child: stats.top.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'Belum ada penjualan hari ini',
                )
              : _TopItems(stats.top),
        ),
      SectionCard(
        title: 'Pesanan aktif',
        trailing: TextButton(
          onPressed: () => _open(const KdsPage()),
          child: const Text('Lihat dapur'),
        ),
        child: open.isEmpty
            ? const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Tidak ada pesanan aktif',
              )
            : Column(
                children: [
                  for (final o in open.take(5))
                    _ActiveOrderRow(
                      order: o,
                      tableNames: tableNames,
                      nowMs: nowMs,
                    ),
                ],
              ),
      ),
      SectionCard(
        title: 'Stok menipis',
        trailing: TextButton(
          onPressed: () => _open(const InventoryPage()),
          child: const Text('Lihat stok'),
        ),
        child: low.isEmpty
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Semua stok aman',
              )
            : Column(
                children: [
                  for (final i in low.take(5))
                    _LowStockRow(ingredient: i, level: levels[i.id] ?? 0),
                ],
              ),
      ),
    ];

    final outlet = ref.watch(activeOutletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth - 32;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Greeting(name: user.name, outlet: outlet?.name, now: now),
              const SizedBox(height: 16),
              AdaptiveGrid(children: tiles),
              const SizedBox(height: 16),
              _columns(width, cards),
            ],
          );
        },
      ),
    );
  }

  /// HP: satu kolom. Tab dan Web: dua kolom.
  Widget _columns(double width, List<Widget> cards) {
    if (width < 900) {
      return Column(
        children: [
          for (final c in cards)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.outlet,
    required this.now,
  });
  final String name;
  final String? outlet;
  final DateTime now;

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
    final tanggal =
        '${_hari[now.weekday - 1]}, ${now.day} ${_bulan[now.month - 1]} ${now.year}';
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat $sapaan, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outlet == null ? tanggal : '$tanggal • $outlet',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: .9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars(this.stats);
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final maxV = stats.totals.fold<int>(0, (m, v) => v > m ? v : m);
    const barArea = 120.0;
    return SizedBox(
      height: barArea + 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < stats.days.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _compact(stats.totals[i]),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w500,
                      color: i == 6 ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: maxV == 0
                        ? 4
                        : (stats.totals[i] / maxV * barArea)
                              .clamp(4.0, barArea)
                              .toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: i == 6
                          ? AppColors.primary
                          : const Color(0xFFC4B5FD),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _hariPendek[stats.days[i].weekday - 1],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w500,
                      color: i == 6 ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopItems extends StatelessWidget {
  const _TopItems(this.items);
  final List<({String name, int qty})> items;

  @override
  Widget build(BuildContext context) {
    final maxQty = items.first.qty;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${i + 1}.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        items[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${items[i].qty}×',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: items[i].qty / maxQty,
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
              ],
            ),
          ),
      ],
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
    final name = tableNames[order.tableId] ?? '';
    final where = order.type == OrderType.takeaway
        ? 'Takeaway'
        : name.isEmpty
        ? 'Dine-in'
        : (name.toLowerCase().startsWith('meja') ? name : 'Meja $name');
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${order.items.length} item • ${rupiah.format(order.total)}',
                  style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Sisa ${qtyText(level)} ${ingredient.unit} • minimum ${qtyText(ingredient.minStock)}',
                style: GoogleFonts.inter(
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
