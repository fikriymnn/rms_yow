import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rms_yow/features/tables/table_providers.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_providers.dart';
import '../tables/dining_table.dart';
import 'reservation.dart';
import 'reservation_providers.dart';

TimeOfDay _defaultTime() {
  final n = DateTime.now().add(const Duration(hours: 1));
  return TimeOfDay(hour: n.hour, minute: n.minute < 30 ? 0 : 30);
}

Future<void> showReservationDialog(
  BuildContext context,
  WidgetRef ref, {
  Reservation? existing,
  required DateTime day,
}) async {
  final tables = ref.read(tablesProvider).value ?? <DiningTable>[];
  final all = ref.read(reservationsProvider).value ?? <Reservation>[];
  final user = ref.read(appUserProvider).value;

  final name = TextEditingController(text: existing?.name);
  final phone = TextEditingController(text: existing?.phone);
  final pax = TextEditingController(text: '${existing?.partySize ?? 2}');
  final note = TextEditingController(text: existing?.note);
  var date = existing == null
      ? day
      : DateTime.fromMillisecondsSinceEpoch(existing.at);
  var time = existing == null
      ? _defaultTime()
      : TimeOfDay.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(existing.at),
        );
  var duration = existing?.durationMin ?? 90;
  String? tableId = existing?.tableId;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final paxN = int.tryParse(pax.text) ?? 0;
        final cap = tables.where((t) => t.id == tableId).firstOrNull?.capacity;
        final valid = name.text.trim().isNotEmpty && paxN > 0;
        return AlertDialog(
          title: Text(existing == null ? 'Reservasi baru' : 'Edit reservasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  onChanged: (_) => setS(() {}),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telepon'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pax,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah tamu',
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: duration,
                        decoration: const InputDecoration(labelText: 'Durasi'),
                        items: [
                          for (final d in [60, 90, 120, 180])
                            DropdownMenuItem(value: d, child: Text('$d menit')),
                        ],
                        onChanged: (v) => setS(() => duration = v ?? duration),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(DateFormat('d MMM yyyy').format(date)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) setS(() => date = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(time.format(ctx)),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: time,
                          );
                          if (t != null) setS(() => time = t);
                        },
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String?>(
                  initialValue: tableId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Meja (opsional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Belum dipilih'),
                    ),
                    for (final t in tables)
                      DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text('${t.name} (${t.capacity} kursi)'),
                      ),
                  ],
                  onChanged: (v) => setS(() => tableId = v),
                ),
                if (cap != null && paxN > cap)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Melebihi kapasitas meja ($cap kursi)',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: valid ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;

  final at = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).millisecondsSinceEpoch;
  final cand = Reservation(
    id: existing?.id ?? const Uuid().v4(),
    name: name.text.trim(),
    at: at,
    phone: phone.text.trim(),
    partySize: int.tryParse(pax.text) ?? 2,
    durationMin: duration,
    tableId: tableId,
    note: note.text.trim(),
    createdBy: existing?.createdBy ?? (user?.name ?? ''),
  );

  if (tableId != null) {
    final clash = all
        .where(
          (x) =>
              x.id != cand.id &&
              x.status == ReservationStatus.booked &&
              x.tableId == tableId &&
              x.overlaps(cand),
        )
        .firstOrNull;
    if (clash != null) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Meja bentrok'),
          content: Text(
            'Meja ini sudah dipesan ${clash.name} pukul '
            '${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(clash.at))}. '
            'Tetap simpan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap simpan'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
  }
  await ref.read(reservationRepositoryProvider).save(cand);
}
