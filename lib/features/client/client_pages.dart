import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/config/app_config.dart';
import '../../core/device/device_name.dart';
import '../../core/theme/app_colors.dart';
import '../../shell/auth_layout.dart';
import '../auth/auth_providers.dart';
import 'client_models.dart';
import 'client_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

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

const _monthsLong = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "16 Desember 2026".
String formatClientDateLong(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${_monthsLong[d.month - 1]} ${d.year}';
}

/// Sisa hari langganan menurut jam server (dibulatkan ke atas).
int daysLeftOf(Subscription s) {
  final now = s.serverTime > 0 ? s.serverTime : DateTime.now().millisecondsSinceEpoch;
  final ms = s.validUntil - now;
  return ms <= 0 ? 0 : (ms / Duration.millisecondsPerDay).ceil();
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
        Icon(Icons.error_outline, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.primary),
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

/// Layar pertama: masuk dengan akun restoran (email + password klien).
class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({super.key});
  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Email dan password restoran wajib diisi');
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
    title: 'Masuk ke akun restoran',
    subtitle: 'Gunakan email dan password restoran yang terdaftar',
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
            textInputAction: TextInputAction.done,
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
            child: _loading ? _busy() : const Text('Masuk'),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum memiliki akun restoran? Hubungi $kCsName.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
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
          Icon(Icons.tablet_android_outlined, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perangkat ini',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Buka WhatsApp CS dengan pesan siap kirim. Bila tidak bisa dibuka (nomor belum diatur,
/// WhatsApp tidak terpasang), tampilkan nomor untuk disalin.
Future<void> contactCs(BuildContext context, ClientState? c) async {
  final who = c == null ? '' : ' untuk restoran ${c.info.name} (${c.info.code})';
  final text = 'Halo $kCsName, saya ingin memperpanjang langganan RMS$who. Terima kasih.';
  if (kCsWhatsapp.isNotEmpty) {
    final uri = Uri.parse('https://wa.me/$kCsWhatsapp?text=${Uri.encodeComponent(text)}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // lanjut ke dialog
    }
  }
  if (!context.mounted) return;
  await showAppDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Hubungi $kCsName'),
      content: Text(
        kCsWhatsapp.isEmpty
            ? 'Sampaikan kepada $kCsName bahwa Anda ingin memperpanjang langganan RMS$who.'
            : 'WhatsApp: +$kCsWhatsapp\n\n'
                  'Sampaikan bahwa Anda ingin memperpanjang langganan RMS$who.',
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

/// Dialog setelah kode aktivasi berhasil dipakai.
Future<void> showActivatedDialog(
  BuildContext context,
  ClientInfo info, {
  required bool reactivated,
}) {
  final s = info.subscription;
  final period = s.lifetime
      ? 'Langganan ${info.name} kini aktif selamanya.'
      : 'Langganan ${info.name} kini aktif selama ${daysLeftOf(s)} hari, '
            'hingga ${formatClientDateLong(s.validUntil)}.';
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.sageSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 34, color: AppColors.success),
      ),
      title: Text(
        reactivated ? 'Selamat, akun Anda aktif kembali!' : 'Langganan berhasil diperpanjang',
        textAlign: TextAlign.center,
      ),
      content: Text(
        reactivated
            ? '$period\n\nSilakan masuk untuk mulai menggunakan aplikasi kembali.'
            : '$period\n\nTerima kasih telah memperpanjang langganan.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
          onPressed: () => Navigator.pop(ctx),
          child: Text(reactivated ? 'OK, masuk sekarang' : 'OK'),
        ),
      ],
    ),
  );
}

