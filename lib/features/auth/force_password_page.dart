import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/shell/auth_layout.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
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
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

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

  Widget _rule(bool ok, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? AppColors.success : AppColors.muted,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: ok ? AppColors.ink : AppColors.muted,
          ),
        ),
      ],
    ),
  );

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
      tooltip: _show ? 'Sembunyikan' : 'Tampilkan',
      icon: Icon(
        _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      onPressed: () => setState(() => _show = !_show),
    ),
  );

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Buat password baru',
    subtitle: 'Langkah keamanan sekali saja',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Password Anda dibuat oleh admin. Demi keamanan, buat password baru '
                  'yang hanya Anda yang tahu sebelum memakai aplikasi.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _old,
          obscureText: !_show,
          decoration: _dec('Password sementara'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _new,
          obscureText: !_show,
          decoration: _dec('Password baru (min. 8 karakter)'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _again,
          obscureText: !_show,
          decoration: _dec('Ulangi password baru'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _busy ? null : _submit(),
        ),
        const SizedBox(height: 10),
        _rule(_new.text.length >= 8, 'Minimal 8 karakter'),
        _rule(
          _new.text.isNotEmpty && _new.text != _old.text,
          'Berbeda dari password sementara',
        ),
        _rule(
          _again.text.isNotEmpty && _new.text == _again.text,
          'Konfirmasi cocok',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.roseSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF9F1239),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    ),
  );
}
