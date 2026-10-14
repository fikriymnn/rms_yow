import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/features/tables/table_providers.dart';

import '../orders/order_providers.dart';
import '../pos/pos_page.dart';
import '../tables/dining_table.dart';
import 'reservation.dart';
import 'reservation_dialog.dart';
import 'reservation_providers.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});
  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  DateTime _day = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  static final _dateFmt = DateFormat('EEE, d MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  void _move(int d) =>
      setState(() => _day = DateTime(_day.year, _day.month, _day.day + d));

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _day = d);
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _setStatus(Reservation r, ReservationStatus s) =>
      ref.read(reservationRepositoryProvider).save(r.copyWith(status: s));

  Future<void> _seat(Reservation r, Map<String, DiningTable> tables) async {
    final table = tables[r.tableId];
    if (table == null) {
      _toast('Pilih meja dulu (menu Edit)');
      return;
    }
    final open = ref
        .read(openOrdersProvider)
        .where((o) => o.tableId == table.id)
        .firstOrNull;
    if (open != null &&
        !await _confirm('${table.name} masih terisi. Lanjutkan?')) {
      return;
    }
    if (!mounted) return;
    final repo = ref.read(reservationRepositoryProvider);
    // status baru berubah setelah pesanan benar-benar disimpan
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosPage(
          table: table,
          order: open,
          onOrderSaved: () => repo.save(
            r.copyWith(
              status: ReservationStatus.seated,
              seatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        ),
      ),
    );
  }

  void _openSeated(Reservation r, Map<String, DiningTable> tables) {
    final table = tables[r.tableId];
    if (table == null) {
      _toast('Meja tidak ditemukan');
      return;
    }
    final open = ref
        .read(openOrdersProvider)
        .where((o) => o.tableId == table.id)
        .firstOrNull;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosPage(table: table, order: open),
      ),
    );
  }

  Future<void> _actions(Reservation r, Map<String, DiningTable> tables) async {
    final booked = r.status == ReservationStatus.booked;
    final seated = r.status == ReservationStatus.seated;
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(r.name),
              subtitle: Text(
                '${r.partySize} orang • ${r.phone} • ${r.status.label}',
              ),
            ),
            if (booked) ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Tamu datang (duduk)'),
                onTap: () => Navigator.pop(ctx, 'seat'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Tidak datang'),
                onTap: () => Navigator.pop(ctx, 'noshow'),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Batalkan'),
                onTap: () => Navigator.pop(ctx, 'cancel'),
              ),
            ],
            if (seated)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Buka pesanan meja'),
                onTap: () => Navigator.pop(ctx, 'open'),
              ),
            if (!booked)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Kembalikan ke "Dipesan"'),
                onTap: () => Navigator.pop(ctx, 'undo'),
              ),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'seat':
        await _seat(r, tables);
      case 'open':
        _openSeated(r, tables);
      case 'edit':
        await showReservationDialog(context, ref, existing: r, day: _day);
      case 'noshow':
        await _setStatus(r, ReservationStatus.noShow);
      case 'cancel':
        if (await _confirm('Batalkan reservasi ${r.name}?')) {
          await _setStatus(r, ReservationStatus.cancelled);
        }
      case 'undo':
        await _setStatus(r, ReservationStatus.booked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(reservationsProvider).value ?? <Reservation>[];
    final tables = {
      for (final t in ref.watch(tablesProvider).value ?? <DiningTable>[])
        t.id: t,
    };
    final start = _day.millisecondsSinceEpoch;
    final end = DateTime(
      _day.year,
      _day.month,
      _day.day + 1,
    ).millisecondsSinceEpoch;
    final list = all.where((r) => r.at >= start && r.at < end).toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _move(-1),
          ),
          TextButton(onPressed: _pick, child: Text(_dateFmt.format(_day))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _move(1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showReservationDialog(context, ref, day: _day),
        icon: const Icon(Icons.add),
        label: const Text('Reservasi'),
      ),
      body: list.isEmpty
          ? const Center(child: Text('Tidak ada reservasi pada tanggal ini'))
          : ListView(
              children: [
                for (final r in list)
                  Builder(
                    builder: (_) {
                      final late =
                          r.status == ReservationStatus.booked &&
                          now > r.at + 15 * 60000;
                      final inactive = r.status != ReservationStatus.booked;
                      return ListTile(
                        leading: Text(
                          _timeFmt.format(
                            DateTime.fromMillisecondsSinceEpoch(r.at),
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: late ? cs.error : null,
                          ),
                        ),
                        title: Text(
                          '${r.name} • ${r.partySize} orang',
                          style: TextStyle(
                            decoration:
                                inactive && r.status != ReservationStatus.seated
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          [
                            tables[r.tableId]?.name ?? 'Meja belum dipilih',
                            if (r.phone.isNotEmpty) r.phone,
                            if (r.note.isNotEmpty) r.note,
                          ].join(' • '),
                        ),
                        trailing: Chip(
                          label: Text(late ? 'Terlambat' : r.status.label),
                        ),
                        onTap: () => _actions(r, tables),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
