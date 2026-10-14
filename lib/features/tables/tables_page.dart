import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/features/tables/table_providers.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../auth/auth_providers.dart';
import '../orders/order_models.dart';
import '../orders/order_providers.dart';
import '../pos/pos_page.dart';
import '../reservations/reservation.dart';
import '../reservations/reservation_providers.dart';
import '../reservations/reservations_page.dart';
import 'dining_table.dart';

class TablesPage extends ConsumerWidget {
  const TablesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      minuteTickProvider,
    ); // segarkan indikator tiap menit & saat ganti hari
    final tables = ref.watch(tablesProvider).value ?? <DiningTable>[];
    final open = ref.watch(openOrdersProvider);
    final canManage = ref.watch(appUserProvider).value?.canManageMenu ?? false;
    final repo = ref.read(tableRepositoryProvider);
    final takeaways = open.where((o) => o.type == OrderType.takeaway).toList();
    final cs = Theme.of(context).colorScheme;

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

    // booking hari ini (status Dipesan) untuk satu meja, urut jam
    List<Reservation> bookingsOf(String tableId) => reservations
        .where(
          (r) =>
              r.status == ReservationStatus.booked &&
              r.tableId == tableId &&
              r.at >= dayStart &&
              r.at < dayEnd,
        )
        .toList();

    Order? orderOf(String tableId) =>
        open.where((o) => o.tableId == tableId).firstOrNull;

    void openPos({DiningTable? table, Order? order}) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosPage(table: table, order: order),
      ),
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
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, repo, null, false),
              icon: const Icon(Icons.add),
              label: const Text('Meja'),
            )
          : null,
      body: Column(
        children: [
          if (takeaways.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final o in takeaways)
                      ActionChip(
                        avatar: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                        ),
                        label: Text('${o.number} • ${rupiah.format(o.total)}'),
                        onPressed: () => openPos(order: o),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: tables.isEmpty
                ? const Center(child: Text('Belum ada meja'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisExtent: 124,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: tables.length,
                    itemBuilder: (_, i) {
                      final t = tables[i];
                      final o = orderOf(t.id);
                      final bk = bookingsOf(t.id);
                      final hasBooking = bk.isNotEmpty;
                      final overdue =
                          hasBooking && nowMs > bk.first.at + 15 * 60000;
                      final soon = bk.any(
                        (r) => r.at - nowMs <= 60 * 60000 && r.endAt > nowMs,
                      );
                      final accent = overdue ? cs.error : cs.primary;

                      return Card(
                        color: o != null ? cs.primaryContainer : null,
                        shape: soon
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: accent, width: 2),
                              )
                            : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => openPos(table: t, order: o),
                              onLongPress: canManage
                                  ? () => _edit(context, repo, t, o != null)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${t.capacity} kursi',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    if (hasBooking)
                                      Text(
                                        bk.length == 1
                                            ? 'Booking ${clock(bk.first.at)} • ${bk.first.name}'
                                            : 'Booking ${bk.map((r) => clock(r.at)).join(', ')}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      o == null
                                          ? 'Kosong'
                                          : rupiah.format(o.total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (hasBooking)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(
                                  Icons.event_available,
                                  size: 16,
                                  color: accent,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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
}
