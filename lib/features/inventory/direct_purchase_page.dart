import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'direct_purchase.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

/// Satu baris yang sedang diisi.
class _Line {
  _Line(this.ingredient) : useBuyUnit = ingredient.buyUnit.isNotEmpty;
  final Ingredient ingredient;
  bool useBuyUnit;
  final qty = TextEditingController();
  final price = TextEditingController();
  final note = TextEditingController();

  String get unit => useBuyUnit ? ingredient.buyUnit : ingredient.unit;
  double get factor => useBuyUnit ? ingredient.buyFactor : 1;
  double? get qtyValue {
    final v = parseNum(qty.text);
    return v == null || v <= 0 ? null : v;
  }

  double get priceValue => parseNum(price.text.replaceAll('.', '')) ?? 0;
  bool get valid => qtyValue != null && priceValue >= 0;

  void dispose() {
    qty.dispose();
    price.dispose();
    note.dispose();
  }
}

/// Catat belanja langsung (tanpa PO): beberapa bahan sekaligus, tiap baris punya catatan,
/// plus tempat belanja & catatan keseluruhan. Stok bertambah otomatis setelah tersimpan.
class DirectPurchasePage extends ConsumerStatefulWidget {
  const DirectPurchasePage({super.key, this.initial});
  final Ingredient? initial; // dibuka dari menu satu bahan
  @override
  ConsumerState<DirectPurchasePage> createState() => _DirectPurchasePageState();
}

class _DirectPurchasePageState extends ConsumerState<DirectPurchasePage> {
  final _place = TextEditingController();
  final _note = TextEditingController();
  final List<_Line> _lines = [];
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _lines.add(_Line(widget.initial!));
  }

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold(0, (s, l) => s + l.priceValue);
  bool get _valid => _lines.isNotEmpty && _lines.every((l) => l.valid);

  Future<void> _addIngredient() async {
    final all = [...?ref.read(ingredientsProvider).value]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IngredientPicker(all: all, taken: {for (final l in _lines) l.ingredient.id}),
    );
    if (picked != null) setState(() => _lines.add(_Line(picked)));
  }

  Future<void> _save() async {
    final u = ref.read(appUserProvider).value;
    final id = const Uuid().v4();
    final now = DateTime.now();
    // jam disamakan dengan sekarang bila tanggal = hari ini, selain itu jam 12.00
    final at = DateUtils.isSameDay(_date, now)
        ? now
        : DateTime(_date.year, _date.month, _date.day, 12);
    final p = DirectPurchase(
      id: id,
      number: 'BL-${DateFormat('yyyyMMdd').format(at)}-${id.substring(0, 4).toUpperCase()}',
      at: at.millisecondsSinceEpoch,
      place: _place.text.trim(),
      note: _note.text.trim(),
      createdByName: u?.name ?? '',
      createdAt: now.millisecondsSinceEpoch,
      lines: [
        for (final l in _lines)
          PurchaseLine(
            ingredientId: l.ingredient.id,
            name: l.ingredient.name,
            qty: l.qtyValue!,
            unit: l.unit,
            factor: l.factor,
            price: l.priceValue,
            note: l.note.text.trim(),
          ),
      ],
    );
    setState(() => _saving = true);
    try {
      await ref.read(directPurchaseRepositoryProvider).save(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Belanja ${p.number} dicatat (${_lines.length} bahan)')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belanja langsung')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_lines.length} bahan',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                    ),
                    Text(
                      rupiah.format(_total),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _valid && !_saving ? _save : null,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: AppLoader(size: 16, onDark: true))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Simpan belanja'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            title: 'Belanja',
            child: Column(
              children: [
                TextField(
                  controller: _place,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tempat belanja',
                    hintText: 'mis. Pasar Baru, Toko Sinar Jaya',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: now.subtract(const Duration(days: 30)),
                      lastDate: now,
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal belanja',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_dateFmt.format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'mis. belanja mingguan, dibayar tunai',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _lines.length; i++) Entrance(index: i, child: _lineCard(i)),
          OutlinedButton.icon(
            onPressed: _addIngredient,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah bahan'),
          ),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Tambahkan semua bahan yang dibeli dalam satu belanja. Stok bertambah otomatis setelah disimpan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.faint, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    final ing = l.ingredient;
    final q = l.qtyValue;
    final perUnit = q == null || l.priceValue <= 0 ? null : l.priceValue / q;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
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
                child: Text(ing.name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (ing.buyUnit.isNotEmpty)
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(value: true, label: Text(ing.buyUnit)),
                    ButtonSegment(value: false, label: Text(ing.unit)),
                  ],
                  selected: {l.useBuyUnit},
                  onSelectionChanged: (v) => setState(() => l.useBuyUnit = v.first),
                ),
              IconButton(
                tooltip: 'Hapus baris',
                onPressed: () => setState(() => _lines.removeAt(i).dispose()),
                icon: Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: l.qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: InputDecoration(labelText: 'Jumlah', suffixText: l.unit, isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: l.price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Total harga', prefixText: 'Rp ', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: l.note,
                  decoration: const InputDecoration(
                    hintText: 'Catatan bahan, mis. merek / kualitas',
                    isDense: true,
                  ),
                ),
                if (perUnit != null || (q != null && l.useBuyUnit && l.factor != 1)) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (perUnit != null) '≈ ${rupiah.format(perUnit)} / ${l.unit}',
                      if (q != null && l.factor != 1) '= ${qtyText(q * l.factor)} ${ing.unit}',
                    ].join(' · '),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker({required this.all, required this.taken});
  final List<Ingredient> all;
  final Set<String> taken;
  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.all.where((i) => _q.isEmpty || i.name.toLowerCase().contains(_q)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari bahan',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'Bahan tidak ditemukan')
                : ListView.builder(
                    controller: scroll,
                    itemCount: list.length,
                    itemBuilder: (_, k) {
                      final i = list[k];
                      final taken = widget.taken.contains(i.id);
                      return ListTile(
                        title: Text(i.name),
                        subtitle: Text(i.buyUnit.isEmpty ? i.unit : '${i.buyUnit} (1 = ${qtyText(i.buyFactor)} ${i.unit})'),
                        trailing: taken ? const StatusPill('Sudah ditambah') : null,
                        onTap: () => Navigator.pop(context, i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
