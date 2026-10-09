import 'package:flutter/material.dart';

/// Dialog alasan wajib (min. 3 karakter). Return null jika dibatalkan.
Future<String?> askReason(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Alasan (wajib)'),
          onChanged: (_) => setS(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: c.text.trim().length < 3
                ? null
                : () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    ),
  );
}
