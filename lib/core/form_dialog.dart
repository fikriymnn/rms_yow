import 'package:flutter/material.dart';

/// Dialog isian generik. Return nilai tiap kolom (sudah di-trim), atau null.
Future<List<String>?> formDialog(
  BuildContext context,
  String title,
  List<String> labels, {
  List<String>? initial,
  Set<int> numeric = const {},
  String okLabel = 'Simpan',
  String? hint,
  Set<int> obscure = const {},
}) {
  final cs = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(text: initial?[i] ?? ''),
  ];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(hint),
              ),
            for (var i = 0; i < labels.length; i++)
              TextField(
                controller: cs[i],
                autofocus: i == 0,
                keyboardType: numeric.contains(i)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                decoration: InputDecoration(labelText: labels[i]),
                obscureText: obscure.contains(i),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, [for (final c in cs) c.text.trim()]),
          child: Text(okLabel),
        ),
      ],
    ),
  );
}
