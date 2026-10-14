import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/meta_db.dart';
import 'auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _server = TextEditingController(text: defaultServerUrl());
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(metaDbProvider).getMeta('server_url').then((m) {
      if (m != null && mounted)
        setState(() => _server.text = m['url'] as String);
    });
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(
            baseUrl: _server.text,
            username: _user.text,
            password: _pass.text,
          );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RMS Login',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Alamat server',
                  hintText: 'http://192.168.1.10:8000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _user,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _loading ? null : _login(),
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
                  onPressed: _loading ? null : _login,
                  child: Text(_loading ? 'Memproses...' : 'Masuk'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
