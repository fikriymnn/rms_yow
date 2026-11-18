import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/shell/auth_layout.dart';

import '../../core/api/api_exception.dart';
import '../client/client_pages.dart';
import '../client/client_providers.dart';
import '../../core/theme/app_colors.dart';
import 'auth_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
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
          .login(username: _user.text, password: _pass.text);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchClient() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti akun restoran?'),
        content: const Text(
          'Anda akan keluar dari akun restoran ini dan perlu masuk lagi '
          'dengan email dan password restoran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(clientProvider.notifier).forget();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Selamat datang',
    subtitle: ref.watch(clientProvider).value?.info.name ?? 'Masuk untuk melanjutkan',
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
            AuthErrorBox(_error!),
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
          const DeviceNameTile(),
          const SizedBox(height: 12),
          _SubscriptionTile(enabled: !_loading),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : _switchClient,
            child: const Text('Bukan restoran ini? Ganti akun restoran'),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Restaurant Management System • by Kovalen Teknologi',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Info masa aktif + tombol perpanjang langganan di halaman login.
class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(clientProvider).value;
    if (c == null) return const SizedBox.shrink();
    final s = c.info.subscription;
    final text = s.lifetime
        ? 'Langganan aktif selamanya'
        : s.inGrace
        ? 'Masa tenggang • berakhir ${formatClientDate(s.validUntil)}'
        : 'Aktif hingga ${formatClientDate(s.validUntil)} • ${daysLeftOf(s)} hari lagi';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: s.inGrace ? const Color(0xFFF7EBD6) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            s.inGrace ? Icons.hourglass_bottom_rounded : Icons.workspace_premium_outlined,
            size: 20,
            color: s.inGrace ? AppColors.warning : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (!s.lifetime)
            TextButton(
              onPressed: enabled
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SubscriptionPage(blocked: false),
                      ),
                    )
                  : null,
              child: const Text('Perpanjang'),
            ),
        ],
      ),
    );
  }
}
