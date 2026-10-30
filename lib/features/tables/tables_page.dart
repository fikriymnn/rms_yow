import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../pos/pos_page.dart';
import '../reservations/reservation.dart';
import '../reservations/reservation_providers.dart';
import '../reservations/reservations_page.dart';
import 'dining_table.dart';
import 'tables_providers.dart';
import 'table_hold.dart';

enum _Filter { all, free, busy, booked }

class TablesPage extends ConsumerStatefulWidget {
  const TablesPage({super.key});
  @override
  ConsumerState<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends ConsumerState<TablesPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    ref.watch(
      minuteTickProvider,
    ); // segarkan indikator tiap menit & saat ganti hari
    final tables = ref.watch(tablesProvider).value ?? <DiningTable>[];
    final open = ref.watch(openOrdersProvider);
    final holds = ref.watch(activeHoldsProvider);
    final allOrders = ref.watch(ordersProvider).value ?? <Order>[];
    TableHold? holdOf(String tableId) =>
        holds.where((h) => h.tableId == tableId).firstOrNull;
    final canManage =
        ref.watch(appUserProvider).value?.can('tables.create') ?? false;
    final repo = ref.read(tableRepositoryProvider);
    final takeaways = open.where((o) => o.type == OrderType.takeaway).toList();

    final reservations =
        ref.watch(reservationsProvider).value ?? <Reservation>[];
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final dayEnd = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final hm = DateFormat('HH:mm');
    String clock(int ms) => hm.format(DateTime.fromMillisecondsSinceEpoch(ms));

