import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'late_rules_page.dart';
import 'payroll_models.dart';
import 'payslip_view.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

/// Angka rupiah dari isian (abaikan titik, spasi, "Rp").
int parseMoney(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

String _plain(int v) => v == 0 ? '' : v.toString();

final _digits = [FilteringTextInputFormatter.digitsOnly];

void _toast(BuildContext context, String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

/// Penggajian untuk owner / manager (izin payroll.manage).
class PayrollPage extends ConsumerStatefulWidget {
  const PayrollPage({super.key});
  @override
  ConsumerState<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends ConsumerState<PayrollPage> {
  List<OutletInfo> _outlets = const [];
  String? _outletId; // owner: outlet yang dipilih (null = semua)
  late Future<(List<PayRun>, List<PayEmployee>)> _future = _load();

  bool get _isOwner => ref.read(sessionProvider).value?.user.isOwner ?? false;

  Future<(List<PayRun>, List<PayEmployee>)> _load() async {
    final api = ref.read(apiClientProvider);
    final s = ref.read(sessionProvider).value!;
    if (_isOwner && _outlets.isEmpty) {
      _outlets = [
        for (final m in await api.get('/outlets') as List<dynamic>)
          OutletInfo.fromJson(m as Map<String, dynamic>),
      ];
      if (_outlets.length == 1) _outletId = _outlets.first.id;
    } else if (!_isOwner) {
      _outlets = [if (s.outlet != null) s.outlet!];
      _outletId = s.outlet?.id;
    }
    final q = {if (_outletId != null) 'outlet_id': _outletId};
    final runs = [
      for (final m in await api.get('/payroll/runs', query: q) as List<dynamic>)
        PayRun.fromJson(m as Map<String, dynamic>),
    ];
    final emps = [
      for (final m in await api.get('/payroll/employees', query: q) as List<dynamic>)
        PayEmployee.fromJson(m as Map<String, dynamic>),
    ];
    return (runs, emps);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _settings() async {
    final api = ref.read(apiClientProvider);
    final cur = await api.get('/payroll/settings') as Map;
    if (!mounted) return;
    var day = (cur['period_start_day'] as num?)?.toInt() ?? 1;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Periode gaji'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tanggal mulai periode gaji setiap bulan.'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(labelText: 'Mulai tanggal'),
                  items: [
                    for (var d = 1; d <= 28; d++)
                      DropdownMenuItem(
                        value: d,
                        child: Text(d == 1 ? '1 (tgl 1 s.d. akhir bulan)' : '$d (s.d. tgl ${d - 1} bulan berikutnya)'),
                      ),
                  ],
                  onChanged: (v) => setS(() => day = v ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await api.put('/payroll/settings', data: {'period_start_day': day});
      if (mounted) _toast(context, 'Pengaturan periode disimpan');
    } catch (e) {
      if (mounted) _toast(context, errorText(e));
    }
  }

  Future<void> _newRun() async {
    final api = ref.read(apiClientProvider);
    var startDay = 1;
    try {
      startDay = ((await api.get('/payroll/settings') as Map)['period_start_day'] as num).toInt();
    } catch (_) {}
    if (!mounted) return;
    var (start, end) = suggestedPeriod(startDay, DateTime.now());
    String? outletId = _outletId ?? (_outlets.length == 1 ? _outlets.first.id : null);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(bool isStart) async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: isStart ? start : end,
              firstDate: DateTime(2024),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            setS(() {
              if (isStart) {
                start = d;
              } else {
                end = d;
              }
            });
          }

          final valid = outletId != null && !end.isBefore(start);
          return AlertDialog(
            title: const Text('Periode gaji baru'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isOwner && _outlets.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: outletId,
                      decoration: const InputDecoration(labelText: 'Outlet'),
                      items: [
                        for (final o in _outlets) DropdownMenuItem(value: o.id, child: Text(o.name)),
                      ],
                      onChanged: (v) => setS(() => outletId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => pick(true), child: Text('Mulai ${fmtIsoDate(isoDate(start))}')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(onPressed: () => pick(false), child: Text('Akhir ${fmtIsoDate(isoDate(end))}')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Slip dibuat untuk karyawan yang gajinya sudah diatur, dihitung dari absensi periode ini. '
                    'Masih bisa diubah sebelum diterbitkan.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(onPressed: valid ? () => Navigator.pop(ctx, true) : null, child: const Text('Buat')),
            ],
          );
        },
      ),
    );
    if (ok != true || outletId == null) return;
    try {
      final r = PayRun.fromJson(
        Map<String, dynamic>.from(
          await api.post('/payroll/runs', data: {
            'outlet_id': outletId,
            'period_start': isoDate(start),
            'period_end': isoDate(end),
          }) as Map,
        ),
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PayRunPage(runId: r.id)));
      _reload();
    } catch (e) {
      if (mounted) _toast(context, errorText(e));
    }
  }

  Future<void> _editProfile(PayEmployee e) async {
    final saved = await showAppDialog<bool>(
      context: context,
      builder: (_) => _ProfileDialog(employee: e),
    );
    if (saved == true) _reload();
  }

  Widget _runsTab(List<PayRun> runs) {
    if (runs.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada periode gaji',
        message: 'Atur gaji karyawan di tab "Gaji karyawan", lalu buat periode gaji.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: runs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = runs[i];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PayRunPage(runId: r.id)));
              _reload();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(periodText(r.periodStart, r.periodEnd),
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('${r.outletName} • ${r.count} karyawan • ${rupiah.format(r.totalNet)}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  StatusPill(r.isDraft ? 'Draft' : 'Diterbitkan', tone: r.isDraft ? Tone.warning : Tone.success),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _employeesTab(List<PayEmployee> emps) {
    if (emps.isEmpty) {
      return const EmptyState(icon: Icons.people_outline, title: 'Tidak ada karyawan yang bisa diatur');
    }
    String summary(PayProfile p) => [
      kSchemeLabels[p.scheme] ?? p.scheme,
      if (p.usesBase) 'pokok ${rupiah.format(p.baseSalary)}',
      if (p.usesDaily) '${rupiah.format(p.dailyRate)}/hari',
    ].join(' • ');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: emps.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Text(
            'Nominal gaji hanya terlihat oleh pengelola. Karyawan hanya melihat slip gaji yang sudah diterbitkan.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
          );
        }
        final e = emps[i - 1];
        final p = e.profile;
        return ListTile(
          tileColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(e.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          subtitle: Text(p == null ? e.roleLabel : '${e.roleLabel} • ${summary(p)}'),
          trailing: p == null
              ? const StatusPill('Belum diatur', tone: Tone.warning)
              : const Icon(Icons.chevron_right),
          onTap: () => _editProfile(e),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = _isOwner;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: RmsAppBar(
          title: const Text('Penggajian'),
          actions: [
            IconButton(
              tooltip: 'Aturan potongan terlambat',
              icon: const Icon(Icons.timer_off_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LateRulesPage(outlets: _outlets, initialOutletId: _outletId),
                ),
              ),
            ),
            if (owner)
              IconButton(tooltip: 'Pengaturan periode', icon: const Icon(Icons.tune), onPressed: _settings),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Periode gaji'), Tab(text: 'Gaji karyawan')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newRun,
          icon: const Icon(Icons.add),
          label: const Text('Periode baru'),
        ),
        body: Column(
          children: [
            if (owner && _outlets.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DropdownButtonFormField<String?>(
                  initialValue: _outletId,
                  decoration: const InputDecoration(labelText: 'Outlet', isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Semua outlet')),
                    for (final o in _outlets) DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
                  ],
                  onChanged: (v) {
                    _outletId = v;
                    _reload();
                  },
                ),
              ),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', message: errorText(snap.error!));
                  }
                  final d = snap.data;
                  if (d == null) return const Center(child: AppLoader());
                  return TabBarView(children: [_runsTab(d.$1), _employeesTab(d.$2)]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pengaturan gaji satu karyawan.
class _ProfileDialog extends ConsumerStatefulWidget {
  const _ProfileDialog({required this.employee});
  final PayEmployee employee;
  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  late final PayProfile _p = widget.employee.profile ?? const PayProfile();
  late String _scheme = _p.scheme;
  late bool _bpjs = _p.bpjsEnabled;
  late bool _pph = _p.pph21Enabled;
  late final _base = TextEditingController(text: _plain(_p.baseSalary));
  late final _daily = TextEditingController(text: _plain(_p.dailyRate));
  late final _allow = TextEditingController(text: _plain(_p.fixedAllowance));
  late bool _lateOn = _p.lateDeductionEnabled;
  late bool _otOn = _p.overtimeBonusEnabled;
  late final _bpjsAmt = TextEditingController(text: _plain(_p.bpjsAmount));
  late final _pphAmt = TextEditingController(text: _plain(_p.pph21Amount));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_base, _daily, _allow, _bpjsAmt, _pphAmt]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _usesBase => _scheme == 'monthly' || _scheme == 'monthly_daily';
  bool get _usesDaily => _scheme == 'daily' || _scheme == 'monthly_daily';

  String? _validate() {
    if (_usesBase && parseMoney(_base.text) <= 0) return 'Gaji pokok wajib diisi';
    if (_usesDaily && parseMoney(_daily.text) <= 0) return 'Tarif harian wajib diisi';
    if (_bpjs && parseMoney(_bpjsAmt.text) <= 0) return 'Nominal potongan BPJS wajib diisi';
    if (_pph && parseMoney(_pphAmt.text) <= 0) return 'Nominal potongan PPh 21 wajib diisi';
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final p = PayProfile(
      scheme: _scheme,
      baseSalary: _usesBase ? parseMoney(_base.text) : 0,
      dailyRate: _usesDaily ? parseMoney(_daily.text) : 0,
      fixedAllowance: parseMoney(_allow.text),
      lateDeductionEnabled: _lateOn,
      overtimeBonusEnabled: _otOn,
      bpjsEnabled: _bpjs,
      bpjsAmount: _bpjs ? parseMoney(_bpjsAmt.text) : 0,
      pph21Enabled: _pph,
      pph21Amount: _pph ? parseMoney(_pphAmt.text) : 0,
    );
    try {
      await ref.read(apiClientProvider).put('/payroll/employees/${widget.employee.userId}/profile', data: p.toJson());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _money(TextEditingController c, String label, {String? helper}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: _digits,
      decoration: InputDecoration(labelText: label, prefixText: 'Rp ', helperText: helper),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Gaji ${widget.employee.name}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _scheme,
                decoration: const InputDecoration(labelText: 'Skema gaji'),
                items: [
                  for (final e in kSchemeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _scheme = v ?? 'monthly'),
              ),
              if (_usesBase) _money(_base, 'Gaji pokok per periode'),
              if (_usesDaily)
                _money(
                  _daily,
                  _scheme == 'daily' ? 'Upah per hari hadir' : 'Uang harian per hari hadir',
                  helper: 'Dikali jumlah hari hadir dari absensi',
                ),
              _money(_allow, 'Tunjangan tetap (opsional)'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _lateOn,
                title: const Text('Potongan keterlambatan'),
                subtitle: const Text('Nominal mengikuti aturan potongan terlambat outlet'),
                onChanged: (v) => setState(() => _lateOn = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _otOn,
                title: const Text('Bonus lembur'),
                subtitle: const Text('Dari lembur yang disetujui di Absensi, nominal diisi saat menyetujui'),
                onChanged: (v) => setState(() => _otOn = v),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _bpjs,
                title: const Text('Potong BPJS'),
                onChanged: (v) => setState(() => _bpjs = v ?? false),
              ),
              if (_bpjs) _money(_bpjsAmt, 'Potongan BPJS (bagian karyawan)'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _pph,
                title: const Text('Potong PPh 21'),
                onChanged: (v) => setState(() => _pph = v ?? false),
              ),
              if (_pph) _money(_pphAmt, 'Potongan PPh 21 per periode'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan…' : 'Simpan')),
      ],
    );
  }
}

/// Detail satu periode gaji: daftar slip, hitung ulang, terbitkan.
class PayRunPage extends ConsumerStatefulWidget {
  const PayRunPage({super.key, required this.runId});
  final String runId;
  @override
  ConsumerState<PayRunPage> createState() => _PayRunPageState();
}

class _PayRunPageState extends ConsumerState<PayRunPage> {
  late Future<PayRun> _future = _load();
  bool _busy = false;

  Future<PayRun> _load() async => PayRun.fromJson(
    Map<String, dynamic>.from(await ref.read(apiClientProvider).get('/payroll/runs/${widget.runId}') as Map),
  );

  void _reload() => setState(() => _future = _load());

  Future<void> _act(Future<void> Function() job, String ok) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) _toast(context, ok);
      _reload();
    } catch (e) {
      if (mounted) _toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String ok) async =>
      await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiClientProvider);
    return FutureBuilder<PayRun>(
      future: _future,
      builder: (context, snap) {
        final r = snap.data;
        return Scaffold(
          appBar: RmsAppBar(
            title: Text(r == null ? 'Periode gaji' : periodText(r.periodStart, r.periodEnd)),
            actions: [
              if (r != null && r.isDraft)
                IconButton(
                  tooltip: 'Hapus draft',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy
                      ? null
                      : () async {
                          if (!await _confirm('Hapus draft periode?', 'Semua slip di draft ini ikut terhapus.', 'Hapus')) return;
                          try {
                            await api.request('DELETE', '/payroll/runs/${r.id}');
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) _toast(context, errorText(e));
                          }
                        },
                ),
            ],
          ),
          bottomNavigationBar: r == null || !r.isDraft
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _act(() => api.post('/payroll/runs/${r.id}/recalculate'), 'Dihitung ulang dari absensi'),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Hitung ulang'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (!await _confirm(
                                      'Terbitkan slip gaji?',
                                      'Slip akan muncul di akun masing-masing karyawan dan tidak bisa diubah lagi.',
                                      'Terbitkan',
                                    )) {
                                      return;
                                    }
                                    await _act(() => api.post('/payroll/runs/${r.id}/publish'), 'Slip gaji diterbitkan');
                                  },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Terbitkan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          body: snap.hasError
              ? EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', message: errorText(snap.error!))
              : r == null
              ? const Center(child: AppLoader())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AdaptiveGrid(
                      minTileWidth: 160,
                      maxColumns: 3,
                      children: [
                        StatTile(icon: Icons.storefront_outlined, label: 'Outlet', value: r.outletName),
                        StatTile(icon: Icons.people_outline, label: 'Karyawan', value: '${r.count}'),
                        StatTile(icon: Icons.payments_outlined, label: 'Total gaji diterima', value: rupiah.format(r.totalNet)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        StatusPill(r.isDraft ? 'Draft: belum terlihat karyawan' : 'Diterbitkan',
                            tone: r.isDraft ? Tone.warning : Tone.success),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (r.slips.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada slip',
                        message: 'Atur gaji karyawan dulu, lalu tekan "Hitung ulang".',
                      ),
                    for (final s in r.slips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          tileColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          title: Text(s.userName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                          subtitle: Text('${s.days} hari hadir • ${kSchemeLabels[s.scheme] ?? s.scheme}'),
                          trailing: Text(rupiah.format(s.net),
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.primary)),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PayslipEditPage(slip: s, run: r),
                              ),
                            );
                            _reload();
                          },
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Slip satu karyawan: komponen otomatis + komponen manual (draft bisa diubah).
class PayslipEditPage extends ConsumerStatefulWidget {
  const PayslipEditPage({super.key, required this.slip, required this.run});
  final Payslip slip;
  final PayRun run;
  @override
  ConsumerState<PayslipEditPage> createState() => _PayslipEditPageState();
}

class _PayslipEditPageState extends ConsumerState<PayslipEditPage> {
  late Payslip _slip = widget.slip;
  bool _saving = false;

  List<PayLine> get _manual => _slip.lines.where((l) => !l.auto).toList();

  Future<void> _save(List<PayLine> manual, String note) async {
    setState(() => _saving = true);
    try {
      final res = await ref.read(apiClientProvider).put(
        '/payroll/payslips/${_slip.id}/manual',
        data: {'lines': [for (final l in manual) l.toJson()], 'note': note},
      );
      setState(() => _slip = Payslip.fromJson(Map<String, dynamic>.from(res as Map)));
    } catch (e) {
      if (mounted) _toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editLine([PayLine? line]) async {
    var kind = line?.kind ?? 'earning';
    final label = TextEditingController(text: line?.label);
    final amount = TextEditingController(text: _plain(line?.amount ?? 0));
    const presets = ['Service charge', 'Bonus', 'Insentif', 'Kasbon', 'Potongan lain'];
    final res = await showAppDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(line == null ? 'Tambah komponen' : 'Ubah komponen'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'earning', label: Text('Pendapatan')),
                    ButtonSegment(value: 'deduction', label: Text('Potongan')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (v) => setS(() => kind = v.first),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in presets)
                      ActionChip(
                        label: Text(p),
                        onPressed: () => setS(() {
                          label.text = p;
                          kind = (p == 'Kasbon' || p == 'Potongan lain') ? 'deduction' : 'earning';
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Nama komponen')),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits,
                  decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
                ),
              ],
            ),
          ),
          actions: [
            if (line != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text('Hapus'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (res == null) return;
    final manual = _manual;
    final idx = line == null ? -1 : manual.indexWhere((l) => l.id == line.id);
    if (res == 'delete') {
      if (idx >= 0) manual.removeAt(idx);
    } else {
      final amt = parseMoney(amount.text);
      if (label.text.trim().isEmpty || amt <= 0) {
        if (mounted) _toast(context, 'Isi nama dan nominal komponen');
        return;
      }
      final nl = PayLine(id: line?.id ?? '', kind: kind, label: label.text.trim(), amount: amt);
      if (idx >= 0) {
        manual[idx] = nl;
      } else {
        manual.add(nl);
      }
    }
    await _save(manual, _slip.note);
  }

  Future<void> _editNote() async {
    final c = TextEditingController(text: _slip.note);
    final v = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan di slip'),
        content: TextField(controller: c, maxLines: 3, maxLength: 500),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (v != null) await _save(_manual, v);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.run.isDraft;
    final period = periodText(widget.run.periodStart, widget.run.periodEnd);
    return Scaffold(
      appBar: RmsAppBar(
        title: const Text('Slip gaji'),
        actions: [
          IconButton(
            tooltip: 'Bagikan PDF',
            icon: const Icon(Icons.ios_share),
            onPressed: () => sharePayslipPdf(_slip, period: period, outlet: widget.run.outletName),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (draft) ...[
            Text(
              'Komponen dari pengaturan gaji & absensi dihitung otomatis. Tambahkan komponen lain '
              '(service charge, bonus, kasbon, dll.) di bawah.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _saving ? null : () => _editLine(),
                  icon: const Icon(Icons.add),
                  label: const Text('Komponen'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _editNote,
                  icon: const Icon(Icons.notes),
                  label: const Text('Catatan'),
                ),
              ],
            ),
            if (_manual.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final l in _manual)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(l.isEarning ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: l.isEarning ? AppColors.success : AppColors.danger),
                  title: Text(l.label),
                  subtitle: Text(rupiah.format(l.amount)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: _saving ? null : () => _editLine(l),
                ),
            ],
            const SizedBox(height: 12),
          ],
          PayslipView(slip: _slip, period: period, outlet: widget.run.outletName),
        ],
      ),
    );
  }
}
