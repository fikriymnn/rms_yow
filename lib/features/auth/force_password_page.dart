import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'auth_providers.dart';

class ForcePasswordPage extends ConsumerStatefulWidget {
  const ForcePasswordPage({super.key});
  @override
  ConsumerState<ForcePasswordPage> createState() => _ForcePasswordPageState();
}

class _ForcePasswordPageState extends ConsumerState<ForcePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_new.text.length < 8) {
      setState(() => _error = 'Password baru minimal 8 karakter');
      return;
    }
    if (_new.text != _again.text) {
      setState(() => _error = 'Konfirmasi password tidak sama');
      return;
    }
    if (_new.text == _old.text) {
      setState(
        () => _error = 'Password baru harus berbeda dari password sementara',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/change-password',
            data: {'old_password': _old.text, 'new_password': _new.text},
          );
      final messenger = ScaffoldMessenger.of(context);
      await ref
          .read(sessionProvider.notifier)
          .expire(); // server mencabut semua sesi
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Password diganti. Silakan login dengan password baru.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Buat password baru'),
      automaticallyImplyLeading: false,
      actions: [
        TextButton(
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
          child: const Text('Keluar'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Password Anda dibuat oleh admin. Demi keamanan, buat password baru '
                'yang hanya Anda yang tahu sebelum memakai aplikasi.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _old,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password sementara',
                ),
              ),
              TextField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password baru (min. 8 karakter)',
                ),
              ),
              TextField(
                controller: _again,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Ulangi password baru',
                ),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Memproses...' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