    // booking hari ini (status Dipesan), urut jam
    final todayBookings =
        reservations
            .where(
              (r) =>
                  r.status == ReservationStatus.booked &&
                  r.at >= dayStart &&
                  r.at < dayEnd,
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    List<Reservation> bookingsOf(String tableId) =>
        todayBookings.where((r) => r.tableId == tableId).toList();
    Order? orderOf(String tableId) =>
        open.where((o) => o.tableId == tableId).firstOrNull;

    void openPos({DiningTable? table, Order? order}) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosPage(table: table, order: order),
      ),
    );

    bool occupied(String id) => orderOf(id) != null || holdOf(id) != null;
    final busyCount = tables.where((t) => occupied(t.id)).length;
    final bookedCount = tables.where((t) => bookingsOf(t.id).isNotEmpty).length;
    final freeCount = tables.length - busyCount;
    bool show(DiningTable t) => switch (_filter) {
      _Filter.all => true,
      _Filter.free => !occupied(t.id),
      _Filter.busy => occupied(t.id),
      _Filter.booked => bookingsOf(t.id).isNotEmpty,
    };
    final visible = tables.where(show).toList();
    final tableNames = {for (final t in tables) t.id: t.name};

    final filters = SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          for (final (f, label, n) in [
            (_Filter.all, 'Semua', tables.length),
            (_Filter.free, 'Kosong', freeCount),
            (_Filter.busy, 'Terisi', busyCount),
            (_Filter.booked, 'Booking', bookedCount),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$label $n'),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ],
      ),
    );

    final Widget grid = tables.isEmpty
        ? EmptyState(
            icon: Icons.table_restaurant_outlined,
            title: 'Belum ada meja',
            message: canManage ? 'Tambahkan dengan tombol + Meja' : null,
          )
        : visible.isEmpty
        ? const EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'Tidak ada meja pada filter ini',
          )
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisExtent: 136,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: visible.length,
            itemBuilder: (_, i) {
              final t = visible[i];
              final o = orderOf(t.id);
              final h = holdOf(t.id);
              final held = h == null
                  ? null
                  : allOrders.where((x) => x.id == h.id).firstOrNull;
              return _TableCard(
                table: t,
                order: o,
                hold: h,
                holdTotal: held?.total,
                bookings: bookingsOf(t.id),
                nowMs: nowMs,
                clock: clock,
                onTap: () => (o == null && h != null)
                    ? _holdSheet(context, t, h, openPos)
                    : openPos(table: t, order: o),
                onLongPress: canManage
                    ? () => _edit(context, repo, t, o != null || h != null)
                    : null,
              );
            },
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meja'),
        actions: [
          IconButton(
            tooltip: 'Reservasi',
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReservationsPage()),
            ),
          ),
          TextButton.icon(
            onPressed: () => openPos(),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Takeaway'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, repo, null, false),
              icon: const Icon(Icons.add),
              label: const Text('Meja'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          final main = Column(
            children: [
              filters,
              if (!wide && takeaways.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final o in takeaways)
                          ActionChip(
                            avatar: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 18,
                            ),
                            label: Text(
                              '${o.number} • ${rupiah.format(o.total)}',
                            ),
                            onPressed: () => openPos(order: o),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: grid),
            ],
          );
          if (!wide) return main;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              SizedBox(
                width: 340,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 88),
                  children: [
                    SectionCard(
                      title: 'Takeaway aktif',
                      child: takeaways.isEmpty
                          ? const EmptyState(
                              icon: Icons.shopping_bag_outlined,
                              title: 'Tidak ada takeaway',
                            )
                          : Column(
                              children: [
                                for (final o in takeaways)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => openPos(order: o),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              o.number,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            rupiah.format(o.total),
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Booking hari ini',
                      child: todayBookings.isEmpty
                          ? const EmptyState(
                              icon: Icons.event_available_outlined,
                              title: 'Tidak ada booking',
                            )
                          : Column(
                              children: [
                                for (final r in todayBookings)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        StatusPill(
                                          clock(r.at),
                                          tone: nowMs > r.at + 15 * 60000
                                              ? Tone.danger
                                              : Tone.info,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                tableNames[r.tableId] ??
                                                    'Belum pilih meja',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12.5,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    TableRepository repo,
    DiningTable? existing,
    bool occupied,
  ) async {
    final name = TextEditingController(text: existing?.name);
    final cap = TextEditingController(
      text: (existing?.capacity ?? 4).toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Meja baru' : 'Edit meja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama (mis. T1)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cap,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kapasitas'),
            ),
          ],
        ),
        actions: [
          if (existing != null && !occupied)
            TextButton(
              onPressed: () {
                repo.remove(existing.id);
                Navigator.pop(ctx);
              },
              child: const Text('Hapus'),
            ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              repo.save(
                (existing ?? DiningTable(id: const Uuid().v4(), name: ''))
                    .copyWith(
                      name: name.text.trim(),
                      capacity: int.tryParse(cap.text) ?? 4,
                    ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _holdSheet(
    BuildContext context,
    DiningTable t,
    TableHold h,
    void Function({DiningTable? table, Order? order}) openPos,
  ) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                t.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Sudah dibayar (${h.orderNumber}) • pelanggan masih di meja',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text('Tambah pesanan'),
              onTap: () => Navigator.pop(ctx, 'add'),
            ),
            ListTile(
              leading: const Icon(Icons.event_seat_outlined),
              title: const Text('Kosongkan meja'),
              onTap: () => Navigator.pop(ctx, 'free'),
            ),
          ],
        ),
      ),
    );
    if (a == 'add') openPos(table: t);
    if (a == 'free')
      await ref.read(tableHoldRepositoryProvider).save(h.release());
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.order,
    this.hold,
    this.holdTotal,
    required this.bookings,
    required this.nowMs,
    required this.clock,
    required this.onTap,
    this.onLongPress,
  });
  final DiningTable table;
  final Order? order;
  final TableHold? hold;
  final int? holdTotal;
  final List<Reservation> bookings;
  final int nowMs;
  final String Function(int) clock;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final busy = o != null || hold != null;
    final hasBooking = bookings.isNotEmpty;
    final overdue = hasBooking && nowMs > bookings.first.at + 15 * 60000;
    final soon = bookings.any(
      (r) => r.at - nowMs <= 60 * 60000 && r.endAt > nowMs,
    );
    final accent = overdue ? AppColors.danger : AppColors.rose;
    final border = soon
        ? accent
        : (busy ? AppColors.primary : AppColors.border);
    final minutes = o != null
        ? ((nowMs - o.createdAt) / 60000).floor().clamp(0, 99999)
        : 0;
    final bookingLabel = bookings.length == 1
        ? 'Booking ${clock(bookings.first.at)} • ${bookings.first.name}'
        : 'Booking ${bookings.map((r) => clock(r.at)).join(', ')}';

    return Material(
      color: busy ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: soon ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      table.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (hasBooking)
                    Icon(Icons.event_available, size: 18, color: accent),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.event_seat_outlined,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${table.capacity} kursi',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              if (hasBooking) ...[
                const SizedBox(height: 6),
                Text(
                  bookingLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  StatusPill(
                    o != null
                        ? 'Terisi • $minutes mnt'
                        : (hold != null ? 'Sudah bayar' : 'Kosong'),
                    tone: o != null
                        ? Tone.info
                        : (hold != null ? Tone.warning : Tone.success),
                  ),
                  const Spacer(),
                  if (o != null || holdTotal != null)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          rupiah.format(o?.total ?? holdTotal ?? 0),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
