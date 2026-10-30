import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/reason_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../export/csv_util.dart';
import '../export/export_service.dart';
import '../export/period_chips.dart';
import 'attendance_models.dart';

class _SummaryRow {
  _SummaryRow.fromJson(Map<String, dynamic> m)
    : userId = m['user_id'] as String,
      userName = m['user_name'] as String? ?? '',
      records = (m['records'] as num?)?.toInt() ?? 0,
      minutes = (m['minutes'] as num?)?.toInt() ?? 0,
      openCount = (m['open_count'] as num?)?.toInt() ?? 0;

  final String userId;
  final String userName;
  final int records;
  final int minutes;
  final int openCount;
}

String _statusLabel(String s) => switch (s) {
  'ok' => 'OK',
  'suspicious' => 'Mencurigakan',
  _ => 'Belum ditinjau',
};

Tone _reviewTone(String s) => switch (s) {
  'ok' => Tone.success,
  'suspicious' => Tone.danger,
  _ => Tone.neutral,
};

String _initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

class AttendanceAdminPage extends ConsumerStatefulWidget {
  const AttendanceAdminPage({super.key});
  @override
  ConsumerState<AttendanceAdminPage> createState() =>
      _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends ConsumerState<AttendanceAdminPage> {
  static const _page = 100;
  static final _hm = DateFormat('HH:mm');
  static final _day = DateFormat('EEE, d MMM');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _stamp = DateFormat('yyyyMMdd');

  DateTimeRange _range = PeriodChips.thisMonth();
  String? _status; // null | pending | ok | suspicious
  List<AttendanceRecord> _items = [];
  List<_SummaryRow> _summary = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  String? _selectedId; // layar lebar: catatan yang dibuka di panel kanan

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  int get _since => _range.start.millisecondsSinceEpoch;
  int get _until => DateTime(
    _range.end.year,
    _range.end.month,
    _range.end.day + 1,
  ).millisecondsSinceEpoch;

  Map<String, dynamic> _base() {
    final outlet = ref.read(activeOutletIdProvider);
    return {
      'since': _since,
      'until': _until,
      if (outlet != null) 'outlet_id': outlet,
    };
  }

  List<AttendanceRecord> _parse(dynamic data) => [
    for (final m in data as List<dynamic>)
      AttendanceRecord.fromJson(m as Map<String, dynamic>),
  ];

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait<dynamic>([
        api.get(
          '/attendance',
          query: {
            ..._base(),
            if (_status != null) 'review_status': _status,
            'limit': _page,
            'offset': 0,
          },
        ),
        api.get('/attendance/summary', query: _base()),
      ]);
      final list = _parse(results[0]);
      final sum = [
        for (final m in results[1] as List<dynamic>)
          _SummaryRow.fromJson(m as Map<String, dynamic>),
      ];
      if (!mounted) return;
      setState(() {
        _items = list;
        _hasMore = list.length == _page;
        _summary = sum;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _more() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .get(
            '/attendance',
            query: {
              ..._base(),
              if (_status != null) 'review_status': _status,
              'limit': _page,
              'offset': _items.length,
            },
          );
      final more = _parse(data);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...more];
        _hasMore = more.length == _page;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
      });
      _toast(errorText(e));
    }
  }

  Future<void> _run(Future<dynamic> Function() job, {String? ok}) async {
    try {
      await job();
      if (ok != null) _toast(ok);
      await _reload();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  // ---------- aksi ----------

  Future<void> _review(AttendanceRecord r, String status) async {
    var note = '';
    if (status == 'suspicious') {
      final reason = await askReason(context, 'Alasan menandai mencurigakan');
      if (reason == null) return;
      note = reason;
    }
    await _run(
      () => ref
          .read(apiClientProvider)
          .request(
            'PATCH',
            '/attendance/${r.id}/review',
            data: {'status': status, 'note': note},
          ),
      ok: 'Tinjauan disimpan',
    );
  }

  Widget _timeTile(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.muted),
        ],
      ),
    ),
  );

  Future<void> _correct(AttendanceRecord r) async {
    final inDt = DateTime.fromMillisecondsSinceEpoch(r.clockInAt);
    var tin = TimeOfDay.fromDateTime(inDt);
    TimeOfDay? tout = r.clockOutAt == null
        ? null
        : TimeOfDay.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!),
          );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Koreksi ${r.userName}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(inDt),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                _timeTile(Icons.login, 'Jam masuk', tin.format(ctx), () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: tin,
                  );
                  if (t != null) setS(() => tin = t);
                }),
                const SizedBox(height: 8),
                _timeTile(
                  Icons.logout,
                  'Jam pulang',
                  tout == null ? 'belum diisi' : tout!.format(ctx),
                  () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: tout ?? tin,
                    );
                    if (t != null) setS(() => tout = t);
                  },
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

    final newIn = DateTime(
      inDt.year,
      inDt.month,
      inDt.day,
      tin.hour,
      tin.minute,
    );
    DateTime? newOut;
    final t = tout;
    if (t != null) {
      newOut = DateTime(inDt.year, inDt.month, inDt.day, t.hour, t.minute);
      if (!newOut.isAfter(newIn)) newOut = newOut.add(const Duration(days: 1));
    }
    final body = <String, dynamic>{'reason': reason};
    if (newIn.millisecondsSinceEpoch != r.clockInAt) {
      body['clock_in_at'] = newIn.millisecondsSinceEpoch;
    }
    if (newOut != null && newOut.millisecondsSinceEpoch != r.clockOutAt) {
      body['clock_out_at'] = newOut.millisecondsSinceEpoch;
    }
    if (body.length == 1) {
      _toast('Tidak ada perubahan');
      return;
    }
    await _run(
      () => ref
          .read(apiClientProvider)
          .request('PATCH', '/attendance/${r.id}', data: body),
      ok: 'Koreksi disimpan',
    );
  }

  Future<void> _handle(AttendanceRecord r, String action) async {
    switch (action) {
      case 'correct':
        await _correct(r);
      default:
        await _review(r, action);
    }
  }

  Future<void> _openSheet(AttendanceRecord r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: _detailChildren(r, (a) => Navigator.pop(ctx, a)),
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _handle(r, action);
  }

  // ---------- ekspor ----------

  Future<void> _export(bool summary) async {
    try {
      final api = ref.read(apiClientProvider);
      final List<List<Object?>> rows;
      if (summary) {
        rows = [
          ['Karyawan', 'Jumlah catatan', 'Total jam', 'Belum pulang'],
          for (final s in _summary)
            [
              s.userName,
              s.records,
              double.parse((s.minutes / 60).toStringAsFixed(2)),
              s.openCount,
            ],
        ];
      } else {
        final all = <AttendanceRecord>[];
        for (var offset = 0; offset < 5000; offset += 500) {
          final page = _parse(
            await api.get(
              '/attendance',
              query: {
                ..._base(),
                if (_status != null) 'review_status': _status,
                'limit': 500,
                'offset': offset,
              },
            ),
          );
          all.addAll(page);
          if (page.length < 500) break;
        }
        rows = [
          [
            'Karyawan',
            'Tanggal',
            'Masuk',
            'Pulang',
            'Durasi (jam)',
            'Jarak masuk (m)',
            'Jarak pulang (m)',
            'Tanda',
            'Status tinjauan',
            'Catatan tinjauan',
            'Dikoreksi',
          ],
          for (final r in all)
            [
              r.userName,
              _ymd.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt)),
              _hm.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt)),
              r.clockOutAt == null
                  ? ''
                  : _hm.format(
                      DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!),
                    ),
              r.minutes == null
                  ? null
                  : double.parse((r.minutes! / 60).toStringAsFixed(2)),
              r.inDistanceM,
              r.outDistanceM,
              [...r.inFlags, ...r.outFlags].join(', '),
              r.reviewStatus,
              r.reviewNote,
              r.edited ? 'ya' : 'tidak',
            ],
        ];
      }
      if (rows.length <= 1) {
        _toast('Tidak ada data pada periode ini');
        return;
      }
      await shareBytes(
        'rms_absensi_${summary ? 'rekap_' : ''}${_stamp.format(_range.start)}_${_stamp.format(_range.end)}.csv',
        'text/csv',
        Uint8List.fromList(toCsvBytes(rows)),
      );
    } catch (e) {
      _toast(errorText(e));
    }
  }

  // ---------- tampilan ----------

  Widget _errorView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(errorText(_error!)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _reload, child: const Text('Coba lagi')),
      ],
    ),
  );

  Widget _info(String k, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            k,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _detailChildren(
    AttendanceRecord r,
    ValueChanged<String> onAction,
  ) {
    final inDt = DateTime.fromMillisecondsSinceEpoch(r.clockInAt);
    final outDt = r.clockOutAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!);
    final flags = [
      ...r.inFlags,
      ...r.outFlags,
    ].map((f) => f == 'late_sync' ? 'dikirim terlambat' : f).join(', ');
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Text(
                _initials(r.userName),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.userName,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, d MMM yyyy').format(inDt),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(
                  _statusLabel(r.reviewStatus),
                  tone: _reviewTone(r.reviewStatus),
                ),
                if (r.stale) ...[
                  const SizedBox(height: 4),
                  const StatusPill('Lupa pulang', tone: Tone.danger),
                ],
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Foto verifikasi',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PhotoBox(
                recordId: r.id,
                kind: 'in',
                available: r.hasInPhoto,
                label: 'Masuk ${_hm.format(inDt)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoBox(
                recordId: r.id,
                kind: 'out',
                available: r.hasOutPhoto,
                label: outDt == null ? 'Pulang' : 'Pulang ${_hm.format(outDt)}',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Rincian',
        child: Column(
          children: [
            if (r.minutes != null) _info('Durasi', durationText(r.minutes!)),
            _info(
              'Jarak masuk',
              r.inDistanceM == null
                  ? '-'
                  : '±${r.inDistanceM} m dari titik outlet',
            ),
            if (r.outDistanceM != null)
              _info('Jarak pulang', '±${r.outDistanceM} m dari titik outlet'),
            if (flags.isNotEmpty) _info('Tanda', flags),
            if (r.stale)
              _info(
                'Peringatan',
                'Belum absen pulang lebih dari 16 jam',
                color: AppColors.danger,
              ),
            if (r.edited) _info('Riwayat', 'Pernah dikoreksi manager'),
            _info('Tinjauan', _statusLabel(r.reviewStatus)),
            if (r.reviewNote.isNotEmpty) _info('Catatan', r.reviewNote),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (r.reviewStatus != 'ok')
            FilledButton.tonalIcon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Tandai OK'),
              onPressed: () => onAction('ok'),
            ),
          if (r.reviewStatus != 'suspicious')
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.report_outlined),
              label: const Text('Mencurigakan'),
              onPressed: () => onAction('suspicious'),
            ),
          if (r.reviewStatus != 'pending')
            OutlinedButton(
              onPressed: () => onAction('pending'),
              child: const Text('Reset tinjauan'),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Koreksi jam'),
            onPressed: () => onAction('correct'),
          ),
        ],
      ),
    ];
  }

  Widget _recordCard(
    AttendanceRecord r, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final inDt = DateTime.fromMillisecondsSinceEpoch(r.clockInAt);
    final outDt = r.clockOutAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!);
    final late =
        r.inFlags.contains('late_sync') || r.outFlags.contains('late_sync');
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: r.stale
                  ? AppColors.danger
                  : (selected ? AppColors.primary : AppColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  _initials(r.userName),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusPill(
                          _statusLabel(r.reviewStatus),
                          tone: _reviewTone(r.reviewStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_day.format(inDt)} • ${_hm.format(inDt)} - ${outDt == null ? '...' : _hm.format(outDt)}'
                      '${r.minutes == null ? '' : ' • ${durationText(r.minutes!)}'}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (r.stale)
                          const StatusPill(
                            'Lupa absen pulang',
                            tone: Tone.danger,
                          ),
                        if (r.edited)
                          const StatusPill('Dikoreksi', tone: Tone.info),
                        if (late)
                          const StatusPill(
                            'Dikirim terlambat',
                            tone: Tone.warning,
                          ),
                        if (r.inDistanceM != null)
                          StatusPill('Masuk ±${r.inDistanceM} m'),
                        if (r.outDistanceM != null)
                          StatusPill('Pulang ±${r.outDistanceM} m'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView();
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final pending = _items.where((r) => r.reviewStatus == 'pending').length;
        final stale = _items.where((r) => r.stale).length;

        final listView = RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              AdaptiveGrid(
                minTileWidth: 120,
                maxColumns: 3,
                children: [
                  StatTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Catatan',
                    value: '${_items.length}',
                  ),
                  StatTile(
                    icon: Icons.hourglass_top,
                    label: 'Perlu ditinjau',
                    value: '$pending',
                    tone: pending > 0 ? Tone.warning : Tone.success,
                  ),
                  StatTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Lupa pulang',
                    value: '$stale',
                    tone: stale > 0 ? Tone.danger : Tone.success,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (label, value) in [
                    ('Semua', null),
                    ('Perlu ditinjau', 'pending'),
                    ('Mencurigakan', 'suspicious'),
                    ('OK', 'ok'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) {
                        setState(() {
                          _status = value;
                        });
                        _reload();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Tidak ada catatan pada periode ini',
                ),
              for (final r in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _recordCard(
                    r,
                    selected: wide && r.id == _selectedId,
                    onTap: () {
                      if (wide) {
                        setState(() => _selectedId = r.id);
                      } else {
                        _openSheet(r);
                      }
                    },
                  ),
                ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _more,
                    child: Text(
                      _loadingMore ? 'Memuat...' : 'Muat lebih banyak',
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
        if (!wide) return listView;

        final sel = _items.where((r) => r.id == _selectedId).firstOrNull;
        return Row(
          children: [
            SizedBox(width: 460, child: listView),
            const VerticalDivider(width: 1),
            Expanded(
              child: sel == null
                  ? const EmptyState(
                      icon: Icons.touch_app_outlined,
                      title: 'Pilih catatan',
                      message: 'Foto dan rinciannya tampil di sini',
                    )
                  : ListView(
                      key: ValueKey(sel.id),
                      padding: const EdgeInsets.all(16),
                      children: _detailChildren(sel, (a) => _handle(sel, a)),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView();
    final totalMin = _summary.fold<int>(0, (s, e) => s + e.minutes);
    final openAll = _summary.fold<int>(0, (s, e) => s + e.openCount);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          AdaptiveGrid(
            minTileWidth: 150,
            maxColumns: 3,
            children: [
              StatTile(
                icon: Icons.groups_outlined,
                label: 'Karyawan',
                value: '${_summary.length}',
              ),
              StatTile(
                icon: Icons.schedule,
                label: 'Total jam kerja',
                value: durationText(totalMin),
                tone: Tone.success,
              ),
              StatTile(
                icon: Icons.warning_amber_rounded,
                label: 'Belum pulang',
                value: '$openAll',
                tone: openAll > 0 ? Tone.danger : Tone.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_summary.isEmpty)
            const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Belum ada absensi pada periode ini',
            )
          else
            AdaptiveGrid(
              minTileWidth: 340,
              maxColumns: 3,
              children: [
                for (final s in _summary)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            _initials(s.userName),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${s.records} catatan',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              if (s.openCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: StatusPill(
                                    '${s.openCount} belum pulang',
                                    tone: Tone.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          durationText(s.minutes),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlet = ref.watch(activeOutletProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Absensi${outlet == null ? '' : ' • ${outlet.name}'}'),
          actions: [
            PopupMenuButton<bool>(
              tooltip: 'Ekspor CSV',
              icon: const Icon(Icons.ios_share),
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: false,
                  child: Text('Ekspor catatan (CSV)'),
                ),
                PopupMenuItem(value: true, child: Text('Ekspor rekap (CSV)')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Catatan'),
              Tab(text: 'Rekap'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PeriodChips(
                  range: _range,
                  onChanged: (r) {
                    setState(() {
                      _range = r;
                    });
                    _reload();
                  },
                ),
              ),
            ),
            Expanded(
              child: TabBarView(children: [_recordsTab(), _summaryTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBox extends ConsumerStatefulWidget {
  const _PhotoBox({
    required this.recordId,
    required this.kind,
    required this.available,
    required this.label,
  });
  final String recordId;
  final String kind; // in | out
  final bool available;
  final String label;

  @override
  ConsumerState<_PhotoBox> createState() => _PhotoBoxState();
}

class _PhotoBoxState extends ConsumerState<_PhotoBox> {
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.available) {
      _future = ref
          .read(apiClientProvider)
          .getBytes('/attendance/${widget.recordId}/photo/${widget.kind}');
    }
  }

  Widget _placeholder(IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 28),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_future == null) {
      body = _placeholder(Icons.no_photography_outlined, 'Tidak ada foto');
    } else {
      body = FutureBuilder<Uint8List>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _placeholder(
              Icons.hide_image_outlined,
              'Foto tidak tersedia (mungkin sudah dihapus sesuai masa simpan)',
            );
          }
          final bytes = snap.data!;
          return GestureDetector(
            onTap: () => showDialog<void>(
              context: ctx,
              builder: (_) =>
                  Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
            ),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            ),
          );
        },
      );
    }
    return Column(
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(color: AppColors.bg, child: body),
          ),
        ),
      ],
    );
  }
}
