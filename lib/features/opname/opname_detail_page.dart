import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import 'opname_list_page.dart';
import 'opname_models.dart';
import 'opname_providers.dart';

final _timeFmt = DateFormat('d MMM yyyy, HH.mm', 'id_ID');

enum _Filter { all, empty, filled, diff }

/// Satu tiket opname: isi stok fisik tiap bahan, simpan di perangkat, lalu kirim.
class OpnameDetailPage extends ConsumerStatefulWidget {
  const OpnameDetailPage({super.key, required this.opnameId});
  final String opnameId;
  @override
  ConsumerState<OpnameDetailPage> createState() => _OpnameDetailPageState();
}

class _OpnameDetailPageState extends ConsumerState<OpnameDetailPage> {
  // isi input saat ini & yang terakhir disimpan di perangkat
  final Map<String, TextEditingController> _actual = {};
  final Map<String, TextEditingController> _note = {};
  Map<String, OpnameCount> _saved = {};
  int? _savedAt;
  bool _loaded = false;
  bool _busy = false;
  bool _draftCleared = false;
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    for (final c in [..._actual.values, ..._note.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final d = await ref.read(opnameDraftStoreProvider).load(widget.opnameId);
    if (!mounted) return;
    setState(() {
      _saved = d.counts;
      _savedAt = d.savedAt;
      for (final e in d.counts.entries) {
        _ctl(_actual, e.key).text = e.value.actual;
        _ctl(_note, e.key).text = e.value.note;
      }
      _loaded = true;
    });
  }

  TextEditingController _ctl(Map<String, TextEditingController> m, String id) =>
      m.putIfAbsent(id, TextEditingController.new);

  OpnameCount _current(String id) =>
      OpnameCount(actual: _actual[id]?.text ?? '', note: _note[id]?.text ?? '');

  /// Bahan yang isinya berbeda dari draf tersimpan.
  int _unsaved(List<Ingredient> ings) {
    var n = 0;
    for (final i in ings) {
      final c = _current(i.id);
      final s = _saved[i.id] ?? const OpnameCount();
      if (c.actual.trim() != s.actual.trim() || c.note.trim() != s.note.trim()) n++;
    }
    return n;
  }

  double? _value(String id) {
    final t = _actual[id]?.text.trim() ?? '';
    if (t.isEmpty) return null;
    final v = parseNum(t);
    return v == null || v < 0 ? null : v;
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save(List<Ingredient> ings, {bool quiet = false}) async {
    final counts = {for (final i in ings) i.id: _current(i.id)};
    final at = await ref.read(opnameDraftStoreProvider).save(widget.opnameId, counts);
    ref.invalidate(opnameDraftFilledProvider(widget.opnameId));
    if (!mounted) return;
    setState(() {
      _saved = {
        for (final e in counts.entries)
          if (!e.value.isEmpty) e.key: e.value,
      };
      _savedAt = at;
    });
    if (!quiet) _toast('Hitungan disimpan di perangkat ini');
  }

  void _discard(List<Ingredient> ings) {
    setState(() {
      for (final i in ings) {
        final s = _saved[i.id] ?? const OpnameCount();
        _ctl(_actual, i.id).text = s.actual;
        _ctl(_note, i.id).text = s.note;
      }
    });
  }

  void _fillEmpty(List<Ingredient> ings, Map<String, double> levels) {
    var n = 0;
    setState(() {
      for (final i in ings) {
        final c = _ctl(_actual, i.id);
        if (c.text.trim().isEmpty) {
          c.text = qtyPlain(levels[i.id] ?? 0);
          n++;
        }
      }
    });
    _toast(n == 0 ? 'Semua bahan sudah terisi' : '$n bahan diisi dengan stok sistem. Jangan lupa simpan.');
  }

  Future<bool> _confirm(String title, String body, String ok, {bool danger = false}) async =>
      await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
            FilledButton(
              style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ok),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _submit(StockOpname o, List<Ingredient> ings, Map<String, double> levels) async {
    final diffs = ings.where((i) => ((_value(i.id) ?? 0) - (levels[i.id] ?? 0)).abs() > 1e-6).length;
    final ok = await _confirm(
      'Kirim hasil opname?',
      '${ings.length} bahan dihitung, $diffs bahan berselisih dengan stok sistem. '
          'Setelah dikirim, stok disesuaikan dengan stok fisik dan tiket tidak bisa diubah lagi.',
      'Kirim',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      // simpan dulu di perangkat: bila pengiriman gagal, hitungan tidak hilang
      await _save(ings, quiet: true);
      final u = ref.read(appUserProvider).value;
      await ref.read(opnameRepositoryProvider).save(
        o.copyWith(
          status: OpnameStatus.submitted,
          submittedByName: u?.name ?? '',
          submittedAt: DateTime.now().millisecondsSinceEpoch,
          items: [
            for (final i in ings)
              OpnameItem(
                ingredientId: i.id,
                name: i.name,
                unit: i.unit,
                actual: _value(i.id)!,
                note: _note[i.id]?.text.trim() ?? '',
              ),
          ],
        ),
      );
      _toast('Hasil opname dikirim');
    } catch (e) {
      _toast('Gagal mengirim: $e. Hitungan tetap tersimpan di perangkat.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(StockOpname o) async {
    final ok = await _confirm(
      'Batalkan ${o.number}?',
      'Tiket ditutup tanpa mengubah stok. Hitungan yang sudah diisi di perangkat ini dihapus.',
      'Batalkan opname',
      danger: true,
    );
    if (!ok) return;
    final u = ref.read(appUserProvider).value;
    await ref.read(opnameRepositoryProvider).save(
      o.copyWith(
        status: OpnameStatus.cancelled,
        cancelledByName: u?.name ?? '',
        cancelledAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await ref.read(opnameDraftStoreProvider).clear(o.id);
    ref.invalidate(opnameDraftFilledProvider(o.id));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final o = ref.watch(opnameProvider(widget.opnameId));
    if (o == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stok opname')),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Tiket tidak ditemukan'),
      );
    }
    // server sudah memproses: draf di perangkat tidak diperlukan lagi
    if (o.processedAt != null && !_draftCleared) {
      _draftCleared = true;
      Future.microtask(() async {
        await ref.read(opnameDraftStoreProvider).clear(o.id);
        ref.invalidate(opnameDraftFilledProvider(o.id));
      });
    }
    return o.isOpen ? _openView(o) : _doneView(o);
  }

  // ------------------------------------------------------------------ tiket berjalan

  Widget _openView(StockOpname o) {
    final user = ref.watch(appUserProvider).value;
    final canEdit = user?.can('stock_opname.update') ?? false;
    final canCancel = user?.can('stock_opname.delete') ?? false;
    final ings = [...?ref.watch(ingredientsProvider).value]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final levels = ref.watch(stockLevelsProvider);

    final filled = ings.where((i) => _value(i.id) != null).length;
    final invalid = ings.where((i) {
      final t = _actual[i.id]?.text.trim() ?? '';
      return t.isNotEmpty && _value(i.id) == null;
    }).length;
    bool hasDiff(Ingredient i) {
      final v = _value(i.id);
      return v != null && (v - (levels[i.id] ?? 0)).abs() > 1e-6;
    }

    final diffs = ings.where(hasDiff).length;
    final unsaved = _loaded ? _unsaved(ings) : 0;
    final total = ings.length;
    final allFilled = total > 0 && filled == total && invalid == 0;

    final shown = ings.where((i) {
      final ok = switch (_filter) {
        _Filter.all => true,
        _Filter.empty => _value(i.id) == null,
        _Filter.filled => _value(i.id) != null,
        _Filter.diff => hasDiff(i),
      };
      return ok && (_query.isEmpty || i.name.toLowerCase().contains(_query));
    }).toList();

    return PopScope(
      canPop: unsaved == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final save = await showAppDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hitungan belum disimpan'),
            content: Text('$unsaved bahan berubah sejak terakhir disimpan.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Buang')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
            ],
          ),
        );
        if (save == null || !mounted) return;
        if (save) await _save(ings, quiet: true);
        if (mounted) {
          if (!save) _discard(ings);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.number, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                'Tanggal opname ${opnameDateText(o.date)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(
          left: canCancel
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Color(0xFFF0C8CA)),
                  ),
                  onPressed: _busy ? null : () => _cancel(o),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Batalkan'),
                )
              : null,
          right: canEdit
              ? FilledButton.icon(
                  onPressed: allFilled && !_busy ? () => _submit(o, ings, levels) : null,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: AppLoader(size: 16, onDark: true))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(allFilled ? 'Kirim hasil' : 'Kirim ($filled/$total)'),
                )
              : null,
        ),
        body: !_loaded
            ? const SkeletonList()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _infoCard(o),
                  const SizedBox(height: 12),
                  _progressCard(filled, total),
                  const SizedBox(height: 12),
                  _stats([
                    ('Total', '$total', AppColors.ink),
                    ('Belum dihitung', '${total - filled}', total - filled > 0 ? AppColors.primary : AppColors.ink),
                    ('Terisi', '$filled', AppColors.sageInk),
                    ('Ada selisih', '$diffs', diffs > 0 ? AppColors.warning : AppColors.ink),
                  ]),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (f, label) in const [
                          (_Filter.all, 'Semua'),
                          (_Filter.empty, 'Belum dihitung'),
                          (_Filter.filled, 'Terisi'),
                          (_Filter.diff, 'Ada selisih'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama bahan',
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canEdit) _toolbar(ings, levels, unsaved),
                  const SizedBox(height: 10),
                  if (ings.isEmpty)
                    const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Belum ada bahan',
                      message: 'Tambahkan bahan di menu Stok terlebih dahulu.',
                    )
                  else if (shown.isEmpty)
                    const EmptyState(icon: Icons.filter_alt_off_outlined, title: 'Tidak ada bahan di filter ini')
                  else
                    LayoutBuilder(
                      builder: (context, c) => c.maxWidth >= 760
                          ? _table(shown, levels, canEdit)
                          : Column(
                              children: [
                                for (final i in shown) _itemCard(i, levels[i.id] ?? 0, canEdit),
                              ],
                            ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _toolbar(List<Ingredient> ings, Map<String, double> levels, int unsaved) {
    final savedText = _savedAt == null
        ? 'Belum pernah disimpan'
        : 'Tersimpan ${DateFormat('HH.mm', 'id_ID').format(DateTime.fromMillisecondsSinceEpoch(_savedAt!))}';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _fillEmpty(ings, levels),
          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: const Text('Isi kosong dengan stok sistem'),
        ),
        AnimatedSwitcher(
          duration: Motion.fast,
          child: unsaved > 0
              ? Row(
                  key: const ValueKey('dirty'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulseDot(color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      '$unsaved belum disimpan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                    TextButton(onPressed: () => _discard(ings), child: const Text('Buang')),
                  ],
                )
              : Text(
                  savedText,
                  key: const ValueKey('clean'),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.faint),
                ),
        ),
        FilledButton.tonalIcon(
          onPressed: unsaved > 0 ? () => _save(ings) : null,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Simpan hitungan'),
        ),
      ],
    );
  }

  InputDecoration _dense(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  Widget _actualField(Ingredient i, bool enabled) => TextField(
    controller: _ctl(_actual, i.id),
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    textAlign: TextAlign.right,
    decoration: _dense('0').copyWith(suffixText: i.unit),
    onChanged: (_) => setState(() {}),
  );

  Widget _noteField(Ingredient i, bool enabled) => TextField(
    controller: _ctl(_note, i.id),
    enabled: enabled,
    decoration: _dense('Catatan, mis. 2 rusak'),
    onChanged: (_) => setState(() {}),
  );

  Widget _diffText(Ingredient i, double system) {
    final v = _value(i.id);
    final bad = (_actual[i.id]?.text.trim().isNotEmpty ?? false) && v == null;
    if (bad) {
      return Text('Angka tidak valid', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.danger));
    }
    if (v == null) return Text('—', style: GoogleFonts.plusJakartaSans(color: AppColors.faint));
    final d = v - system;
    final zero = d.abs() < 1e-6;
    return Text(
      zero ? '0' : '${d > 0 ? '+' : ''}${qtyText(d)}',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: zero ? AppColors.sageInk : (d < 0 ? AppColors.danger : AppColors.warning),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _statusPill(Ingredient i) {
    final s = _saved[i.id];
    final c = _current(i.id);
    if (c.actual.trim().isEmpty) return const StatusPill('Belum');
    final savedNow = s != null && s.actual.trim() == c.actual.trim() && s.note.trim() == c.note.trim();
    return savedNow
        ? const StatusPill('Tersimpan', tone: Tone.success)
        : const StatusPill('Belum disimpan', tone: Tone.warning);
  }

  Widget _itemCard(Ingredient i, double system, bool canEdit) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                i.name,
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            _statusPill(i),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Stok sistem ${qtyText(system)} ${i.unit}',
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 5, child: _actualField(i, canEdit)),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Selisih', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.faint)),
                  _diffText(i, system),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _noteField(i, canEdit),
      ],
    ),
  );

  Widget _table(List<Ingredient> rows, Map<String, double> levels, bool canEdit) {
    final head = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: 0.2,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('Bahan', style: head)),
                Expanded(flex: 2, child: Text('Sistem', style: head, textAlign: TextAlign.right)),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Text('Fisik', style: head)),
                Expanded(flex: 2, child: Text('Selisih', style: head, textAlign: TextAlign.right)),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: Text('Catatan', style: head)),
                SizedBox(width: 120, child: Text('Status', style: head, textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (var k = 0; k < rows.length; k++)
            Container(
              color: k.isOdd ? AppColors.surfaceAlt : AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[k].name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${qtyText(levels[rows[k].id] ?? 0)} ${rows[k].unit}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _actualField(rows[k], canEdit)),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _diffText(rows[k], levels[rows[k].id] ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _noteField(rows[k], canEdit)),
                  SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _statusPill(rows[k]))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ tiket selesai / batal

  Widget _doneView(StockOpname o) {
    final items = [...o.items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final shown = items.where((i) {
      final ok = _filter != _Filter.diff || (i.diff ?? 0).abs() > 1e-6;
      return ok && (_query.isEmpty || i.name.toLowerCase().contains(_query));
    }).toList();
    final minus = items.where((i) => (i.diff ?? 0) < -1e-6).length;
    final plus = items.where((i) => (i.diff ?? 0) > 1e-6).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.number, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(
              'Tanggal opname ${opnameDateText(o.date)}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (o.awaitingServer) ...[
            _banner(
              Icons.cloud_upload_outlined,
              'Menunggu diproses server',
              'Stok disesuaikan setelah tiket terkirim. Hitungan tetap tersimpan di perangkat ini.',
              action: TextButton(
                onPressed: () => ref.read(syncControllerProvider.notifier).syncNow(),
                child: const Text('Kirim ulang'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (o.status == OpnameStatus.cancelled) ...[
            _banner(
              Icons.block_rounded,
              'Opname dibatalkan',
              'Tiket ditutup tanpa mengubah stok.',
            ),
            const SizedBox(height: 12),
          ],
          _infoCard(o),
          if (o.status == OpnameStatus.submitted) ...[
            const SizedBox(height: 12),
            _stats([
              ('Bahan', '${items.length}', AppColors.ink),
              ('Sesuai', '${items.length - minus - plus}', AppColors.sageInk),
              ('Kurang', '$minus', minus > 0 ? AppColors.danger : AppColors.ink),
              ('Lebih', '$plus', plus > 0 ? AppColors.warning : AppColors.ink),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _filter != _Filter.diff,
                  onSelected: (_) => setState(() => _filter = _Filter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Ada selisih'),
                  selected: _filter == _Filter.diff,
                  onSelected: (_) => setState(() => _filter = _Filter.diff),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari nama bahan',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            for (final i in shown) _resultRow(i),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(OpnameItem i) {
    final d = i.diff;
    final zero = d == null || d.abs() < 1e-6;
    final color = d == null
        ? AppColors.faint
        : zero
            ? AppColors.sageInk
            : (d < 0 ? AppColors.danger : AppColors.warning);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Sistem ${i.system == null ? '…' : qtyText(i.system!)} → fisik ${qtyText(i.actual)} ${i.unit}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                ),
                if (i.note.isNotEmpty)
                  Text(i.note, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.faint)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            d == null ? '…' : (zero ? '0' : '${d > 0 ? '+' : ''}${qtyText(d)}'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ bagian bersama

  Widget _infoCard(StockOpname o) {
    final outlet = ref.watch(activeOutletProvider);
    String time(int? ms) => ms == null ? '-' : _timeFmt.format(DateTime.fromMillisecondsSinceEpoch(ms));
    final rows = <(String, Widget)>[
      ('Status', Align(alignment: Alignment.centerLeft, child: StatusPill(o.status.label, tone: opnameTone(o.status)))),
      ('Outlet', _val(outlet?.name ?? '-')),
      ('Tanggal opname', _val(opnameDateText(o.date))),
      ('Dibuat oleh', _val(o.createdByName)),
      ('Dibuat', _val(time(o.createdAt))),
      if (o.status == OpnameStatus.submitted) ('Dikirim', _val('${time(o.submittedAt)} · ${o.submittedByName}')),
      if (o.status == OpnameStatus.cancelled) ('Dibatalkan', _val('${time(o.cancelledAt)} · ${o.cancelledByName}')),
      ('Catatan', _val(o.note.isEmpty ? '—' : o.note)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 640 ? 4 : 2;
          final w = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final (label, v) in rows)
                SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.faint),
                      ),
                      const SizedBox(height: 3),
                      v,
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _val(String s) => Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700));

  Widget _progressCard(int filled, int total) {
    final pct = total == 0 ? 0.0 : filled / total;
    final done = pct >= 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Terisi $filled/$total bahan',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: done ? AppColors.sageInk : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.sunken,
                color: done ? AppColors.sage : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hitungan disimpan di perangkat ini sampai dikirim. Tombol Kirim aktif setelah semua bahan terisi.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Widget _stats(List<(String, String, Color)> items) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (label, value, color) in items)
            Container(
              width: w,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _banner(IconData icon, String title, String body, {Widget? action}) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7EBD6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF8A5A12)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A5A12),
                ),
              ),
              Text(body, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF8A5A12))),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _bottomBar({Widget? left, Widget? right}) {
    if (left == null && right == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            ?left,
            const Spacer(),
            ?right,
          ],
        ),
      ),
    );
  }
}
