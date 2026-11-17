import 'package:flutter/material.dart';

/// Daftar kategori unik dari menu yang ada (urut abjad, tanpa yang kosong).
List<String> categoriesOf(Iterable<String> raw) {
  final seen = <String, String>{}; // huruf kecil -> ejaan pertama
  for (final c in raw) {
    final t = c.trim();
    if (t.isNotEmpty) seen.putIfAbsent(t.toLowerCase(), () => t);
  }
  return seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Kategori yang diketik manual tapi sama dengan kategori yang sudah ada (beda huruf
/// besar/kecil atau spasi) memakai ejaan yang sudah ada, agar tidak terpecah dua.
String normalizeCategory(String text, List<String> categories) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  for (final c in categories) {
    if (c.toLowerCase() == t.toLowerCase()) return c;
  }
  return t;
}

const _kNew = '\u0000baru';

/// Isian kategori menu: pilih dari kategori yang sudah ada, atau pilih "Kategori baru"
/// lalu ketik manual. Nilainya disimpan di [controller].
class CategoryField extends StatefulWidget {
  const CategoryField({
    super.key,
    required this.controller,
    required this.categories,
    this.label = 'Kategori',
  });

  final TextEditingController controller;
  final List<String> categories;
  final String label;

  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<CategoryField> {
  late bool _typing; // true = mengetik kategori baru
  final _focus = FocusNode();

  bool _isExisting(String v) =>
      widget.categories.any((c) => c.toLowerCase() == v.trim().toLowerCase());

  @override
  void initState() {
    super.initState();
    final v = widget.controller.text;
    _typing = widget.categories.isEmpty || (v.trim().isNotEmpty && !_isExisting(v));
    widget.controller.addListener(_onExternalChange);
  }

  /// Nilai diubah dari luar (mis. memilih menu yang diusulkan untuk diubah).
  void _onExternalChange() {
    final v = widget.controller.text;
    if (_typing && !_focus.hasFocus && _isExisting(v)) {
      setState(() => _typing = false);
    } else if (!_typing && v.trim().isNotEmpty && !_isExisting(v)) {
      setState(() => _typing = true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChange);
    _focus.dispose();
    super.dispose();
  }

  String? get _selected {
    final v = widget.controller.text.trim().toLowerCase();
    if (v.isEmpty) return null;
    for (final c in widget.categories) {
      if (c.toLowerCase() == v) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_typing) {
      return TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.categories.isNotEmpty && widget.controller.text.isEmpty,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: '${widget.label} baru',
          hintText: 'Ketik nama kategori, mis. Minuman',
          suffixIcon: widget.categories.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Pilih dari kategori yang ada',
                  icon: const Icon(Icons.list_alt_rounded),
                  onPressed: () => setState(() {
                    _typing = false;
                    if (!_isExisting(widget.controller.text)) {
                      widget.controller.clear();
                    }
                  }),
                ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      // key: ganti item terpilih saat nilai berubah dari luar
      key: ValueKey(_selected),
      initialValue: _selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.label),
      hint: const Text('Pilih kategori'),
      items: [
        for (final c in widget.categories)
          DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
        const DropdownMenuItem(
          value: _kNew,
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 18),
              SizedBox(width: 8),
              Text('Kategori baru…'),
            ],
          ),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        if (v == _kNew) {
          setState(() {
            _typing = true;
            widget.controller.clear();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
        } else {
          widget.controller.text = v;
        }
      },
    );
  }
}
