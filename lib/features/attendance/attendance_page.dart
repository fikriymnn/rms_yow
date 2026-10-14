import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_providers.dart';
import '../reservations/reservation_providers.dart';
import 'attendance_models.dart';
import 'attendance_providers.dart';
import 'attendance_report_tab.dart';
import 'employees_tab.dart';

class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManager = ref.watch(appUserProvider).value?.isManager ?? false;
    if (!isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Absensi')),
        body: const ClockTab(),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Absensi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Absen'),
              Tab(text: 'Karyawan'),
              Tab(text: 'Rekap'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ClockTab(), EmployeesTab(), AttendanceReportTab()],
        ),
      ),
    );
  }
}

class ClockTab extends ConsumerStatefulWidget {
  const ClockTab({super.key});
  @override
  ConsumerState<ClockTab> createState() => _ClockTabState();
}

class _ClockTabState extends ConsumerState<ClockTab> {
  final _fails = <String, int>{};
  final _locked = <String, DateTime>{};
  bool _busy = false;
  static final _hm = DateFormat('HH:mm');
  static final _dateFmt = DateFormat('EEEE, d MMM yyyy');

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<String?> _askPin(String name) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('PIN $name'),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _tap(Employee e) async {
    if (_busy) return;
    final until = _locked[e.id];
    if (until != null && DateTime.now().isBefore(until)) {
      _toast('Terlalu banyak percobaan. Coba lagi sebentar.');
      return;
    }
    if (!e.hasPin) {
      _toast('PIN ${e.name} belum diatur. Hubungi manager.');
      return;
    }
    final pin = await _askPin(e.name);
    if (pin == null || !mounted) return;
    if (!verifyPin(e, pin)) {
      final n = (_fails[e.id] ?? 0) + 1;
      if (n >= 5) {
        _fails[e.id] = 0;
        _locked[e.id] = DateTime.now().add(const Duration(minutes: 1));
        _toast('PIN salah 5 kali. Terkunci 1 menit.');
      } else {
        _fails[e.id] = n;
        _toast('PIN salah');
      }
      return;
    }
    _fails[e.id] = 0;
    setState(() => _busy = true);
    try {
      final all = ref.read(attendanceProvider).value ?? <Attendance>[];
      final open = openRecordOf(all, e.id);
      final t = _hm.format(DateTime.now());
      if (open != null) {
        await clockOut(ref, open);
        _toast('Sampai jumpa, ${e.name}. Pulang $t');
      } else {
        await clockIn(ref, e);
        _toast('Selamat bekerja, ${e.name}. Masuk $t');
      }
    } catch (err) {
      _toast('Gagal mencatat absen: $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(minuteTickProvider); // segarkan jam & durasi tiap menit
    final emps = (ref.watch(employeesProvider).value ?? <Employee>[])
        .where((e) => e.active)
        .toList();
    final all = ref.watch(attendanceProvider).value ?? <Attendance>[];
    final now = DateTime.now();
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final cs = Theme.of(context).colorScheme;
    final th = Theme.of(context).textTheme;

    String statusOf(Employee e) {
      final open = openRecordOf(all, e.id);
      if (open != null) {
        final mins = ((now.millisecondsSinceEpoch - open.clockIn) / 60000)
            .round();
        return 'Masuk ${_hm.format(DateTime.fromMillisecondsSinceEpoch(open.clockIn))} • ${durationText(mins)}';
      }
      final last = all
          .where(
            (a) => a.employeeId == e.id && a.clockIn >= dayStart && !a.isOpen,
          )
          .firstOrNull;
      return last == null
          ? 'Belum masuk'
          : 'Pulang ${_hm.format(DateTime.fromMillisecondsSinceEpoch(last.clockOut!))}';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(_hm.format(now), style: th.displaySmall),
              Text(_dateFmt.format(now)),
            ],
          ),
        ),
        Expanded(
          child: emps.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada karyawan. Manager menambahkan di tab Karyawan.',
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: emps.length,
                  itemBuilder: (_, i) {
                    final e = emps[i];
                    final isIn = openRecordOf(all, e.id) != null;
                    final stale = all.any(
                      (a) => a.employeeId == e.id && isStale(a),
                    );
                    return Card(
                      color: isIn ? cs.primaryContainer : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _tap(e),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.name,
                                style: th.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (e.position.isNotEmpty)
                                Text(e.position, style: th.bodySmall),
                              const Spacer(),
                              if (stale)
                                Text(
                                  'Lupa absen pulang',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.error,
                                  ),
                                ),
                              Text(
                                statusOf(e),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
