import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/shell/auth_layout.dart';

import '../../core/api/api_exception.dart';
import '../../core/db/meta_db.dart';
import '../../core/theme/app_colors.dart';
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
  bool _showPass = false;
  bool _editServer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(metaDbProvider).getMeta('server_url').then((m) {
      if (m != null && mounted) {
        setState(() => _server.text = m['url'] as String);
      }
    });
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
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
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Selamat datang',
    subtitle: 'Masuk untuk melanjutkan',
    child: AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _user,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: !_showPass,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _showPass ? 'Sembunyikan' : 'Tampilkan',
                icon: Icon(
                  _showPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
            onSubmitted: (_) => _loading ? null : _login(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.roseSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Color(0xFF9F1239),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Masuk'),
          ),
          const SizedBox(height: 16),
          if (_editServer)
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Alamat server',
                hintText: 'mis. https://rms.contoh.com/api',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _editServer = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.dns_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _server.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      'Ubah',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Restaurant Management System • by Kovalen Teknologi',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}
