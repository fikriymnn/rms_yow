import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/reason_dialog.dart';
import '../audit/audit_log.dart';
import '../audit/audit_providers.dart';
import '../export/csv_util.dart';
import '../export/export_service.dart';
import '../export/period_chips.dart';
import 'attendance_models.dart';
import 'attendance_providers.dart';

class AttendanceReportTab extends ConsumerStatefulWidget {
  const AttendanceReportTab({super.key});
  @override
  ConsumerState<AttendanceReportTab> createState() =>
      _AttendanceReportTabState();
}

class _AttendanceReportTabState extends ConsumerState<AttendanceReportTab> {
  DateTimeRange _range = PeriodChips.thisMonth();
  static final _hm = DateFormat('HH:mm');
  static final _day = DateFormat('EEE d MMM');
  static final _stamp = DateFormat('yyyyMMdd');

  int get _start => _range.start.millisecondsSinceEpoch;
  int get _end => DateTime(
    _range.end.year,
    _range.end.month,
    _range.end.day + 1,
  ).millisecondsSinceEpoch;

  List<Attendance> _inRange() =>
      (ref.read(attendanceProvider).value ?? <Attendance>[])
          .where((a) => a.clockIn >= _start && a.clockIn < _end)
          .toList();

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _t(int ms) => _hm.format(DateTime.fromMillisecondsSinceEpoch(ms));

  Future<void> _export() async {
    try {
      final rows = _inRange().toList()
        ..sort((a, b) => a.clockIn.compareTo(b.clockIn));
      if (rows.isEmpty) {
        _toast('Tidak ada data pada periode ini');
        return;
      }
      final f = DateFormat('yyyy-MM-dd');
      final data = <List<Object?>>[
        [
          'Karyawan',
          'Tanggal',
          'Masuk',
          'Pulang',
          'Durasi (jam)',
          'Catatan',
          'Dikoreksi',
        ],
        for (final a in rows)
          [
            a.employeeName,
            f.format(DateTime.fromMillisecondsSinceEpoch(a.clockIn)),
            _t(a.clockIn),
            a.clockOut == null ? '' : _t(a.clockOut!),
            a.clockOut == null
                ? ''
                : double.parse((a.minutes / 60).toStringAsFixed(2)),
            a.note,
            a.edited ? 'ya' : 'tidak',
          ],
      ];
      await shareBytes(
        'rms_absensi_${_stamp.format(_range.start)}_${_stamp.format(_range.end)}.csv',
        'text/csv',
        Uint8List.fromList(toCsvBytes(data)),
      );
    } catch (e) {
      _toast('Ekspor gagal: $e');
    }
  }

  Future<void> _edit(Attendance a) async {
    final base = DateTime.fromMillisecondsSinceEpoch(a.clockIn);
    var tin = TimeOfDay.fromDateTime(base);
    TimeOfDay? tout = a.clockOut == null
        ? null
        : TimeOfDay.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(a.clockOut!),
          );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Koreksi ${a.employeeName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('EEEE, d MMM yyyy').format(base)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: Text('Masuk ${tin.format(ctx)}'),
                onPressed: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: tin,
                  );
                  if (t != null) setS(() => tin = t);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: Text(
                  tout == null
                      ? 'Pulang: belum diisi'
                      : 'Pulang ${tout!.format(ctx)}',
                ),
                onPressed: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: tout ?? tin,
                  );
                  if (t != null) setS(() => tout = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final reason = await askReason(context, 'Alasan koreksi');
    if (reason == null) return;

    final inDt = DateTime(
      base.year,
      base.month,
      base.day,
      tin.hour,
      tin.minute,
    );
    int? outMs;
    if (tout != null) {
      var o = DateTime(
        base.year,
        base.month,
        base.day,
        tout!.hour,
        tout!.minute,
      );
      if (!o.isAfter(inDt))
        o = o.add(const Duration(days: 1)); // lewat tengah malam
      outMs = o.millisecondsSinceEpoch;
    }
    final updated = a.copyWith(
      clockIn: inDt.millisecondsSinceEpoch,
      clockOut: outMs,
      note: 'Koreksi: $reason',
      edited: true,
    );
    await ref.read(attendanceRepositoryProvider).save(updated);
    await ref
        .read(auditRepositoryProvider)
        .record(
          AuditAction.attendanceEdit,
          reason: reason,
          detail:
              '${a.employeeName} ${_day.format(base)}: ${_t(a.clockIn)}-${a.clockOut == null ? '?' : _t(a.clockOut!)} → ${_t(updated.clockIn)}-${outMs == null ? '?' : _t(outMs)}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(attendanceProvider).value ?? <Attendance>[];
    final inRange = records
        .where((a) => a.clockIn >= _start && a.clockIn < _end)
        .toList();
    final byEmp = <String, List<Attendance>>{};
    for (final a in inRange) {
      byEmp.putIfAbsent(a.employeeId, () => []).add(a);
    }
    final names = {for (final a in inRange) a.employeeId: a.employeeName};
    final ids = byEmp.keys.toList()
      ..sort(
        (a, b) => (names[a] ?? '').toLowerCase().compareTo(
          (names[b] ?? '').toLowerCase(),
        ),
      );
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: PeriodChips(
                range: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ),
            IconButton(
              tooltip: 'Ekspor CSV',
              icon: const Icon(Icons.ios_share),
              onPressed: _export,
            ),
          ],
        ),
        const Divider(height: 24),
        if (ids.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Belum ada absensi pada periode ini')),
          ),
        for (final id in ids)
          Builder(
            builder: (_) {
              final list = byEmp[id]!;
              final days = {
                for (final a in list)
                  DateUtils.dateOnly(
                    DateTime.fromMillisecondsSinceEpoch(a.clockIn),
                  ),
              }.length;
              final minutes = list
                  .where((a) => !a.isOpen)
                  .fold<int>(0, (s, a) => s + a.minutes);
              final stale = list.where(isStale).length;
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(names[id] ?? ''),
                subtitle: Text(
                  '$days hari • ${durationText(minutes)}'
                  '${stale > 0 ? ' • $stale belum pulang' : ''}',
                  style: stale > 0 ? TextStyle(color: cs.error) : null,
                ),
                children: [
                  for (final a in list)
                    ListTile(
                      dense: true,
                      title: Text(
                        '${_day.format(DateTime.fromMillisecondsSinceEpoch(a.clockIn))}   '
                        '${_t(a.clockIn)} - ${a.clockOut == null ? '...' : _t(a.clockOut!)}',
                      ),
                      subtitle: Text(
                        isStale(a)
                            ? 'Belum absen pulang (ketuk untuk koreksi)'
                            : a.isOpen
                            ? 'Sedang bekerja'
                            : '${durationText(a.minutes)}${a.edited ? ' • dikoreksi' : ''}',
                        style: isStale(a) ? TextStyle(color: cs.error) : null,
                      ),
                      onTap: () => _edit(a),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
