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
import 'payroll_models.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

/// Aturan potongan keterlambatan bertingkat per outlet (owner / manager).
///
/// Contoh: terlambat >= 5 menit dipotong Rp10.000, >= 30 menit dipotong Rp25.000.
/// Satu kali terlambat dikenai tingkat TERTINGGI yang terlewati. Hanya berlaku untuk
/// karyawan yang saklar "Potongan keterlambatan"-nya aktif di pengaturan gaji.
class LateRulesPage extends ConsumerStatefulWidget {
  const LateRulesPage({super.key, required this.outlets, this.initialOutletId});
  final List<OutletInfo> outlets;
  final String? initialOutletId;
  @override
  ConsumerState<LateRulesPage> createState() => _LateRulesPageState();
}

class _Row {
  _Row(int minutes, int amount)
    : min = TextEditingController(text: minutes == 0 ? '' : '$minutes'),
      amount = TextEditingController(text: amount == 0 ? '' : '$amount');
  final TextEditingController min;
  final TextEditingController amount;
  void dispose() {
    min.dispose();
    amount.dispose();
  }
}

class _LateRulesPageState extends ConsumerState<LateRulesPage> {
  late String? _outletId =
      widget.initialOutletId ?? (widget.outlets.isNotEmpty ? widget.outlets.first.id : null);
  final List<_Row> _rows = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static final _digits = [FilteringTextInputFormatter.digitsOnly];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = _outletId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await ref.read(apiClientProvider).get('/payroll/late-rules/$id') as Map;
      final tiers = [
        for (final t in (m['late_tiers'] as List? ?? const []))
          LateTier.fromJson(Map<String, dynamic>.from(t as Map)),
      ];
      if (!mounted) return;
      setState(() {
        for (final r in _rows) {
          r.dispose();
        }
        _rows
          ..clear()
          ..addAll([for (final t in tiers) _Row(t.minMinutes, t.amount)]);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  int _n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  String? _validate() {
    final seen = <int>{};
    for (final r in _rows) {
      final m = _n(r.min);
      if (m <= 0) return 'Isi batas menit di setiap tingkat';
      if (_n(r.amount) <= 0) return 'Isi nominal potongan di setiap tingkat';
      if (!seen.add(m)) return 'Batas menit tiap tingkat harus berbeda';
    }
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
    try {
      await ref.read(apiClientProvider).put(
        '/payroll/late-rules/$_outletId',
        data: {
          'late_tiers': [
            for (final r in _rows) LateTier(_n(r.min), _n(r.amount)).toJson(),
          ],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aturan potongan terlambat disimpan')),
      );
      await _load(); // tampil terurut dari server
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _add() {
    final last = _rows.isEmpty ? 0 : _n(_rows.last.min);
    final next = _rows.isEmpty ? 5 : (last > 0 ? last + 15 : 0);
    setState(() => _rows.add(_Row(next, 0)));
  }

  /// Ringkasan dalam kalimat agar mudah dipahami pemilik.
  String _preview() {
    final tiers = [
      for (final r in _rows)
        if (_n(r.min) > 0 && _n(r.amount) > 0) LateTier(_n(r.min), _n(r.amount)),
    ]..sort((a, b) => a.minMinutes.compareTo(b.minMinutes));
    if (tiers.isEmpty) return 'Belum ada aturan: keterlambatan tidak dipotong.';
    final parts = <String>[];
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      final to = i + 1 < tiers.length ? '${tiers[i + 1].minMinutes - 1}' : null;
      final range = to == null
          ? '${t.minMinutes} menit atau lebih'
          : (to == '${t.minMinutes}' ? '${t.minMinutes} menit' : '${t.minMinutes}–$to menit');
      parts.add('Terlambat $range: dipotong ${rupiah.format(t.amount)}');
    }
    return '${parts.join('\n')}\n\nDihitung per kejadian terlambat.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RmsAppBar(title: const Text('Potongan terlambat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.outlets.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: _outletId,
              decoration: const InputDecoration(labelText: 'Outlet', isDense: true),
              items: [
                for (final o in widget.outlets) DropdownMenuItem(value: o.id, child: Text(o.name)),
              ],
              onChanged: (v) {
                _outletId = v;
                _load();
              },
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Atur potongan berdasarkan lama keterlambatan dari jadwal masuk outlet. '
            'Satu kali terlambat dikenai tingkat tertinggi yang terlewati. '
            'Berlaku untuk karyawan yang "Potongan keterlambatan"-nya aktif.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: AppLoader()),
            )
          else ...[
            for (var i = 0; i < _rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _rows[i].min,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Terlambat minimal',
                          suffixText: 'menit',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _rows[i].amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Potongan',
                          prefixText: 'Rp ',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus tingkat',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                    ),
                  ],
                ),
              ),
            if (_rows.length < 10)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah tingkat'),
                ),
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Ringkasan',
              child: Text(_preview(), style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving || _outletId == null ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan aturan'),
            ),
          ],
        ],
      ),
    );
  }
}
