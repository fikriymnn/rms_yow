import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/reason_dialog.dart';
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('EEEE, d MMM yyyy').format(inDt)),
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

  Future<void> _open(AttendanceRecord r) async {
    final inDt = DateTime.fromMillisecondsSinceEpoch(r.clockInAt);
    final outDt = r.clockOutAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!);
    final th = Theme.of(context).textTheme;

    Widget info(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Text(r.userName, style: th.titleLarge),
            Text(DateFormat('EEEE, d MMM yyyy').format(inDt)),
            const SizedBox(height: 12),
            Row(
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
                    label: outDt == null
                        ? 'Pulang'
                        : 'Pulang ${_hm.format(outDt)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (r.minutes != null) info('Durasi', durationText(r.minutes!)),
            info(
              'Jarak masuk',
              r.inDistanceM == null
                  ? '-'
                  : '±${r.inDistanceM} m dari titik outlet',
            ),
            if (r.outDistanceM != null)
              info('Jarak pulang', '±${r.outDistanceM} m dari titik outlet'),
            if (r.inFlags.isNotEmpty || r.outFlags.isNotEmpty)
              info(
                'Tanda',
                [...r.inFlags, ...r.outFlags]
                    .map((f) => f == 'late_sync' ? 'dikirim terlambat' : f)
                    .join(', '),
              ),
            if (r.stale)
              info('Peringatan', 'Belum absen pulang lebih dari 16 jam'),
            if (r.edited) info('Riwayat', 'Pernah dikoreksi manager'),
            info('Tinjauan', _statusLabel(r.reviewStatus)),
            if (r.reviewNote.isNotEmpty) info('Catatan', r.reviewNote),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.reviewStatus != 'ok')
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tandai OK'),
                    onPressed: () => Navigator.pop(ctx, 'ok'),
                  ),
                if (r.reviewStatus != 'suspicious')
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('Mencurigakan'),
                    onPressed: () => Navigator.pop(ctx, 'suspicious'),
                  ),
                if (r.reviewStatus != 'pending')
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'pending'),
                    child: const Text('Reset tinjauan'),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Koreksi jam'),
                  onPressed: () => Navigator.pop(ctx, 'correct'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'correct':
        await _correct(r);
      default:
        await _review(r, action);
    }
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

  Widget _recordTile(AttendanceRecord r) {
    final cs = Theme.of(context).colorScheme;
    final inDt = DateTime.fromMillisecondsSinceEpoch(r.clockInAt);
    final outDt = r.clockOutAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!);
    final tags = <String>[
      if (r.inDistanceM != null) 'masuk ±${r.inDistanceM} m',
      if (r.outDistanceM != null) 'pulang ±${r.outDistanceM} m',
      if (r.inFlags.contains('late_sync') || r.outFlags.contains('late_sync'))
        'dikirim terlambat',
      if (r.edited) 'dikoreksi',
    ];
    final icon = switch (r.reviewStatus) {
      'ok' => Icon(Icons.check_circle, color: Colors.green.shade700),
      'suspicious' => Icon(Icons.report, color: cs.error),
      _ => const Icon(Icons.hourglass_empty),
    };
    return ListTile(
      isThreeLine: true,
      title: Text('${r.userName} • ${_day.format(inDt)}'),
      subtitle: Text(
        '${_hm.format(inDt)} - ${outDt == null ? '...' : _hm.format(outDt)}'
        '${r.minutes == null ? '' : ' • ${durationText(r.minutes!)}'}'
        '${r.stale ? '\nLupa absen pulang' : ''}'
        '${tags.isEmpty ? '' : '\n${tags.join(' • ')}'}',
      ),
      trailing: icon,
      onTap: () => _open(r),
    );
  }

  Widget _recordsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView();
    final pending = _items.where((r) => r.reviewStatus == 'pending').length;
    final stale = _items.where((r) => r.stale).length;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
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
          ),
          if (pending > 0 || stale > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                [
                  if (pending > 0) '$pending belum ditinjau',
                  if (stale > 0) '$stale lupa absen pulang',
                ].join(' • '),
                style: TextStyle(color: stale > 0 ? cs.error : null),
              ),
            ),
          const SizedBox(height: 4),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Tidak ada catatan pada periode ini')),
            ),
          for (final r in _items) _recordTile(r),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _more,
                child: Text(_loadingMore ? 'Memuat...' : 'Muat lebih banyak'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView();
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_summary.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Belum ada absensi pada periode ini')),
            ),
          for (final s in _summary)
            ListTile(
              title: Text(s.userName),
              subtitle: Text(
                '${s.records} catatan'
                '${s.openCount > 0 ? ' • ${s.openCount} belum pulang' : ''}',
                style: s.openCount > 0 ? TextStyle(color: cs.error) : null,
              ),
              trailing: Text(
                durationText(s.minutes),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_future == null) {
      body = const Center(
        child: Text('Tidak ada foto', style: TextStyle(fontSize: 12)),
      );
    } else {
      body = FutureBuilder<Uint8List>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Foto tidak tersedia (mungkin sudah dihapus sesuai masa simpan)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
              ),
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
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: body,
            ),
          ),
        ),
      ],
    );
  }
}
