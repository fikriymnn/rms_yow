import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_dialog.dart';
import '../../core/format.dart';
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
    final cs = Theme.of(context).colorScheme;
    final th = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Usulan baru' : 'Edit usulan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'new', label: Text('Menu baru')),
              ButtonSegment(value: 'change', label: Text('Ubah menu/harga')),
            ],
            selected: {_kind},
            onSelectionChanged: widget.existing != null
                ? null
                : (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: 12),
          if (_kind == 'change')
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
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama menu'),
          ),
          TextField(
            controller: _cat,
            decoration: const InputDecoration(labelText: 'Kategori'),
          ),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
          ),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga usulan (Rp)',
              helperText: 'Harga final ditetapkan owner saat menyetujui',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
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
            Text('Resep per porsi', style: th.titleMedium),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Belum ada bahan'),
              ),
            for (var i = 0; i < _lines.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  ingMap[_lines[i].ingredientId]?.name ?? '(bahan dihapus)',
                ),
                subtitle: avg[_lines[i].ingredientId] == null
                    ? Text(
                        'belum ada harga beli',
                        style: TextStyle(color: cs.error),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${qtyText(_lines[i].qty)} ${ingMap[_lines[i].ingredientId]?.unit ?? ''}',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _lines.removeAt(i)),
                    ),
                  ],
                ),
                onTap: () => _editLine(i, ingMap),
              ),
            TextButton.icon(
              onPressed: () => _addLine(ings),
              icon: const Icon(Icons.add),
              label: const Text('Tambah bahan'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Food cost per porsi'),
                        Text(
                          rupiah.format(cost.round()),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Margin pada harga usulan'),
                        Text(
                          price > 0 ? '${marginPct(price, cost)}%' : '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (missingPrice)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Sebagian bahan belum punya harga beli, food cost bisa lebih rendah dari sebenarnya.',
                          style: TextStyle(color: cs.error, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _submit(target),
            child: const Text('Kirim ke owner'),
          ),
        ],
      ),
    );
  }
}
