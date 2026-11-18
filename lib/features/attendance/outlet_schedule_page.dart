import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

const _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const _zones = {
  'Asia/Jakarta': 'WIB (Jakarta)',
  'Asia/Makassar': 'WITA (Makassar)',
  'Asia/Jayapura': 'WIT (Jayapura)',
};

enum _Mode { open, closed, off } // off = hari itu tidak dinilai

class _DayState {
  _Mode mode = _Mode.off;
  int open = 8 * 60;
  int close = 22 * 60;
}

String _fmt(int m) {
  final v = ((m % 1440) + 1440) % 1440;
  return '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
}

int _parse(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Jadwal buka-tutup satu outlet: dasar penilaian terlambat, pulang cepat, dan lembur.
class OutletSchedulePage extends ConsumerStatefulWidget {
  const OutletSchedulePage({
    super.key,
    required this.outletId,
    required this.outletName,
  });
  final String outletId;
  final String outletName;

  @override
  ConsumerState<OutletSchedulePage> createState() => _OutletSchedulePageState();
}

class _OutletSchedulePageState extends ConsumerState<OutletSchedulePage> {
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  String _tz = 'Asia/Jakarta';
  final _lead = TextEditingController(text: '0');
  final _tail = TextEditingController(text: '0');
  final _grace = TextEditingController(text: '5');
  final List<_DayState> _days = List.generate(7, (_) => _DayState());

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _lead.dispose();
    _tail.dispose();
    _grace.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m =
          await ref
                  .read(apiClientProvider)
                  .get('/attendance/schedule/${widget.outletId}')
              as Map<String, dynamic>;
      _tz = m['timezone'] as String? ?? 'Asia/Jakarta';
      _lead.text = '${m['lead_min'] ?? 0}';
      _tail.text = '${m['tail_min'] ?? 0}';
      _grace.text = '${m['grace_min'] ?? 5}';
      for (final d in (m['days'] as List<dynamic>)) {
        final dm = d as Map<String, dynamic>;
        final st = _days[(dm['weekday'] as num).toInt()];
        if (dm['configured'] != true) {
          st.mode = _Mode.off;
        } else if (dm['closed'] == true) {
          st.mode = _Mode.closed;
        } else {
          st.mode = _Mode.open;
          st.open = _parse(dm['open'] as String);
          st.close = _parse(dm['close'] as String);
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pick(int i, bool isOpen) async {
    final cur = isOpen ? _days[i].open : _days[i].close;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      final v = t.hour * 60 + t.minute;
      if (isOpen) {
        _days[i].open = v;
      } else {
        _days[i].close = v;
      }
    });
  }

  void _copyMonday() {
    final src = _days[0];
    setState(() {
      for (var i = 1; i < 7; i++) {
        _days[i]
          ..mode = src.mode
          ..open = src.open
          ..close = src.close;
      }
    });
  }

  Future<void> _save() async {
    final lead = int.tryParse(_lead.text.trim());
    final tail = int.tryParse(_tail.text.trim());
    final grace = int.tryParse(_grace.text.trim());
    if (lead == null || lead < 0 || lead > 240) {
      _toast('Lead harus 0–240 menit');
      return;
    }
    if (tail == null || tail < 0 || tail > 240) {
      _toast('Tail harus 0–240 menit');
      return;
    }
    if (grace == null || grace < 0 || grace > 120) {
      _toast('Toleransi harus 0–120 menit');
      return;
    }
    final days = <Map<String, dynamic>>[];
    for (var i = 0; i < 7; i++) {
      final d = _days[i];
      if (d.mode == _Mode.off) continue;
      if (d.mode == _Mode.closed) {
        days.add({'weekday': i, 'closed': true});
        continue;
      }
      if (d.open == d.close) {
        _toast('${_dayNames[i]}: jam buka dan tutup tidak boleh sama');
        return;
      }
      days.add({
        'weekday': i,
        'closed': false,
        'open': _fmt(d.open),
        'close': _fmt(d.close),
      });
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .request(
            'PUT',
            '/attendance/schedule/${widget.outletId}',
            data: {
              'timezone': _tz,
              'lead_min': lead,
              'tail_min': tail,
              'grace_min': grace,
              'days': days,
            },
          );
      _toast('Jadwal disimpan');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _example() {
    final i = _days.indexWhere((d) => d.mode == _Mode.open);
    if (i < 0) return 'Atur minimal satu hari buka agar absensi bisa dinilai.';
    final d = _days[i];
    final lead = int.tryParse(_lead.text.trim()) ?? 0;
    final tail = int.tryParse(_tail.text.trim()) ?? 0;
    final grace = int.tryParse(_grace.text.trim()) ?? 0;
    final inAt = d.open - lead;
    final outAt = d.close + tail;
    return 'Contoh (${_dayNames[i]}): wajib hadir ${_fmt(inAt)}, terlambat bila lewat '
        '${_fmt(inAt + grace)}. Pulang normal ${_fmt(outAt)}; lebih awal dari '
        '${_fmt(outAt - grace)} dihitung pulang cepat, lebih lambat dari '
        '${_fmt(outAt + grace)} dihitung lembur.';
  }

  Widget _numField(String label, TextEditingController c, String hint) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 2,
          suffixText: 'menit',
        ),
      );

  Widget _dayCard(int i) {
    final d = _days[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayNames[i],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Mode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Mode.open, label: Text('Buka')),
                ButtonSegment(value: _Mode.closed, label: Text('Libur')),
                ButtonSegment(value: _Mode.off, label: Text('Tidak dinilai')),
              ],
              selected: {d.mode},
              onSelectionChanged: (s) => setState(() => d.mode = s.first),
            ),
          ),
          if (d.mode == _Mode.open) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login, size: 18),
                    label: Text('Buka ${_fmt(d.open)}'),
                    onPressed: () => _pick(i, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text('Tutup ${_fmt(d.close)}'),
                    onPressed: () => _pick(i, false),
                  ),
                ),
              ],
            ),
            if (d.close <= d.open)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: StatusPill('Tutup keesokan harinya', tone: Tone.info),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zones = {..._zones, if (!_zones.containsKey(_tz)) _tz: _tz};
    return Scaffold(
      appBar: RmsAppBar(
        title: Text(
          'Jadwal${widget.outletName.isEmpty ? '' : ' • ${widget.outletName}'}',
        ),
      ),
      body: _loading
          ? const Center(child: AppLoader())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorText(_error!)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SectionCard(
                  title: 'Aturan penilaian',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _tz,
                        decoration: const InputDecoration(
                          labelText: 'Zona waktu outlet',
                        ),
                        items: [
                          for (final e in zones.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) => setState(() => _tz = v ?? _tz),
                      ),
                      const SizedBox(height: 12),
                      _numField(
                        'Hadir sebelum buka',
                        _lead,
                        'Karyawan wajib hadir sekian menit sebelum jam buka',
                      ),
                      const SizedBox(height: 12),
                      _numField(
                        'Pulang setelah tutup',
                        _tail,
                        'Waktu bersih-bersih sesudah jam tutup',
                      ),
                      const SizedBox(height: 12),
                      _numField(
                        'Toleransi',
                        _grace,
                        'Terlambat atau pulang cepat dalam batas ini tetap tepat waktu',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _example(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Jam buka-tutup per hari',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _copyMonday,
                      child: const Text('Samakan dengan Senin'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < 7; i++) _dayCard(i),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan jadwal'),
                ),
              ],
            ),
    );
  }
}
