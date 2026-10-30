import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/features/tables/tables_providers.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
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

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

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

  Tone _tone(ReservationStatus s) => switch (s) {
    ReservationStatus.booked => Tone.info,
    ReservationStatus.seated => Tone.success,
    ReservationStatus.noShow => Tone.warning,
    ReservationStatus.cancelled => Tone.neutral,
  };

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
              title: Text(
                r.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text('${r.partySize} orang • ${r.phone}'),
              trailing: StatusPill(r.status.label, tone: _tone(r.status)),
            ),
            const Divider(height: 1),
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

  Widget _tile(Reservation r, Map<String, DiningTable> tables, int now) {
    final late =
        r.status == ReservationStatus.booked && now > r.at + 15 * 60000;
    final struck =
        r.status == ReservationStatus.noShow ||
        r.status == ReservationStatus.cancelled;
    final (String label, Tone tone) = late
        ? ('Terlambat', Tone.danger)
        : (r.status.label, _tone(r.status));
    final detail = [
      tables[r.tableId]?.name ?? 'Meja belum dipilih',
      if (r.phone.isNotEmpty) r.phone,
      if (r.note.isNotEmpty) r.note,
    ].join(' • ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _actions(r, tables),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: late ? AppColors.danger : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 66,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: late ? const Color(0xFFFEE2E2) : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _timeFmt.format(DateTime.fromMillisecondsSinceEpoch(r.at)),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: late ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.name} • ${r.partySize} orang',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: struck ? TextDecoration.lineThrough : null,
                        color: struck ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label, tone: tone),
            ],
          ),
        ),
      ),
    );
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
    final list = all.where((r) => r.at >= start && r.at < end).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final now = DateTime.now().millisecondsSinceEpoch;

    int count(ReservationStatus s) => list.where((r) => r.status == s).length;
    final guests = list
        .where(
          (r) =>
              r.status == ReservationStatus.booked ||
              r.status == ReservationStatus.seated,
        )
        .fold<int>(0, (s, r) => s + r.partySize);

    final summary = SectionCard(
      title: 'Ringkasan',
      child: Column(
        children: [
          KvRow('Dipesan', '${count(ReservationStatus.booked)}'),
          KvRow('Sudah duduk', '${count(ReservationStatus.seated)}'),
          KvRow('Tidak datang', '${count(ReservationStatus.noShow)}'),
          KvRow('Dibatalkan', '${count(ReservationStatus.cancelled)}'),
          const Divider(height: 20),
          KvRow(
            'Total tamu aktif',
            '$guests',
            bold: true,
            color: AppColors.primary,
          ),
        ],
      ),
    );

    final listView = list.isEmpty
        ? const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Tidak ada reservasi pada tanggal ini',
          )
        : Column(
            children: [
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _tile(r, tables, now),
                ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Reservasi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showReservationDialog(context, ref, day: _day),
        icon: const Icon(Icons.add),
        label: const Text('Reservasi'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              DateBar(
                label: _dateFmt.format(_day),
                onPrev: () => _move(-1),
                onNext: () => _move(1),
                onPick: _pick,
                onToday: _isToday
                    ? null
                    : () => setState(() {
                        final n = DateTime.now();
                        _day = DateTime(n.year, n.month, n.day);
                      }),
              ),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: listView),
                    const SizedBox(width: 16),
                    SizedBox(width: 320, child: summary),
                  ],
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      'Dipesan ${count(ReservationStatus.booked)}',
                      tone: Tone.info,
                    ),
                    StatusPill(
                      'Duduk ${count(ReservationStatus.seated)}',
                      tone: Tone.success,
                    ),
                    StatusPill('Tamu aktif $guests'),
                  ],
                ),
                const SizedBox(height: 12),
                listView,
              ],
            ],
          );
        },
      ),
    );
  }
}
