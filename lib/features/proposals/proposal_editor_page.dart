import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_extra.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../menu/menu_item.dart';
import '../menu/menu_providers.dart';
import 'menu_proposal.dart';
import 'proposal_providers.dart';

class ProposalEditorPage extends ConsumerStatefulWidget {
  const ProposalEditorPage({super.key, this.existing});
  final MenuProposal? existing;
  @override
  ConsumerState<ProposalEditorPage> createState() => _ProposalEditorPageState();
}

class _ProposalEditorPageState extends ConsumerState<ProposalEditorPage> {
  late String _kind = widget.existing?.kind ?? 'new';
  MenuItem? _target;
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _cat = TextEditingController(text: widget.existing?.category);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.proposedPrice}',
  );
  late bool _withRecipe =
      widget.existing == null || widget.existing!.recipe != null;
  late List<RecipeLine> _lines = [...?widget.existing?.recipe];

  @override
  void dispose() {
    _name.dispose();
    _cat.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _pickTarget(MenuItem m) {
    setState(() {
      _target = m;
      _name.text = m.name;
      _cat.text = m.category;
      _desc.text = m.description;
      _price.text = '${m.price}';
      if (_withRecipe && _lines.isEmpty) {
        _lines = [...?ref.read(recipesProvider).value?[m.id]?.lines];
      }
    });
  }

  Future<void> _addLine(List<Ingredient> ings) async {
    final avail = ings
        .where((i) => !_lines.any((l) => l.ingredientId == i.id))
        .toList();
    if (avail.isEmpty) {
      _toast('Tidak ada bahan lain. Tambahkan di Stok → Bahan.');
      return;
    }
    final ing = await showDialog<Ingredient>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih bahan'),
        children: [
          for (final i in avail)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text('${i.name} (${i.unit})'),
            ),
        ],
      ),
    );
    if (ing == null || !mounted) return;
    final r = await formDialog(
      context,
      ing.name,
      ['Takaran per porsi (${ing.unit})'],
      numeric: {0},
    );
    final q = r == null ? null : parseNum(r[0]);
    if (q == null || q <= 0) return;
    setState(() => _lines.add(RecipeLine(ingredientId: ing.id, qty: q)));
  }

  Future<void> _editLine(int i, Map<String, Ingredient> ings) async {
    final l = _lines[i];
    final r = await formDialog(
      context,
      ings[l.ingredientId]?.name ?? 'Takaran',
      ['Takaran per porsi'],
      initial: [qtyPlain(l.qty)],
      numeric: {0},
    );
    final q = r == null ? null : parseNum(r[0]);
    if (q == null || q <= 0) return;
    setState(
      () => _lines[i] = RecipeLine(ingredientId: l.ingredientId, qty: q),
    );
  }

  Future<void> _submit(MenuItem? target) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (_kind == 'change' && target == null) {
      _toast('Pilih menu yang ingin diubah');
      return;
    }
    if (_name.text.trim().isEmpty) {
      _toast('Nama menu wajib diisi');
      return;
    }
    if (price <= 0) {
      _toast('Harga usulan harus diisi');
      return;
    }
    final withRecipe = _kind == 'new' || _withRecipe;
    if (_kind == 'new' && _lines.isEmpty) {
      _toast('Resep wajib diisi untuk menu baru (untuk menghitung food cost)');
      return;
    }
    final existing = widget.existing;
    await ref
        .read(proposalRepositoryProvider)
        .save(
          MenuProposal(
            id: existing?.id ?? const Uuid().v4(),
            kind: _kind,
            targetId: _kind == 'change' ? target!.id : null,
            name: _name.text.trim(),
            category: _cat.text.trim(),
            description: _desc.text.trim(),
            proposedPrice: price,
            recipe: withRecipe ? List.of(_lines) : null,
            submittedBy: user.uid,
            submittedByName: user.name,
            createdAt:
                existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
    _toast('Usulan dikirim ke owner');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final master = [...?ref.watch(menuMasterProvider).value]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final ings = ref.watch(ingredientsProvider).value ?? <Ingredient>[];
    final ingMap = {for (final i in ings) i.id: i};
    final avg = ref.watch(avgCostProvider);
    final target =
        _target ??
        (widget.existing?.targetId == null
            ? null
            : master
                  .where((m) => m.id == widget.existing!.targetId)
                  .firstOrNull);
    final showRecipe = _kind == 'new' || _withRecipe;
    final cost = foodCostOf(_lines, avg);
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final missingPrice = _lines.any((l) => avg[l.ingredientId] == null);
    final pct = price > 0 && _lines.isNotEmpty ? marginPct(price, cost) : null;
    final marginTone = toneColors(
      pct == null
          ? Tone.neutral
          : (pct >= 60
                ? Tone.success
                : (pct >= 30 ? Tone.warning : Tone.danger)),
    );
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final kindCard = SectionCard(
      title: 'Jenis usulan',
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'new', label: Text('Menu baru')),
          ButtonSegment(value: 'change', label: Text('Ubah menu/harga')),
        ],
        selected: {_kind},
        onSelectionChanged: widget.existing != null
            ? null
            : (v) => setState(() => _kind = v.first),
      ),
    );

    final infoCard = SectionCard(
      title: 'Informasi menu',
      child: Column(
        children: [
          if (_kind == 'change') ...[
            DropdownButtonFormField<String>(
              initialValue: target?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Menu yang diubah'),
              items: [
                for (final m in master)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.name} • ${rupiah.format(m.price)}'),
                  ),
              ],
              onChanged: widget.existing != null
                  ? null
                  : (id) {
                      final m = master.where((x) => x.id == id).firstOrNull;
                      if (m != null) _pickTarget(m);
                    },
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama menu'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cat,
            decoration: const InputDecoration(labelText: 'Kategori'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga usulan (Rp)',
              prefixText: 'Rp ',
              helperText: 'Harga final ditetapkan owner saat menyetujui',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );

    final recipeCard = SectionCard(
      title: 'Resep per porsi',
      trailing: showRecipe
          ? TextButton.icon(
              onPressed: () => _addLine(ings),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah bahan'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_kind == 'change')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ikut ubah resep'),
              value: _withRecipe,
              onChanged: (v) => setState(() {
                _withRecipe = v;
                if (v && _lines.isEmpty && target != null) {
                  _lines = [
                    ...?ref.read(recipesProvider).value?[target.id]?.lines,
                  ];
                }
              }),
            ),
          if (showRecipe) ...[
            if (_lines.isEmpty)
              const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Belum ada bahan',
                message: 'Ketuk "Tambah bahan"',
              ),
            for (var i = 0; i < _lines.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _editLine(i, ingMap),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ingMap[_lines[i].ingredientId]?.name ??
                                    '(bahan dihapus)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (avg[_lines[i].ingredientId] == null)
                                Text(
                                  'belum ada harga beli',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${qtyText(_lines[i].qty)} ${ingMap[_lines[i].ingredientId]?.unit ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _lines.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    final form = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        kindCard,
        const SizedBox(height: 12),
        infoCard,
        const SizedBox(height: 12),
        recipeCard,
      ],
    );

    final warning = missingPrice
        ? Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.roseSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Sebagian bahan belum punya harga beli, food cost bisa lebih rendah dari sebenarnya.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9F1239),
              ),
            ),
          )
        : const SizedBox.shrink();

    final summaryCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showRecipe)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: marginTone.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Margin pada harga usulan',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    pct == null ? '-' : '$pct%',
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: marginTone.fg,
                    ),
                  ),
                ],
              ),
            ),
          if (showRecipe) ...[
            const SizedBox(height: 10),
            KvRow('Food cost per porsi', rupiah.format(cost.round())),
          ],
          KvRow('Harga usulan', price > 0 ? rupiah.format(price) : '-'),
          warning,
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _submit(target),
            child: const Text('Kirim ke owner'),
          ),
        ],
      ),
    );

    final bottomBar = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (showRecipe)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Food cost ${rupiah.format(cost.round())}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      pct == null ? 'Margin -' : 'Margin $pct%',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: marginTone.fg,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: () => _submit(target),
              child: const Text('Kirim ke owner'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Usulan baru' : 'Edit usulan'),
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                SizedBox(
                  width: 380,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: summaryCard,
                  ),
                ),
              ],
            )
          : form,
      bottomNavigationBar: wide ? null : bottomBar,
    );
  }
}
