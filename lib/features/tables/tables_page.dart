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
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

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
    // modul Reservasi dimatikan -> izinnya dicabut -> tombol & filter booking disembunyikan
    final canReserve =
        ref.watch(appUserProvider).value?.can('reservations.read') ?? false;
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

    // filter bergaya segmen: wadah krem, pilihan aktif putih
    final filters = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.sunken,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (final (f, label, n) in [
              (_Filter.all, 'Semua', tables.length),
              (_Filter.free, 'Kosong', freeCount),
              (_Filter.busy, 'Terisi', busyCount),
              if (canReserve) (_Filter.booked, 'Booking', bookedCount),
            ])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.curve,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _filter == f ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _filter == f
                          ? const [BoxShadow(color: Color(0x14171717), blurRadius: 6, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text.rich(
                          TextSpan(
                            text: label,
                            children: [
                              TextSpan(
                                text: '  $n',
                                style: TextStyle(
                                  color: _filter == f ? AppColors.primary : AppColors.faint,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: _filter == f ? FontWeight.w800 : FontWeight.w600,
                            color: _filter == f ? AppColors.ink : const Color(0xFF57514B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final Widget grid = tables.isEmpty
        ? EmptyState(
            icon: Icons.table_restaurant_outlined,
            title: 'Belum ada meja',
            message: canManage
                ? 'Tambahkan meja agar pesanan makan di tempat bisa dicatat per meja.'
                : 'Minta owner/manager menambahkan meja. Pesanan bawa pulang tetap bisa lewat tombol Takeaway.',
            actionLabel: canManage ? 'Tambah meja' : null,
            onAction: canManage ? () => _edit(context, repo, null, false) : null,
          )
        : visible.isEmpty
        ? EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'Tidak ada meja pada filter ini',
            actionLabel: 'Tampilkan semua meja',
            actionIcon: Icons.select_all_rounded,
            onAction: () => setState(() => _filter = _Filter.all),
          )
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              // tinggi kartu ikut skala huruf HP agar isi tidak terpotong
              mainAxisExtent: 128 * textScaleOf(context),
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
              return Entrance(
                index: i,
                child: _TableCard(
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
                ),
              );
            },
          );

    return Scaffold(
      appBar: RmsAppBar(
        title: const Text('Meja'),
        pageActions: [
          if (canReserve)
            PageAction(
              icon: Icons.event_available_outlined,
              label: 'Reservasi',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationsPage()),
              ),
            ),
          PageAction(
            icon: Icons.shopping_bag_outlined,
            label: 'Takeaway',
            primary: true,
            onPressed: () => openPos(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, repo, null, false),
              icon: const Icon(Icons.add),
              label: const Text('Tambah meja'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          final main = Column(
            children: [
              filters,
              // gestur tersembunyi dijelaskan, agar pengelola baru tahu cara mengubah meja
              if (canManage && tables.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Ketuk meja untuk memesan • tekan lama untuk mengubah/menghapus',
                    maxLines: 2,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              // takeaway aktif: satu baris yang bisa digeser (dulu Wrap; banyak takeaway
              // membuat daftar meja terdorong habis / overflow di HP)
              if (!wide && takeaways.isNotEmpty)
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                    itemCount: takeaways.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, k) {
                      final o = takeaways[k];
                      return Center(
                        child: ActionChip(
                          avatar: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: Text(
                            '${o.customerName ?? o.number} • ${rupiah.format(o.total)}',
                          ),
                          onPressed: () => openPos(order: o),
                        ),
                      );
                    },
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
                                              o.customerName == null ? o.number : '${o.customerName} · ${o.number}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            rupiah.format(o.total),
                                            style: GoogleFonts.plusJakartaSans(
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
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                tableNames[r.tableId] ??
                                                    'Belum pilih meja',
                                                style: GoogleFonts.plusJakartaSans(
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
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Meja baru' : 'Edit meja'),
        content: SingleChildScrollView(
          // HP kecil / keyboard terbuka: isi dialog bisa digulir, tidak overflow
          child: Column(
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
      // daftar aksi bisa lebih tinggi dari 9/16 layar HP: boleh tinggi + digulir
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  t.name,
                  style: GoogleFonts.plusJakartaSans(
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
    final minutes = o != null
        ? ((nowMs - o.createdAt) / 60000).floor().clamp(0, 99999)
        : 0;
    final bookingLabel = bookings.length == 1
        ? '${clock(bookings.first.at)} · ${bookings.first.name}'
        : bookings.map((r) => clock(r.at)).join(', ');

    // warna per status: kosong putih, terisi hitam, sudah bayar sage, booking maroon muda
    final (Color bg, Color fg, Color sub, Color line) = o != null
        ? (AppColors.ink, AppColors.bg, AppColors.onInkMuted, AppColors.ink)
        : hold != null
        ? (AppColors.sageSoft, AppColors.sageInk, AppColors.sageInk, AppColors.sageSoft)
        : hasBooking
        ? (
            AppColors.primarySoft,
            AppColors.primaryDeep,
            AppColors.primary,
            soon || overdue ? AppColors.primary : AppColors.primarySoft,
          )
        : (AppColors.surface, AppColors.ink, AppColors.faint, AppColors.border);

    final state = o != null
        ? 'Terisi'
        : hold != null
        ? 'Sudah bayar'
        : hasBooking
        ? (overdue ? 'Booking terlambat' : 'Booking')
        : 'Kosong';
    final detail = o != null
        ? '$minutes mnt · ${rupiah.format(o.total)}'
        : hold != null
        ? rupiah.format(holdTotal ?? 0)
        : hasBooking
        ? bookingLabel
        : 'Siap dipakai';

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Semantics(
        button: true,
        label: '${table.name}, $state',
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line, width: soon || overdue ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      table.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: fg,
                      ),
                    ),
                  ),
                  Text(
                    '${table.capacity} kursi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sub,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  if (o != null && minutes >= 45) ...[
                    const PulseDot(color: Color(0xFFE59AA6), size: 6),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(
                      state,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                  if (hasBooking && busy)
                    Icon(Icons.event_available_rounded, size: 16, color: sub),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sub,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