/// [blocked] = true: gerbang aplikasi (langganan habis / ditangguhkan / terlalu lama offline).
/// [blocked] = false: dibuka dari halaman login atau Akun owner untuk perpanjangan.
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

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_coupon.text.trim().isEmpty) {
      setState(() => _error = 'Masukkan kode aktivasi dari $kCsName');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final notifier = ref.read(clientProvider.notifier);
    try {
      // Status disimpan setelah dialog ditutup, supaya dialog sempat tampil sebelum
      // gerbang aplikasi berpindah ke halaman login.
      final info = await notifier.redeem(_coupon.text, apply: false);
      _coupon.clear();
      if (!mounted) {
        await notifier.applyInfo(info);
        return;
      }
      setState(() => _loading = false);
      await showActivatedDialog(context, info, reactivated: widget.blocked);
      await notifier.applyInfo(info);
      if (mounted && !widget.blocked) Navigator.of(context).maybePop();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status langganan belum berubah')),
      );
    }
  }

  Future<void> _switchClient() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun restoran?'),
        content: const Text(
          'Anda perlu masuk lagi dengan email dan password restoran. '
          'Data yang belum terkirim tetap tersimpan di perangkat ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await ref.read(clientProvider.notifier).forget();
  }

  Widget _statusCard({
    required IconData icon,
    required Color fg,
    required Color bg,
    required String title,
    required String message,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: fg, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.5, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _orDivider(String text) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );

  Widget _whatsappButton(ClientState? c, {required bool primary}) {
    final style = primary
        ? FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          )
        : null;
    const icon = Icon(Icons.chat_outlined);
    final label = Text(primary ? 'Hubungi CS via WhatsApp' : 'Belum punya kode? Hubungi CS');
    return primary
        ? FilledButton.icon(
            style: style,
            onPressed: () => contactCs(context, c),
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => contactCs(context, c),
            icon: icon,
            label: label,
          );
  }

  List<Widget> _codeForm(String button) => [
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
      onSubmitted: (_) => _loading ? null : _redeem(),
    ),
    if (_error != null) ...[const SizedBox(height: 12), AuthErrorBox(_error!)],
    const SizedBox(height: 12),
    FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
      onPressed: _loading ? null : _redeem,
      child: _loading ? _busy() : Text(button),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(clientProvider).value;
    final reason = ref.watch(clientBlockProvider);
    final name = c?.info.name ?? 'restoran Anda';
    final sub = c?.info.subscription;

    if (!widget.blocked) return _extendPage(c, sub);

    final card = switch (reason) {
      BlockReason.suspended => _statusCard(
        icon: Icons.pause_circle_outline,
        fg: AppColors.danger,
        bg: AppColors.roseSoft,
        title: 'Akun sedang ditangguhkan',
        message:
            'Mohon maaf, akun $name sedang ditangguhkan sehingga aplikasi belum dapat '
            'digunakan. Silakan hubungi $kCsName untuk informasi lebih lanjut.',
      ),
      BlockReason.offlineTooLong => _statusCard(
        icon: Icons.wifi_off_rounded,
        fg: AppColors.warning,
        bg: const Color(0xFFF7EBD6),
        title: 'Perlu terhubung ke internet',
        message:
            'Status langganan belum diperiksa lebih dari $kOfflineGraceDays hari. '
            'Sambungkan perangkat ke internet, lalu ketuk "Periksa lagi".',
      ),
      _ => _statusCard(
        icon: Icons.event_busy_outlined,
        fg: AppColors.danger,
        bg: AppColors.roseSoft,
        title: 'Masa aktif langganan telah berakhir',
        message:
            'Mohon maaf, langganan $name telah berakhir'
            '${sub == null || sub.validUntil <= 0 ? '' : ' pada ${formatClientDateLong(sub.validUntil)}'}'
            ' sehingga aplikasi untuk sementara tidak dapat digunakan. '
            'Jika belum melakukan pemesanan perpanjangan, silakan hubungi $kCsName.',
      ),
    };
    final canRedeem = reason == BlockReason.expired || reason == BlockReason.none;

    return AuthLayout(
      title: reason == BlockReason.suspended ? 'Akun tidak aktif' : 'Langganan tidak aktif',
      subtitle: c?.info.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card,
          const SizedBox(height: 16),
          if (reason != BlockReason.offlineTooLong) _whatsappButton(c, primary: true),
          if (canRedeem) ...[
            const SizedBox(height: 22),
            _orDivider('Sudah memiliki kode aktivasi?'),
            const SizedBox(height: 8),
            Text(
              'Masukkan kode dari $kCsName di bawah ini untuk mengaktifkan kembali akun Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            ..._codeForm('Aktifkan'),
          ],
          const SizedBox(height: 10),
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
      ),
    );
  }

  Widget _extendPage(ClientState? c, Subscription? sub) {
    final status = sub == null
        ? null
        : sub.lifetime
        ? _statusCard(
            icon: Icons.all_inclusive_rounded,
            fg: AppColors.primary,
            bg: AppColors.primarySoft,
            title: 'Langganan aktif selamanya',
            message: 'Langganan ${c!.info.name} tidak memiliki batas waktu.',
          )
        : sub.inGrace
        ? _statusCard(
            icon: Icons.hourglass_bottom_rounded,
            fg: AppColors.warning,
            bg: const Color(0xFFF7EBD6),
            title: 'Masa tenggang',
            message:
                'Langganan ${c!.info.name} berakhir pada ${formatClientDateLong(sub.validUntil)}. '
                'Segera perpanjang agar aplikasi tetap dapat digunakan.',
          )
        : _statusCard(
            icon: Icons.verified_outlined,
            fg: AppColors.success,
            bg: AppColors.sageSoft,
            title: 'Langganan aktif',
            message:
                'Langganan ${c!.info.name} aktif hingga ${formatClientDateLong(sub.validUntil)} '
                '(${daysLeftOf(sub)} hari lagi).',
          );
    return Scaffold(
      appBar: RmsAppBar(title: const Text('Perpanjang langganan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (status != null) status,
              const SizedBox(height: 20),
              Text(
                'Masukkan kode aktivasi dari $kCsName untuk menambah masa aktif langganan.',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 14),
              ..._codeForm('Perpanjang'),
              const SizedBox(height: 22),
              _whatsappButton(c, primary: false),
            ],
          ),
        ),
      ),
    );
  }
}
