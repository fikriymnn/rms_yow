import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/config/app_config.dart';
import '../../core/device/device_name.dart';
import '../../core/theme/app_colors.dart';
import '../../shell/auth_layout.dart';
import '../auth/auth_providers.dart';
import 'client_models.dart';
import 'client_providers.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// "selamanya" atau "s.d. 12 Des 2026".
String formatValidUntil(Subscription s) =>
    s.lifetime ? 'selamanya' : 's.d. ${formatClientDate(s.validUntil)}';

String formatClientDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// Kupon: huruf besar, tanpa spasi; tanda minus dibiarkan (server mengabaikannya).
class _CouponFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase().replaceAll(' ', ''));
}

class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.roseSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: Color(0xFF9F1239)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9F1239)),
          ),
        ),
      ],
    ),
  );
}

Widget _busy() => const SizedBox(
  width: 22,
  height: 22,
  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
);

/// Layar pertama: aktivasi perangkat untuk satu klien.
class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({super.key});
  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _coupon = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _pass, _coupon]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty || _coupon.text.trim().isEmpty) {
      setState(() => _error = 'Email, password, dan kode aktivasi wajib diisi');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(clientProvider.notifier)
          .activate(
            baseUrl: defaultServerUrl(),
            email: _email.text,
            password: _pass.text,
            coupon: _coupon.text,
            deviceName: await ref.read(deviceNameProvider.future),
          );
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Aktivasi perangkat',
    subtitle: 'Masuk dengan akun restoran Anda dan kode aktivasi dari CS',
    child: AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email restoran',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: !_showPass,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password restoran',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _showPass ? 'Sembunyikan' : 'Tampilkan',
                icon: Icon(
                  _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _coupon,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_CouponFormatter()],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Kode aktivasi',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            onSubmitted: (_) => _loading ? null : _submit(),
          ),
          const SizedBox(height: 12),
          const DeviceNameTile(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBox(_error!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _loading ? null : _submit,
            child: _loading ? _busy() : const Text('Aktifkan'),
          ),
          const SizedBox(height: 14),
          Text(
            'Kode aktivasi dari CS bisa dipakai lagi bila perangkat perlu diaktivasi ulang. '
            'Belum punya? Hubungi $kCsName.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

/// Nama perangkat (dibaca otomatis dari sistem, tidak bisa diubah).
class DeviceNameTile extends ConsumerWidget {
  const DeviceNameTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(deviceNameProvider).value ?? '…';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.tablet_android_outlined, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perangkat ini',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
        ],
      ),
    );
  }
}

Future<void> contactCs(BuildContext context, ClientState? c) async {
  final who = c == null ? '' : '\n\nRestoran: ${c.info.name} (${c.info.code})';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Hubungi $kCsName'),
      content: Text(
        kCsWhatsapp.isEmpty
            ? 'Sampaikan bahwa Anda ingin memperpanjang langganan RMS.$who'
            : 'WhatsApp: +$kCsWhatsapp\n'
                  'Sampaikan bahwa Anda ingin memperpanjang langganan RMS.$who',
      ),
      actions: [
        if (kCsWhatsapp.isNotEmpty)
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '+$kCsWhatsapp'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nomor CS disalin')),
              );
            },
            child: const Text('Salin nomor'),
          ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
      ],
    ),
  );
}

/// Langganan habis / ditangguhkan / terlalu lama offline. Juga dipakai dari Akun
/// untuk memasukkan kupon perpanjangan ([blocked] = false).
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key, this.blocked = true});
  final bool blocked;
  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  final _coupon = TextEditingController();
  bool _loading = false;
  bool _checking = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_coupon.text.trim().isEmpty) {
      setState(() => _error = 'Masukkan kode perpanjangan dari CS');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(clientProvider.notifier).redeem(_coupon.text);
      _coupon.clear();
      final c = ref.read(clientProvider).value;
      if (mounted) {
        setState(
          () => _info = c == null
              ? 'Berhasil'
              : c.info.subscription.lifetime
              ? 'Langganan aktif selamanya'
              : 'Langganan aktif sampai ${formatClientDate(c.info.subscription.validUntil)}',
        );
        if (!widget.blocked) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_info!)));
          Navigator.of(context).maybePop();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    await ref.read(clientProvider.notifier).refreshStatus();
    if (!mounted) return;
    setState(() => _checking = false);
    if (ref.read(clientBlockProvider) != BlockReason.none) {
      setState(() => _info = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status belum berubah')),
      );
    }
  }

  Future<void> _switchClient() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun restoran?'),
        content: const Text(
          'Perangkat perlu diaktivasi ulang dengan kode baru dari CS. '
          'Data yang belum terkirim tetap tersimpan di perangkat.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await ref.read(clientProvider.notifier).forget();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(clientProvider).value;
    final reason = ref.watch(clientBlockProvider);
    final (title, message) = switch (reason) {
      BlockReason.suspended => (
        'Akun ditangguhkan',
        'Akun restoran ${c?.info.name ?? ''} sedang ditangguhkan. Hubungi $kCsName.',
      ),
      BlockReason.offlineTooLong => (
        'Perlu terhubung ke internet',
        'Status langganan belum diperiksa lebih dari $kOfflineGraceDays hari. '
            'Sambungkan perangkat ke internet lalu tekan "Periksa lagi".',
      ),
      BlockReason.expired => (
        'Langganan berakhir',
        'Langganan ${c?.info.name ?? 'restoran Anda'} berakhir'
            '${c == null ? '' : ' pada ${formatClientDate(c.info.subscription.validUntil)}'}. '
            'Hubungi $kCsName untuk perpanjangan, lalu masukkan kode yang diberikan.',
      ),
      BlockReason.none => (
        widget.blocked ? 'Langganan aktif' : 'Perpanjang langganan',
        c == null
            ? ''
            : c.info.subscription.lifetime
            ? 'Langganan aktif selamanya. '
            : 'Aktif sampai ${formatClientDate(c.info.subscription.validUntil)}. '
                  'Masukkan kode dari CS untuk menambah masa aktif.',
      ),
    };

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: GoogleFonts.inter(fontSize: 14, height: 1.45)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => contactCs(context, c),
          icon: const Icon(Icons.support_agent_outlined),
          label: Text('Hubungi $kCsName'),
        ),
        if (reason != BlockReason.offlineTooLong &&
            reason != BlockReason.suspended) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _coupon,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_CouponFormatter()],
            decoration: const InputDecoration(
              labelText: 'Kode perpanjangan',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            onSubmitted: (_) => _loading ? null : _redeem(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _loading ? null : _redeem,
            child: _loading ? _busy() : const Text('Perpanjang'),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), AuthErrorBox(_error!)],
        if (_info != null) ...[
          const SizedBox(height: 12),
          Text(_info!, style: GoogleFonts.inter(color: AppColors.primary)),
        ],
        if (widget.blocked) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _checking ? null : _recheck,
            icon: const Icon(Icons.refresh),
            label: const Text('Periksa lagi'),
          ),
          TextButton(
            onPressed: _switchClient,
            child: const Text('Keluar dari akun restoran'),
          ),
        ],
      ],
    );

    if (!widget.blocked) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(16), children: [body]),
      );
    }
    return AuthLayout(title: title, subtitle: c?.info.name, child: body);
  }
}
